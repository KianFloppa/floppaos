#!/usr/bin/env bash
# FloppaOS Phase 1: install the third-party theme parts for the current user.
#
# Each part comes from its own project, at one pinned, reviewed commit (see CREDITS.md). We copy the files
# ourselves and do NOT run the projects' own installers:
#  - icons: Fluent (decision 24), built by look/fluent-build.sh;
#  - window decoration (Willow), cursors (WinSur) and Plasma style (Utterly-Round): look/parts-build.sh.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

FLUENT_REPO="https://github.com/vinceliuice/Fluent-icon-theme"
FLUENT_COMMIT="c8a244f571ef8fb47812bdc9dbce76546cedce69"   # 2026-08-31, reviewed 2026-11-22
WILLOW_REPO="https://github.com/doncsugar/willow-theme"
WILLOW_COMMIT="59b4e62ec63a6948e0f2fbc78a5d951b36a7f584"   # branch plasma-6, 2024-04-03, reviewed 2026-11-22
WINSUR_REPO="https://github.com/yeyushengfan258/WinSur-dark-cursors"
WINSUR_COMMIT="022b4aa0a1f8f90d4cd88ed1a16dc7bcd5f87cc8"   # 2020-09-18, reviewed 2026-11-22
UTTERLY_REPO="https://github.com/HimDek/Utterly-Round-Plasma-Style"
UTTERLY_COMMIT="7e011c19382f8afa99daac3226828ce82eaf4f13"  # 2024-08-08, reviewed 2026-11-22
CACHE="${HOME}/.cache/floppaos"
ICONS="${HOME}/.local/share/icons"

fetch() {  # fetch <repo> <commit> <folder>: one pinned commit, checked
  if [ ! -d "$3/.git" ] || [ "$(git -C "$3" rev-parse HEAD 2>/dev/null)" != "$2" ]; then
    rm -rf "$3"
    mkdir -p "$3"
    git -C "$3" init -q
    git -C "$3" remote add origin "$1"
    git -C "$3" fetch -q --depth 1 origin "$2"
    git -C "$3" checkout -q FETCH_HEAD
  fi
  [ "$(git -C "$3" rev-parse HEAD)" = "$2" ] || { echo "Theme parts are not the reviewed version. Delete $3 and run again."; exit 1; }
}
echo "Downloading theme parts if needed (about 130 MB, one time)..."
fetch "${FLUENT_REPO}" "${FLUENT_COMMIT}" "${CACHE}/fluent-${FLUENT_COMMIT:0:7}"
fetch "${WILLOW_REPO}" "${WILLOW_COMMIT}" "${CACHE}/willow-${WILLOW_COMMIT:0:7}"
fetch "${WINSUR_REPO}" "${WINSUR_COMMIT}" "${CACHE}/winsur-${WINSUR_COMMIT:0:7}"
fetch "${UTTERLY_REPO}" "${UTTERLY_COMMIT}" "${CACHE}/utterly-${UTTERLY_COMMIT:0:7}"
# Earlier FloppaOS versions took these parts from NeoWin, a theme collection that also carries Windows icons.
# Its download (about 150 MB) is no longer needed.
rm -rf "${CACHE}"/neowin-*

# Icons: Fluent and Fluent-dark, without the icons that show Microsoft product logos, the Windows logo or other
# systems' logos (README rule 3; they fall back to KDE's Breeze icons). start-here shows the FloppaOS mark.
# The icons that FloppaOS used before ("NeoWin"; they copy Microsoft's own drawings) are removed.
command -v python3 >/dev/null || { echo "python3 is needed (sudo pacman -S python)."; exit 1; }
mkdir -p "${ICONS}"
rm -rf "${ICONS}/NeoWin"
bash "${DIR}/fluent-build.sh" "${CACHE}/fluent-${FLUENT_COMMIT:0:7}" "${ICONS}" >/dev/null

# Window decoration, cursors, and the Plasma style with our pure-black colours for the taskbar and pop-ups.
bash "${DIR}/parts-build.sh" "${CACHE}/willow-${WILLOW_COMMIT:0:7}" "${CACHE}/winsur-${WINSUR_COMMIT:0:7}" \
  "${CACHE}/utterly-${UTTERLY_COMMIT:0:7}" "${HOME}/.local/share"

echo "Theme parts installed."
