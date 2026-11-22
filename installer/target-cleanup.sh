#!/usr/bin/env bash
# FloppaOS installer, step "Preparing FloppaOS for its first start" (Calamares shellprocess@livefiles).
#
# Runs INSIDE the newly installed system (Calamares runs it in a chroot), after the live system was copied
# onto the disk and the user account was created. It turns that copy of the live USB system into a normal
# installed system. Each step says why. installer/README.md lists everything this removes.
#
# Test without a disk: tools/test-installer-cleanup.sh runs it against an unpacked FloppaOS ISO.
set -uo pipefail

log()  { printf 'floppaos-cleanup: %s\n' "$*"; }
fail() { printf 'floppaos-cleanup: ERROR: %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" = 0 ] || fail "must run as root"
# Never on the live system itself: it would remove the live user's login. Inside the installer's chroot
# /run is a fresh, empty tmpfs, so /run/archiso only exists on the live system.
if [ -d /run/archiso ] && [ "${FLOPPAOS_CLEANUP_TEST:-0}" != 1 ]; then
  fail "this is the live system (/run/archiso exists); this script only runs inside the installed system"
fi

# 1. Kernel. The live image keeps /boot empty (the live kernel is on the USB stick). Arch's kernel package
#    also keeps its kernel as /usr/lib/modules/<version>/vmlinuz; copying it to /boot/vmlinuz-<name> is what
#    Arch's own install hook (/usr/share/libalpm/scripts/mkinitcpio) does. The boot image (initramfs) is
#    built by the next installer steps.
found=0
for dir in /usr/lib/modules/*/; do
  if [ ! -f "${dir}vmlinuz" ] || [ ! -f "${dir}pkgbase" ]; then continue; fi
  pkgbase="$(<"${dir}pkgbase")"
  install -Dm644 "${dir}vmlinuz" "/boot/vmlinuz-${pkgbase}" || fail "could not copy the kernel to /boot"
  log "kernel copied: /boot/vmlinuz-${pkgbase} ($(basename "${dir}"))"
  found=1
done
[ "${found}" = 1 ] || fail "no kernel found in /usr/lib/modules"

# 2. Files that only belong on the live USB stick.
live_only=(
  # From Arch's live profile (archiso "releng"):
  /etc/mkinitcpio.conf.d/archiso.conf                       # boot hooks for starting from the USB stick
  /etc/systemd/system/getty@tty1.service.d/autologin.conf   # root logged in on the text console, no password
  /etc/ssh/sshd_config.d/10-archiso.conf                    # SSH allowed root to log in with a password
  /etc/systemd/system/etc-pacman.d-gnupg.mount              # package keyring only in RAM, lost at every boot
  /etc/systemd/system/pacman-init.service                   # recreated that RAM keyring at every boot
  /etc/systemd/system/choose-mirror.service                 # boot option of the live stick
  /etc/systemd/system/livecd-alsa-unmuter.service           # live stick sound helper
  /etc/systemd/system/livecd-talk.service                   # screen reader for the live boot menu entry
  /etc/systemd/journald.conf.d/volatile-storage.conf        # system log only in RAM
  /etc/systemd/logind.conf.d/do-not-suspend.conf            # never suspend (live stick only)
  /etc/systemd/resolved.conf.d/archiso.conf                 # live stick network setting
  /etc/systemd/system-generators/systemd-gpt-auto-generator # switched off on the live stick only
  /etc/motd                                                 # live stick welcome text
  /root/.automated_script.sh
  /root/.zlogin
  /usr/local/bin/choose-mirror
  /usr/local/bin/Installation_guide
  /usr/local/bin/livecd-sound
  # From the FloppaOS live system (iso/airootfs, iso/build.sh):
  /etc/plasmalogin.conf.d/floppaos-live.conf                # automatic login as the live user
  /etc/systemd/system/systemd-time-wait-sync.service.d/floppaos-live.conf  # 30 s limit for the live keyring's clock wait
  /etc/sudoers.d/floppa-live                                # sudo without a password for the live user
  /root/.config/kdeglobals                                  # black colours for the installer, which runs as root
)
for f in "${live_only[@]}"; do
  if [ -e "${f}" ] || [ -L "${f}" ]; then
    rm -f -- "${f}" && log "removed ${f}"
  fi
done
rm -rf -- /usr/local/share/livecd-sound /root/.gnupg
rmdir /etc/systemd/system/systemd-time-wait-sync.service.d 2>/dev/null || true
rmdir --ignore-fail-on-non-empty /etc/systemd/system/getty@tty1.service.d /etc/mkinitcpio.conf.d \
  /etc/systemd/journald.conf.d /etc/systemd/logind.conf.d /etc/systemd/resolved.conf.d \
  /etc/systemd/system-generators 2>/dev/null || true

# The links that switched those services on, plus two more the live stick has on: the SSH server (a gaming
# desktop should not run one by default) and "wait until the clock is synchronised" (delays boot offline).
while IFS= read -r link; do
  rm -f -- "${link}" && log "switched off ${link#/etc/systemd/system/}"
done < <(find /etc/systemd/system -type l \( -name 'pacman-init.service' -o -name 'choose-mirror.service' \
  -o -name 'livecd-*.service' -o -name 'sshd.service' -o -name 'systemd-time-wait-sync.service' \
  -o -name 'etc-pacman.d-gnupg.mount' \))

# 3. Live user. The installer's removeuser step deletes it; if that failed, the passwordless live account
#    would stay, so delete it here. "floppa" cannot be the new account's name (users.conf).
if id floppa >/dev/null 2>&1; then
  userdel -f -r floppa >/dev/null 2>&1 || true
  log "live user removed"
fi
rm -rf -- /home/floppa

# 4. Root account. The live system's root has no password. The installer sets one if the user chose an
#    administrator password; otherwise lock root (the new account can still use sudo).
if [ -z "$(awk -F: '$1 == "root" { print $2 }' /etc/shadow)" ]; then
  passwd -l root >/dev/null && log "root account locked (it had no password)"
fi
# /etc/lsb-release names FloppaOS like /etc/os-release does (a pacman hook keeps it so after package updates).
if [ -f /usr/local/lib/floppaos/lsb-release ]; then
  sh /usr/local/lib/floppaos/lsb-release && log "lsb-release names FloppaOS"
fi
# root's login shell: the live ISO uses zsh (Arch's releng profile); an installed system gets Arch's default, bash.
if [ "$(getent passwd root | cut -d: -f7)" = /usr/bin/zsh ]; then
  usermod -s /bin/bash root && log "root's shell set to bash"
fi

# 5. Package keyring. The live system kept it in RAM, so the copy has none, and without it every update
#    fails with "signature is unknown trust".
if [ ! -s /etc/pacman.d/gnupg/pubring.gpg ] && [ ! -s /etc/pacman.d/gnupg/pubring.kbx ]; then
  pacman-key --init || fail "could not create the package keyring"
  pacman-key --populate || fail "could not add Arch's keys to the package keyring"
  log "package keyring set up"
fi
# gpg leaves helper programs running; they would keep the new disk busy and stop the installer unmounting it.
gpgconf --homedir /etc/pacman.d/gnupg --kill all >/dev/null 2>&1 || true

# 6. 32-bit packages (multilib, used by games) must get updates too: make sure that repository is on.
if grep -q '^#\[multilib\]' /etc/pacman.conf; then
  sed -i '/^#\[multilib\]/{s/^#//;n;s/^#Include/Include/}' /etc/pacman.conf
  log "multilib repository switched on"
fi

# 7. Packages only the live stick needs. (The installer itself is removed in the step after this one.)
#    Removing mkinitcpio-archiso (files in usr/lib/initcpio) makes mkinitcpio's pacman hook rebuild the boot
#    image, and the installer's very next steps build it again. So the hook is switched off for this removal
#    only, by an override of the same name in /etc/pacman.d/hooks; the trap makes sure the override is gone
#    afterwards, also if something fails (otherwise kernel updates would no longer rebuild the boot image).
#    Seen in a VM without hardware acceleration: 8 minutes saved; on a real PC under a minute.
hook_override=/etc/pacman.d/hooks/90-mkinitcpio-install.hook
remove_hook_override() { [ -L "${hook_override}" ] && [ "$(readlink "${hook_override}")" = /dev/null ] && rm -f "${hook_override}"; return 0; }
trap remove_hook_override EXIT
if pacman -Q mkinitcpio-archiso >/dev/null 2>&1 && [ ! -e "${hook_override}" ] && [ ! -L "${hook_override}" ]; then
  mkdir -p /etc/pacman.d/hooks && ln -s /dev/null "${hook_override}"
fi
for p in mkinitcpio-archiso memtest86+ memtest86+-efi edk2-shell livecd-sounds syslinux; do
  if pacman -Q "${p}" >/dev/null 2>&1; then
    if pacman -Rns --noconfirm "${p}" >/dev/null 2>&1; then log "removed package ${p}"; else log "kept package ${p} (another package needs it)"; fi
  fi
done
remove_hook_override

# 8. Keyboard layout for Plasma. On Wayland, Plasma reads the layout from KDE's own setting (kxkbrc), not from
#    the X11 file the installer's keyboard step writes. Make the chosen layout KDE's default for every user.
x11conf=/etc/X11/xorg.conf.d/00-keyboard.conf
xkb_option() { sed -n "s/^[[:space:]]*Option[[:space:]]*\"$1\"[[:space:]]*\"\([^\"]*\)\".*/\1/p" "${x11conf}" | head -n1; }
if [ -f "${x11conf}" ]; then
  layout="$(xkb_option XkbLayout)"; variant="$(xkb_option XkbVariant)"
  model="$(xkb_option XkbModel)";   options="$(xkb_option XkbOptions)"
  if [ -n "${layout}" ]; then
    {
      echo "[Layout]"
      echo "Use=true"
      echo "LayoutList=${layout}"
      echo "VariantList=${variant}"
      [ -n "${model}" ] && echo "Model=${model}"
      [ -n "${options}" ] && { echo "Options=${options}"; echo "ResetOldOptions=true"; }
    } > /etc/xdg/kxkbrc
    log "keyboard layout for Plasma: ${layout}${variant:+ (${variant})}"
  fi
fi

# 9. Host name: the installer writes the one the user typed; never keep the live stick's name.
if [ "$(cat /etc/hostname 2>/dev/null)" = floppaos-live ] || [ "$(cat /etc/hostname 2>/dev/null)" = archiso ]; then
  echo floppaos > /etc/hostname
  log "host name set to floppaos"
fi

log "done"
