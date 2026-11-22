#!/usr/bin/env bash
# FloppaOS Phase 2: remove Floppa Setup for the current user.
# The Floppa Launcher and the games stay installed; remove those in the launcher's own settings.
set -euo pipefail
rm -f "${HOME}/.local/share/applications/floppa-setup.desktop" \
      "${HOME}/.config/autostart/floppa-setup.desktop" \
      "${HOME}/.local/share/floppaos/floppa-setup.py" \
      "${HOME}/.local/share/applications/floppaos-pc-check.desktop" \
      "${HOME}/.local/share/floppaos/floppaos-pc-check.py"
echo "Floppa Setup and the FloppaOS PC check removed."
