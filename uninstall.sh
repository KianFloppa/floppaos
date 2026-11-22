#!/usr/bin/env bash
# FloppaOS Setup Pack: undo ./install.sh for the current user.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bash "${DIR}/setup/uninstall.sh"
bash "${DIR}/look/uninstall.sh"
