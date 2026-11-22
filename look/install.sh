#!/usr/bin/env bash
# FloppaOS look: one command for KDE Plasma 6. Needs git and an internet connection the first time.
# Installs everything for the current user only (no admin rights). Undo with look/uninstall.sh.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
S="${HOME}/.local/share"
THEME="org.floppaos.desktop"

command -v git >/dev/null || { echo "git not found."; exit 1; }

# 1. Third-party theme parts (icons, window decoration, cursors, Plasma style).
bash "${DIR}/fetch-parts.sh"

# 2. Our own parts: colour scheme, FloppaOS mark, and the FloppaOS global theme (defaults + taskbar layout).
mkdir -p "${S}/color-schemes" "${S}/icons/hicolor/scalable/apps" "${S}/plasma/look-and-feel"
cp -f "${DIR}/color-schemes/FloppaOSBlack.colors" "${S}/color-schemes/"
cp -f "${DIR}/assets/floppaos-start.svg" "${S}/icons/hicolor/scalable/apps/floppaos.svg"
rm -rf "${S}/plasma/look-and-feel/${THEME}"
cp -a "${DIR}/global-theme/${THEME}" "${S}/plasma/look-and-feel/${THEME}"
# The FloppaOS start menu widget (the taskbar layout uses it when it is installed).
kpackagetool6 --type=Plasma/Applet --upgrade "${DIR}/start-menu" >/dev/null 2>&1 \
  || kpackagetool6 --type=Plasma/Applet --install "${DIR}/start-menu" >/dev/null
kbuildsycoca6 --noincremental >/dev/null 2>&1 || true

# 3. Apply it.
bash "${DIR}/apply.sh"
