#!/usr/bin/env bash
# FloppaOS look: apply the FloppaOS global theme for the current user.
# The theme files must already be installed, either per user (look/install.sh)
# or system-wide (packages floppaos-look + floppaos-theme-parts).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${HOME}/.local/share/floppaos"
THEME="org.floppaos.desktop"

for tool in kwriteconfig6 plasma-apply-lookandfeel; do
  command -v "${tool}" >/dev/null || { echo "${tool} not found. Is this KDE Plasma 6?"; exit 1; }
done

# Keep a copy of the current panel layout.
mkdir -p "${DATA}"
CFG="${HOME}/.config/plasma-org.kde.plasma.desktop-appletsrc"
[ -f "${CFG}" ] && cp -f "${CFG}" "${DATA}/appletsrc.backup-$(date +%Y%m%d-%H%M%S)"

# No colour switching by time of day and no tinting from the wallpaper.
kwriteconfig6 --file kdeglobals --group KDE --key AutomaticLookAndFeel false
kwriteconfig6 --file kdeglobals --group General --key accentColorFromWallpaper false

plasma-apply-lookandfeel -a "${THEME}" --resetLayout

# Settings a global theme cannot carry: shortcuts, sounds, night light, window borders.
bash "${DIR}/apply-extras.sh"

echo "FloppaOS look applied. Log out and back in once so everything (shortcuts, cursors) is active."
