#!/usr/bin/env bash
# FloppaOS: put the window decoration, cursors and Plasma style into a share folder, straight from their own
# projects (each checked out at one pinned, reviewed commit; see CREDITS.md). Their install scripts are not run:
# this script only copies files and renames two of them.
#
# Usage: parts-build.sh <willow-theme> <WinSur-dark-cursors> <Utterly-Round-Plasma-Style> <share folder>
#   <share folder> is /usr/share (or $pkgdir/usr/share) for the package, ~/.local/share for the Setup Pack.
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ $# -eq 4 ] || { echo "Usage: $0 <willow-theme> <WinSur-dark-cursors> <Utterly-Round-Plasma-Style> <share folder>" >&2; exit 2; }
WILLOW="$1/aurorae-themes"
WINSUR="$2/dist"
UTTERLY="$3/desktoptheme/translucent"
SHARE="$4"
for f in "${WILLOW}/src/dark/blur/decoration.svg" "${WILLOW}/WillowDark/WillowDarkrc" "${WINSUR}/index.theme" \
         "${UTTERLY}/metadata.json" "${DIR}/color-schemes/FloppaOSBlack.colors"; do
  [ -f "${f}" ] || { echo "Missing: ${f}" >&2; exit 1; }
done
AURORAE="${SHARE}/aurorae/themes"
ICONS="${SHARE}/icons"
PLASMA="${SHARE}/plasma/desktoptheme"
mkdir -p "${AURORAE}" "${ICONS}" "${PLASMA}"

# Window decoration: "Willow Dark Blur" and its "Alt" version, put together the way Willow's own
# aurorae-themes/genThemes.sh does it: the button pictures, the blur frame (decoration.svg), and the theme's
# settings file and description, renamed for the blur version. Willow's backup files (*.bak) are left out.
willow() {  # willow <button folder> <theme> <base theme> <shown name> <plugin id>
  local d="${AURORAE}/$2"
  rm -rf "${d}"
  mkdir -p "${d}"
  cp "${WILLOW}/src/dark/$1"/*.svg "${d}/"
  cp "${WILLOW}/src/dark/blur/decoration.svg" "${d}/decoration.svg"
  cp "${WILLOW}/$3/$3rc" "${d}/$2rc"
  sed -e "s|^Name=.*|Name=$4|" -e "s|^X-KDE-PluginInfo-Name=.*|X-KDE-PluginInfo-Name=$5|" \
    "${WILLOW}/$3/metadata.desktop" > "${d}/metadata.desktop"
}
willow icons     WillowDarkBlur    WillowDark    "Willow Dark Blur"     willow-dark-blur-aurorae
willow icons-alt WillowDarkBlurAlt WillowDarkAlt "Willow Dark Blur Alt" willow-dark-blur-alt-aurorae

# Cursors: WinSur Dark, as built by its author (dist/).
rm -rf "${ICONS}/WinSur-dark-cursors"
cp -a "${WINSUR}" "${ICONS}/WinSur-dark-cursors"

# Plasma style: Utterly-Round, its see-through version (desktoptheme/translucent, Plasma id "Utterly-Round").
# FloppaOS adds a colours file so the taskbar and its pop-ups stay pure black: our FloppaOS Black scheme.
rm -rf "${PLASMA}/Utterly-Round"
cp -a "${UTTERLY}" "${PLASMA}/Utterly-Round"
install -m644 "${DIR}/color-schemes/FloppaOSBlack.colors" "${PLASMA}/Utterly-Round/colors"

# Nothing may point outside the copied folders.
if find "${AURORAE}/WillowDarkBlur" "${AURORAE}/WillowDarkBlurAlt" "${ICONS}/WinSur-dark-cursors" \
     "${PLASMA}/Utterly-Round" -xtype l | grep -q .; then
  echo "Broken links in the theme parts." >&2
  exit 1
fi
