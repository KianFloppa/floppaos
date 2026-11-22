#!/usr/bin/env bash
# Build the FloppaOS ISO with mkarchiso. Run as root on Arch Linux (or in an Arch container with --privileged).
# Usage: build.sh <folder with the built FloppaOS packages and floppaos.db.tar.gz>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKGREPO="$(cd "${1:?folder with the FloppaOS packages}" && pwd)"
WORK="${WORK:-/tmp/floppaos-iso}"
OUT="${OUT:-${ROOT}/out}"
PROFILE="${WORK}/profile"

[ "$(id -u)" = 0 ] || { echo "Run as root."; exit 1; }
[ -f "${PKGREPO}/floppaos.db.tar.gz" ] || { echo "No floppaos.db.tar.gz in ${PKGREPO}."; exit 1; }
command -v mkarchiso >/dev/null || pacman -S --noconfirm --needed archiso

rm -rf "${WORK}"
mkdir -p "${WORK}" "${OUT}"
cp -r /usr/share/archiso/configs/releng "${PROFILE}"

# Packages
# Arch's tools for cloud images, its text installer, disk cloning and a second boot manager are not needed:
# FloppaOS has its own installer (installer/). Removing them also keeps them off installed systems.
sed -i -E '/^(cloud-init|archinstall|clonezilla|refind)$/d' "${PROFILE}/packages.x86_64"
grep -v '^\s*#' "${ROOT}/iso/packages.extra" | sed '/^\s*$/d' >> "${PROFILE}/packages.x86_64"
sort -u -o "${PROFILE}/packages.x86_64" "${PROFILE}/packages.x86_64"

# Our packages as a local repository (only for building; the finished ISO uses Arch's servers).
# multilib is needed for the 32-bit graphics drivers games use.
sed -i 's/^#\[multilib\]/[multilib]/; /^\[multilib\]/{n;s/^#Include/Include/}' "${PROFILE}/pacman.conf"
# The same pacman.conf (multilib on, without the build-only [floppaos] repository below) goes into the image.
# Otherwise the 32-bit packages games need would get no updates. mkarchiso keeps a pacman.conf from
# airootfs and sets the package's default one aside as .pacnew (the way Arch's own ISO ships /etc/passwd).
install -Dm644 "${PROFILE}/pacman.conf" "${PROFILE}/airootfs/etc/pacman.conf"
# FloppaOS updates (keyring/README.md): once the signing key exists, installed systems get FloppaOS's own
# packages from the signed repository on the "packages-x86_64" release, and the image carries the key.
# Build the ISO only after the packages workflow has published that release once.
if [ -s "${ROOT}/keyring/floppaos.gpg" ]; then
  echo floppaos-keyring >> "${PROFILE}/packages.x86_64"
  cat >> "${PROFILE}/airootfs/etc/pacman.conf" <<'CONF'

# FloppaOS's own packages (look, Floppa Setup, installer parts), signed with the key from floppaos-keyring.
[floppaos]
SigLevel = Required
Server = https://github.com/KianFloppa/floppaos/releases/download/packages-$arch
CONF
fi
cat >> "${PROFILE}/pacman.conf" <<CONF

[floppaos]
SigLevel = Optional TrustAll
Server = file://${PKGREPO}
CONF

# Files on top of releng's
cp -a "${ROOT}/iso/airootfs/." "${PROFILE}/airootfs/"
rm -f "${PROFILE}/airootfs/home/floppa/.keep"
# NetworkManager (needed by the desktop's network applet) manages the network instead of releng's
# systemd-networkd + iwd; two network managers at once fight over the connections.
find "${PROFILE}/airootfs/etc/systemd/system" \( -name 'systemd-networkd*' -o -name 'iwd.service' \
  -o -name 'dbus-org.freedesktop.network1.service' \) -type l -delete
rm -rf "${PROFILE}/airootfs/etc/systemd/system/cloud-init.target.wants"   # cloud-init is not installed (above)
# No SSH server on the live stick (Arch's live system starts one for installing over the network).
rm -f "${PROFILE}/airootfs/etc/systemd/system/multi-user.target.wants/sshd.service"

# The installer runs as root, which has no KDE settings: give the live root account FloppaOS's black colours,
# so the installer's pages match its black sidebar (installer/target-cleanup.sh removes this again).
install -Dm644 "${ROOT}/look/color-schemes/FloppaOSBlack.colors" "${PROFILE}/airootfs/root/.config/kdeglobals"

# "Install FloppaOS" on the live desktop (same entry as in the start menu, from installer/).
# Where the source code of every package in the image is, and the written offer (docs/source-code.md).
install -Dm644 "${ROOT}/docs/source-code.md" "${PROFILE}/airootfs/usr/share/doc/floppaos/SOURCE-CODE.md"
install -Dm644 "${ROOT}/installer/floppaos-install.desktop" "${PROFILE}/airootfs/home/floppa/Desktop/floppaos-install.desktop"
# "FloppaOS PC check" next to it: what works on this PC, for trying FloppaOS from the USB stick on a real PC.
install -Dm644 "${ROOT}/pc-check/floppaos-pc-check.desktop" "${PROFILE}/airootfs/home/floppa/Desktop/floppaos-pc-check.desktop"

