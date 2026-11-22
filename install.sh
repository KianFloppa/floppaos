#!/usr/bin/env bash
# FloppaOS Setup Pack (Release A): run on a normal CachyOS (or other KDE Plasma 6) install.
# Installs the FloppaOS look and Floppa Setup for the current user. No admin rights needed, except once for
# kdialog if the system lacks it (asked first, see below).
# Undo with ./uninstall.sh
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Floppa Setup opens its windows with kdialog, a small KDE program. CachyOS's KDE comes without it (seen in
# the VM 2026-11-22), so ask once here. Always pacman -Syu: a kdialog installed with -S alone was newer than
# the rest of the system and did not start ("version Qt_6.12 not found"). Arch-based systems update as a whole.
kdialog_ok() {
  command -v kdialog >/dev/null 2>&1 || return 1
  [ -z "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ] || kdialog --version >/dev/null 2>&1
}
if ! kdialog_ok && command -v pacman >/dev/null 2>&1; then
  if command -v kdialog >/dev/null 2>&1; then
    echo "kdialog, the small KDE program Floppa Setup uses for its windows, does not start: the system needs an update."
  else
    echo "Floppa Setup needs kdialog, a small KDE program, for its windows. This system does not have it yet."
  fi
  ans=n
  if [ -t 0 ]; then
    read -r -p "Do it now? This updates the whole system and asks for your password. [Y/n] " ans || ans=n
  fi
  case "${ans:-y}" in
    [nN]*) echo "Later, in Konsole: sudo pacman -Syu --needed kdialog   (then open Floppa Setup from the start menu)" ;;
    *) sudo pacman -Syu --needed kdialog || echo "kdialog was not installed; try again later: sudo pacman -Syu --needed kdialog" ;;
  esac
fi

bash "${DIR}/look/install.sh"
bash "${DIR}/setup/install.sh"
if [ -n "${WAYLAND_DISPLAY:-}${DISPLAY:-}" ]; then
  (python3 "${HOME}/.local/share/floppaos/floppa-setup.py" --first-run >/dev/null 2>&1 &)
fi
echo "FloppaOS Setup Pack $(cat "${DIR}/VERSION" 2>/dev/null || echo "") installed."
echo "Optional, needs your password: a black login screen too: sudo ${DIR}/look/login-screen.sh"
