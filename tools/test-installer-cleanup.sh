#!/usr/bin/env bash
# Tests installer/target-cleanup.sh against a real FloppaOS ISO, without a disk or a VM:
# unpacks the ISO's system image (what the installer copies onto the disk), does what the installer's
# earlier steps do (remove the live user, create a user, write a keyboard layout), runs the cleanup inside
# the copy (chroot) and checks the result. Optionally also builds the boot image (initramfs).
#
# Usage (as root, Linux, needs unsquashfs and bsdtar; about 8 GB free space):
#   tools/test-installer-cleanup.sh <floppaos.iso> <empty work folder> [--initramfs]
# Exit code 0 = all checks passed. Used by .github/workflows/iso.yml after every ISO build.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISO="$(realpath "${1:?ISO file}")"
WORK="${2:?empty work folder}"
WITH_INITRAMFS="${3:-}"

[ "$(id -u)" = 0 ] || { echo "Run as root."; exit 1; }
mkdir -p "${WORK}"
WORK="$(realpath "${WORK}")"
[ -z "$(ls -A "${WORK}")" ] || { echo "Work folder must be empty: ${WORK}"; exit 1; }
T="${WORK}/target"

cleanup_mounts() {
  for m in run dev/pts dev sys proc; do mountpoint -q "${T}/${m}" && umount -l "${T}/${m}"; done
  mountpoint -q "${T}" && umount -l "${T}"
  return 0
}
trap cleanup_mounts EXIT

echo "== Unpacking the system image from ${ISO##*/}"
bsdtar -xf "${ISO}" -C "${WORK}" arch/x86_64/airootfs.sfs
unsquashfs -q -n -d "${T}" "${WORK}/arch/x86_64/airootfs.sfs" >/dev/null
rm -f "${WORK}/arch/x86_64/airootfs.sfs"

# The same mounts the installer's mount step makes (installer/calamares/modules/mount.conf). The copy's root
# is bind-mounted onto itself so that, as on the real new partition, "/" is a mount point (mkinitcpio's
# autodetect looks for the root filesystem).
mount --bind "${T}" "${T}"
mount -t proc proc "${T}/proc"
mount -t sysfs sys "${T}/sys"
mount --bind /dev "${T}/dev"
mount --bind /dev/pts "${T}/dev/pts"
mount -t tmpfs tmpfs "${T}/run"
in_target() { chroot "${T}" /usr/bin/env -i PATH=/usr/bin:/usr/sbin HOME=/root LANG=C.UTF-8 "$@"; }

echo "== Doing what the installer does before the cleanup"
in_target userdel -f -r floppa 2>/dev/null || true                    # removeuser
in_target useradd -m -G users,wheel,video,audio,input tester           # users
echo 'tester:tester' | in_target chpasswd
echo tester-floppaos > "${T}/etc/hostname"
mkdir -p "${T}/etc/X11/xorg.conf.d"                                    # keyboard
cat > "${T}/etc/X11/xorg.conf.d/00-keyboard.conf" <<'CONF'
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        Option "XkbLayout" "de"
        Option "XkbModel" "pc105"
        Option "XkbVariant" "nodeadkeys"
EndSection
CONF
echo 'KEYMAP=de-latin1-nodeadkeys' > "${T}/etc/vconsole.conf"

echo "== Running installer/target-cleanup.sh inside the copy"
install -Dm755 "${ROOT}/installer/target-cleanup.sh" "${T}/usr/lib/floppaos-installer/target-cleanup"
in_target /usr/lib/floppaos-installer/target-cleanup

if [ "${WITH_INITRAMFS}" = "--initramfs" ]; then
  echo "== Building the boot image like the installer's initcpio step"
  in_target mkinitcpio -p linux
fi

