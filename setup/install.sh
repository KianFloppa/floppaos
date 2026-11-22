#!/usr/bin/env bash
# FloppaOS Phase 2: install Floppa Setup for the current user.
# Adds "Floppa Setup" to the start menu and shows it at login until the Floppa Launcher is installed.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATA="${HOME}/.local/share/floppaos"
APPS="${HOME}/.local/share/applications"
AUTO="${HOME}/.config/autostart"

command -v python3 >/dev/null || { echo "python3 is needed for Floppa Setup."; exit 1; }
mkdir -p "${DATA}" "${APPS}" "${AUTO}"
cp -f "${DIR}/floppa-setup.py" "${DATA}/floppa-setup.py"
chmod +x "${DATA}/floppa-setup.py"

ICON="applications-games"
[ -f "${HOME}/.local/share/icons/hicolor/scalable/apps/floppaos.svg" ] && ICON="floppaos"

entry() {   # file, extra argument
  cat > "$1" <<DESKTOP
[Desktop Entry]
Type=Application
Name=Floppa Setup
Comment=Check and set up the Floppa Launcher, the games and FloppaNet
Exec=python3 "${DATA}/floppa-setup.py"$2
Icon=${ICON}
Terminal=false
Categories=Game;Settings;
DESKTOP
}
entry "${APPS}/floppa-setup.desktop" ""
# FloppaOS PC check (read-only hardware report), start menu only.
cp -f "${DIR}/../pc-check/floppaos-pc-check.py" "${DATA}/floppaos-pc-check.py"
chmod +x "${DATA}/floppaos-pc-check.py"
sed -e "s|^Exec=.*|Exec=python3 \"${DATA}/floppaos-pc-check.py\"|" -e "s|^Icon=.*|Icon=${ICON}|" \
  "${DIR}/../pc-check/floppaos-pc-check.desktop" > "${APPS}/floppaos-pc-check.desktop"
entry "${AUTO}/floppa-setup.desktop" " --first-run"
echo "Floppa Setup and FloppaOS PC check installed (start menu)."
