#!/usr/bin/env bash
# FloppaOS Setup Pack (Release A): run on a normal CachyOS (or other KDE Plasma 6) install.
# Installs the FloppaOS look and Floppa Setup for the current user. No admin rights needed.
# Undo with ./uninstall.sh
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${DIR}/look/install.sh"
bash "${DIR}/setup/install.sh"
if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
  (python3 "${HOME}/.local/share/floppaos/floppa-setup.py" --first-run >/dev/null 2>&1 &)
fi
echo "FloppaOS Setup Pack $(cat "${DIR}/VERSION" 2>/dev/null || echo "") installed."