# Live user "floppa" (no password; logs in automatically; sudo without password, live system only)
echo 'floppa:x:1000:1000:FloppaOS live user:/home/floppa:/bin/bash' >> "${PROFILE}/airootfs/etc/passwd"
echo 'floppa::14871::::::'                                        >> "${PROFILE}/airootfs/etc/shadow"
echo 'floppa:x:1000:'                                             >> "${PROFILE}/airootfs/etc/group"
echo 'floppa:!*::'                                                >> "${PROFILE}/airootfs/etc/gshadow"

# Boot menu says FloppaOS instead of Arch Linux (Arch's name and logo are Arch's trademarks; research §3).
# Text replacements instead of our own copies, so the menus keep following Arch's releng updates.
find "${PROFILE}/efiboot" "${PROFILE}/grub" "${PROFILE}/syslinux" -type f \( -name '*.conf' -o -name '*.cfg' \) -exec sed -i \
  -e 's/Boot the Arch Linux \(install\|live\) medium/Boot the FloppaOS live system/g' \
  -e 's/It allows you to install Arch Linux or perform system maintenance/It runs FloppaOS from the stick without installing it/g' \
  -e 's/Arch Linux install medium/FloppaOS live/g' \
  -e 's/Arch Linux live medium/FloppaOS live/g' \
  -e 's/install Arch Linux/install FloppaOS/g' \
  -e 's/^MENU TITLE Arch Linux/MENU TITLE FloppaOS/' \
  -e 's/archisosearchuuid=%ARCHISO_UUID%/archisosearchuuid=%ARCHISO_UUID% cow_spacesize=50%/g' {} +
cp "${ROOT}/iso/boot/splash.png" "${PROFILE}/syslinux/splash.png"   # black instead of the Arch logo
# Live system's writable space: archiso's default is 256 MB, too little for Floppa Setup's downloads (research §14).
grep -rq cow_spacesize "${PROFILE}/efiboot/loader/entries" || echo "Warning: cow_spacesize did not reach the boot menu (archiso changed?)"
if grep -rq 'Arch Linux' "${PROFILE}/efiboot/loader/entries" "${PROFILE}/grub/grub.cfg"; then
  echo "Warning: the boot menu still mentions Arch Linux somewhere:"; grep -rn 'Arch Linux' "${PROFILE}/efiboot/loader/entries" "${PROFILE}/grub/grub.cfg" || true
fi

# Name, label and permissions
sed -i \
  -e 's/^iso_name=.*/iso_name="floppaos"/' \
  -e 's/^iso_label=.*/iso_label="FLOPPAOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"/' \
  -e 's|^iso_publisher=.*|iso_publisher="FloppaOS <https://github.com/KianFloppa/floppaos>"|' \
  -e 's/^iso_application=.*/iso_application="FloppaOS Live"/' \
  -e 's/^buildmodes=.*/buildmodes=("iso")/' \
  -e "s/^airootfs_image_tool_options=.*/airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '15' '-b' '1M')/" \
  "${PROFILE}/profiledef.sh"
sed -i 's|^file_permissions=(|file_permissions=(\n  ["/home/floppa"]="1000:1000:750"\n  ["/home/floppa/Desktop"]="1000:1000:755"\n  ["/home/floppa/Desktop/floppaos-install.desktop"]="1000:1000:755"\n  ["/home/floppa/Desktop/floppaos-pc-check.desktop"]="1000:1000:755"\n  ["/etc/sudoers.d/floppa-live"]="0:0:440"\n  ["/usr/local/lib/floppaos/lsb-release"]="0:0:755"|' "${PROFILE}/profiledef.sh"

# A release build (iso.yml with "release") is named after the version instead of the date:
# floppaos-0.1.0-preview-x86_64.iso. It has to match the file VERSION.
if [ -n "${FLOPPAOS_RELEASE:-}" ]; then
  [[ ${FLOPPAOS_RELEASE} =~ ^[0-9]+\.[0-9]+\.[0-9]+(-[a-z0-9.]+)?$ ]] || { echo "Bad release version: ${FLOPPAOS_RELEASE}"; exit 1; }
  [ "${FLOPPAOS_RELEASE}" = "$(cat "${ROOT}/VERSION")" ] || { echo "Release ${FLOPPAOS_RELEASE} does not match VERSION ($(cat "${ROOT}/VERSION"))"; exit 1; }
  sed -i "s/^iso_version=.*/iso_version=\"${FLOPPAOS_RELEASE}\"/" "${PROFILE}/profiledef.sh"
  grep -q "^iso_version=\"${FLOPPAOS_RELEASE}\"$" "${PROFILE}/profiledef.sh" || { echo "iso_version not set"; exit 1; }
fi

mkarchiso -v -r -w "${WORK}/work" -o "${OUT}" "${PROFILE}"
ls -la "${OUT}"
