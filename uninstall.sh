#!/usr/bin/env bash
# FloppaOS Setup Pack: undo ./install.sh for the current user.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${DIR}/setup/uninstall.sh"
bash "${DIR}/look/uninstall.sh"
if [ -f /etc/plasmalogin.conf.d/10-floppaos.conf ] || [ -f /etc/sddm.conf.d/floppaos.conf ]; then
  echo "The black login screen stays until you run: sudo ${DIR}/look/login-screen.sh --undo"
fi