echo "== Checks"
failures=0
check() {  # check "<description>" <command...>
  local what="$1"; shift
  if "$@" >/dev/null 2>&1; then echo "  ok    ${what}"; else echo "  FAIL  ${what}"; failures=$((failures + 1)); fi
}
absent() { [ ! -e "${T}$1" ] && [ ! -L "${T}$1" ]; }
grub_quiet_test() {  # installer/grub-quiet.sh on a copy of the image's GRUB settings, without/with Windows
  local d; d="$(mktemp -d)"; mkdir -p "${d}/boot/grub" "${d}/etc/default" "${d}/usr/share/grub/themes"
  cp "${T}/etc/default/grub" "${d}/etc/default/grub" || return 1
  cp -r "${T}/usr/share/grub/themes/floppaos" "${d}/usr/share/grub/themes/" || return 1
  printf "menuentry 'FloppaOS Linux' --class floppaos {\n\techo\t'Loading Linux linux ...'\n}\n" > "${d}/boot/grub/grub.cfg"
  [ "$1" = windows ] && echo "menuentry 'Windows Boot Manager (on /dev/nvme0n1p1)' --class windows --class os {" >> "${d}/boot/grub/grub.cfg"
  FLOPPAOS_ROOT="${d}" sh "${ROOT}/installer/grub-quiet.sh" >/dev/null || { rm -rf "${d}"; return 1; }
  local ok=1
  if [ "$1" = windows ]; then  # menu shown, in FloppaOS's look, no "Loading" text
    grep -qx 'GRUB_TERMINAL_OUTPUT=gfxterm' "${d}/etc/default/grub" \
      && grep -qx 'GRUB_THEME="/usr/share/grub/themes/floppaos/theme.txt"' "${d}/etc/default/grub" \
      && ! grep -q '^GRUB_TIMEOUT_STYLE=hidden' "${d}/etc/default/grub" \
      && ! grep -q "Loading Linux" "${d}/boot/grub/grub.cfg" && ok=0
  else
    grep -qx 'GRUB_TIMEOUT_STYLE=hidden' "${d}/etc/default/grub" && grep -qx 'GRUB_TIMEOUT=1' "${d}/etc/default/grub" \
      && ! grep -q '^GRUB_THEME=' "${d}/etc/default/grub" && ! grep -q "Loading Linux" "${d}/boot/grub/grub.cfg" && ok=0
  fi
  rm -rf "${d}"; return "${ok}"
}
floppasetup_step_test() {  # the image's "floppasetup" installer step, run with a stand-in for Calamares' API
  local d; d="$(mktemp -d)"
  cat > "${d}/libcalamares.py" <<'PY'
class _GS:
    def __init__(self, d): self.d = d
    def contains(self, k): return k in self.d
    def value(self, k): return self.d.get(k)
class utils:
    warning = debug = staticmethod(lambda m: None)
globalstorage = None
PY
  python3 -I - "${d}" "${T}" <<'PY' || { rm -rf "${d}"; return 1; }
import importlib.util, sys
sys.path.insert(0, sys.argv[1]); import libcalamares
root = sys.argv[2]
libcalamares.globalstorage = libcalamares._GS({"rootMountPoint": root, "username": "tester",
                                               "floppaos_setup": {"launcher": True, "pin": False, "wine": True}})
spec = importlib.util.spec_from_file_location("m", root + "/usr/lib/floppaos-installer/calamares-modules/floppasetup/main.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
sys.exit(0 if m.run() is None else 1)
PY
  rm -rf "${d}"
  [ "$(grep -v '^#' "${T}/etc/floppaos/setup-choices.conf" | tr '\n' ' ')" = "user=tester launcher=yes pin=no wine=yes " ]
}
floppasecureboot_step_test() {  # the "floppasecureboot" step with a stand-in for Calamares' API: off = nothing,
  # on = runs "floppaos-secureboot setup --code-file F" in the new system, the code in F, and F deleted afterwards
  local d; d="$(mktemp -d)"
  cat > "${d}/libcalamares.py" <<'PY'
import os
class _GS:
    def __init__(self, d): self.d = d
    def contains(self, k): return k in self.d
    def value(self, k): return self.d.get(k)
calls = []
class utils:
    warning = debug = staticmethod(lambda m: None)
    @staticmethod
    def target_env_process_output(cmd, callback=None, *rest):
        path = globalstorage.value("rootMountPoint") + cmd[-1]
        calls.append((list(cmd), open(path).read().strip(), oct(os.stat(path).st_mode & 0o777)))
        return 0
globalstorage = None
PY
  python3 -I - "${d}" "${T}" <<'PY' || { rm -rf "${d}"; return 1; }
import importlib.util, os, sys
sys.path.insert(0, sys.argv[1]); import libcalamares
root = sys.argv[2]
spec = importlib.util.spec_from_file_location("m", root + "/usr/lib/floppaos-installer/calamares-modules/floppasecureboot/main.py")
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
for choice in (None, {"enabled": False, "code": "12345678"}, {"enabled": True, "code": "12ab"}):
    libcalamares.globalstorage = libcalamares._GS({"rootMountPoint": root, "floppaos_secureboot": choice})
    assert m.run() is None and libcalamares.calls == [], choice
libcalamares.globalstorage = libcalamares._GS({"rootMountPoint": root, "floppaos_secureboot": {"enabled": True, "code": "48219063"}})
assert m.run() is None
assert libcalamares.calls == [(["floppaos-secureboot", "setup", "--code-file", "/root/.floppaos-secureboot-code"], "48219063", "0o600")], libcalamares.calls
assert not os.path.exists(root + "/root/.floppaos-secureboot-code")
PY
  rm -rf "${d}"
}
secureboot_sign_test() {  # the image's signing tools sign and verify a copy of its kernel with a throwaway key
  local d=/tmp/floppaos-sbtest ok=0
  in_target bash -c "rm -rf ${d} && mkdir -p ${d} && cd ${d} && openssl req -new -x509 -newkey rsa:2048 -nodes -sha256 -days 1 -subj /CN=test/ -keyout k.key -out k.crt 2>/dev/null && cp /boot/vmlinuz-linux v && sbsign --key k.key --cert k.crt --output v.signed v 2>/dev/null && sbverify --cert k.crt v.signed && ! sbverify --cert k.crt v" || ok=1
  rm -rf "${T}${d}"
  return "${ok}"
}
no_link_named() { [ -z "$(find "${T}/etc/systemd/system" -type l -name "$1" -print -quit)" ]; }
no_process_inside() {  # true when no running process has its root folder inside the copy
  local p r
  for p in /proc/[0-9]*; do
    r="$(readlink "${p}/root" 2>/dev/null)" || continue
    case "${r}" in "${T}"|"${T}"/*) echo "still running inside the copy: $(tr '\0' ' ' < "${p}/cmdline")"; return 1 ;; esac
  done
}

check "kernel is in /boot" test -s "${T}/boot/vmlinuz-linux"
check "kernel matches the package's copy" cmp "${T}/boot/vmlinuz-linux" "$(find "${T}/usr/lib/modules" -mindepth 2 -maxdepth 2 -name vmlinuz | head -n1)"
for f in /etc/mkinitcpio.conf.d/archiso.conf /etc/systemd/system/getty@tty1.service.d/autologin.conf \
         /etc/ssh/sshd_config.d/10-archiso.conf /etc/systemd/system/etc-pacman.d-gnupg.mount \
         /etc/systemd/system/pacman-init.service /etc/systemd/journald.conf.d/volatile-storage.conf \
         /etc/systemd/logind.conf.d/do-not-suspend.conf /etc/plasmalogin.conf.d/floppaos-live.conf \
         /etc/systemd/system/systemd-time-wait-sync.service.d \
         /etc/sudoers.d/floppa-live /etc/motd /root/.automated_script.sh /root/.config/kdeglobals /home/floppa; do
  check "live-only ${f} is gone" absent "${f}"
done
for l in sshd.service pacman-init.service choose-mirror.service 'livecd-*.service' systemd-time-wait-sync.service; do
  check "service ${l} is not switched on" no_link_named "${l}"
done
check "NetworkManager is still switched on" test -L "${T}/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
check "login screen is still switched on" test -L "${T}/etc/systemd/system/display-manager.service"
check "login screen is Plasma Login Manager" bash -c "[ \"\$(readlink '${T}/etc/systemd/system/display-manager.service')\" = /usr/lib/systemd/system/plasmalogin.service ]"
check "Plasma Login Manager's PAM files exist" bash -c "for f in plasmalogin plasmalogin-greeter plasmalogin-autologin; do test -s '${T}/usr/lib/pam.d/'\$f || test -s '${T}/etc/pam.d/'\$f || exit 1; done"
check "greeter user plasmalogin exists" grep -q '^plasmalogin:' "${T}/etc/passwd"
check "new accounts get the Windows shortcuts from the start" grep -q '^_launch=Meta+Esc\\tCtrl+Shift+Esc$' "${T}/etc/skel/.config/kglobalshortcutsrc"
check "new accounts start without a splash screen" grep -q '^Engine=none$' "${T}/etc/skel/.config/ksplashrc"
check "Bluetooth is switched on" test -L "${T}/etc/systemd/system/bluetooth.target.wants/bluetooth.service"
check "power profiles are switched on" test -L "${T}/etc/systemd/system/graphical.target.wants/power-profiles-daemon.service"
check "live user floppa is gone" bash -c "! grep -q '^floppa:' '${T}/etc/passwd'"
check "new user tester still exists" grep -q '^tester:' "${T}/etc/passwd"
check "lsb-release names FloppaOS" grep -qx 'DISTRIB_ID="FloppaOS"' "${T}/etc/lsb-release"
check "pacman hook keeps lsb-release on updates" test -s "${T}/etc/pacman.d/hooks/floppaos-lsb-release.hook"
check "boot screen theme is FloppaOS" grep -qx 'Theme=floppaos' "${T}/etc/plymouth/plymouthd.conf"
check "boot screen theme and its pictures exist" bash -c "d='${T}/usr/share/plymouth/themes/floppaos'; test -s \$d/floppaos.plymouth && test -s \$d/watermark.png && test -e \$d/throbber-0001.png && test -e \$d/animation-0001.png"
check "boot screen does not show the Arch logo" bash -c "! cmp -s '${T}/usr/share/plymouth/themes/floppaos/watermark.png' '${T}/usr/share/plymouth/themes/spinner/watermark.png'"
check "boot menu hidden when FloppaOS is the only system" grub_quiet_test alone
check "boot menu shown in FloppaOS's look when another system is installed" grub_quiet_test windows
check "boot menu theme, its logo and fonts exist" bash -c "d='${T}/usr/share/grub/themes/floppaos'; test -s \$d/theme.txt && test -s \$d/logo.png && test -s \$d/noto-sans-22.pf2 && test -s \$d/select_c.png"
check "root's shell is bash" bash -c "[ \"\$(awk -F: '\$1==\"root\"{print \$7}' '${T}/etc/passwd')\" = /bin/bash ]"
check "root has no empty password" bash -c "[ -n \"\$(awk -F: '\$1==\"root\"{print \$2}' '${T}/etc/shadow')\" ]"
check "package keyring exists" bash -c "test -s '${T}/etc/pacman.d/gnupg/pubring.kbx' || test -s '${T}/etc/pacman.d/gnupg/pubring.gpg'"
check "Arch's keys are trusted" bash -c "chroot '${T}' pacman-key --list-keys 2>/dev/null | grep -q 'Arch Linux'"
check "no program left running inside the copy (would block unmounting)" no_process_inside
check "multilib repository is on" grep -q '^\[multilib\]' "${T}/etc/pacman.conf"
if [ -s "${ROOT}/keyring/floppaos.gpg" ]; then   # FloppaOS updates are on once the signing key exists
  check "FloppaOS update repository is set up" grep -q '^\[floppaos\]' "${T}/etc/pacman.conf"
  check "FloppaOS's signing key is trusted" bash -c "chroot '${T}' pacman-key --list-keys 2>/dev/null | grep -q 'FloppaOS'"
fi
check "pacman accepts its configuration" in_target pacman-conf
check "mkinitcpio's pacman hook is not switched off" absent /etc/pacman.d/hooks/90-mkinitcpio-install.hook
for p in mkinitcpio-archiso memtest86+ livecd-sounds; do
  check "live-only package ${p} removed" bash -c "! chroot '${T}' pacman -Q '${p}'"
done
check "Plasma keyboard layout is de (nodeadkeys)" bash -c "grep -q '^LayoutList=de$' '${T}/etc/xdg/kxkbrc' && grep -q '^VariantList=nodeadkeys$' '${T}/etc/xdg/kxkbrc'"
check "host name kept" grep -qx tester-floppaos "${T}/etc/hostname"
check "installer shows the \"Before you start\" page (no warranty, back up first) right after the welcome page" bash -c "grep -A1 '^ *- welcome\$' '${T}/etc/calamares/settings.conf' | grep -q '^ *- notesqml@beforeyoustart\$' && grep -q 'no warranty' '${T}/etc/calamares/branding/floppaos/before-you-start.qml'"
check "installer shows the \"Floppa games\" page" bash -c "grep -q '^ *- notesqml@floppagames\$' '${T}/etc/calamares/settings.conf' && test -s '${T}/etc/calamares/branding/floppaos/floppa-games.qml' && test -s '${T}/usr/lib/calamares/modules/notesqml/module.desc'"
check "installer runs the floppasetup step" bash -c "grep -q '^ *- floppasetup\$' '${T}/etc/calamares/settings.conf' && test -s '${T}/usr/lib/floppaos-installer/calamares-modules/floppasetup/module.desc'"
check "floppasetup step saves the choices for Floppa Setup" floppasetup_step_test
check "Floppa Setup reads the installer's choices" grep -q '/etc/floppaos/setup-choices.conf' "${T}/usr/bin/floppa-setup"
check "FloppaOS PC check is installed" test -x "${T}/usr/bin/floppaos-pc-check"
check "FloppaOS PC check runs (read-only report)" bash -c "python3 '${T}/usr/bin/floppaos-pc-check' --print | grep -q '^FloppaOS PC check'"
check "installer shows the \"Secure Boot\" page" bash -c "grep -q '^ *- notesqml@secureboot\$' '${T}/etc/calamares/settings.conf' && test -s '${T}/etc/calamares/branding/floppaos/secure-boot.qml'"
check "installer runs the floppasecureboot step right after the boot loader" bash -c "grep -A1 '^ *- bootloader\$' '${T}/etc/calamares/settings.conf' | grep -q '^ *- floppasecureboot\$' && test -s '${T}/usr/lib/floppaos-installer/calamares-modules/floppasecureboot/module.desc'"
check "floppasecureboot step: nothing without the tick, setup with the code in a root-only file that is removed" floppasecureboot_step_test
check "Secure Boot tool, its update hooks and the start-up check are installed" bash -c "test -x '${T}/usr/bin/floppaos-secureboot' && test -s '${T}/usr/share/libalpm/hooks/95-floppaos-secureboot-kernel.hook' && test -s '${T}/usr/share/libalpm/hooks/95-floppaos-secureboot-boot.hook' && test -s '${T}/usr/lib/systemd/system/floppaos-secureboot-check.service'"
check "shim and MokManager are Fedora's Microsoft-signed 16.1-7 files" bash -c "cd '${T}/usr/share/floppaos-shim' && echo '351e131d3c4a636704e9cae7d1296baf8a05beca9922cfebbfa48933c9bf1ad3  shimx64.efi
ed4442fa88cccba3a9e6a32d21a8f4c56bf5aab184f1fb9aadde8d3a9d04dc27  mmx64.efi' | sha256sum -c --quiet"
check "Secure Boot support is not set up until someone asks for it" absent /var/lib/floppaos-secureboot
check "the image's tools sign and verify its kernel (sbsign, sbverify, openssl)" secureboot_sign_test
check "mokutil is installed" test -x "${T}/usr/bin/mokutil"
if [ "${WITH_INITRAMFS}" = "--initramfs" ]; then
  check "boot image built" test -s "${T}/boot/initramfs-linux.img"
fi

echo
if [ "${failures}" = 0 ]; then echo "All checks passed."; else echo "${failures} check(s) failed."; fi
[ "${failures}" = 0 ]
