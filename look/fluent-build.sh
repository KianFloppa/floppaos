#!/usr/bin/env bash
# Builds the Fluent icon theme (vinceliuice/Fluent-icon-theme, GPL-3.0, decision 24) as two icon themes from a
# source checkout, without running Fluent's own install script:
#   Fluent       the standard colours
#   Fluent-dark  the same icons, with light action, place, device and symbolic icons for dark panels (FloppaOS is
#                pure black). Folders it does not change are links to Fluent's.
# This follows what Fluent's install.sh does for these two variants (its "standard" colour; "dark" replaces
# #363636 with #dedede in the same folders). Then tools/icon-audit.py removes the icons named after Microsoft
# products, the Windows logo and other systems' logos (README rule 3); start-here shows the FloppaOS mark. Removed
# icons fall back to KDE's Breeze icons (Inherits).
#
# Usage: look/fluent-build.sh <Fluent source folder> <icons folder>
#   creates <icons folder>/Fluent and <icons folder>/Fluent-dark (replacing old copies)
# Used by packages/floppaos-theme-parts (system-wide) and look/fetch-parts.sh (per user, Setup Pack).
set -euo pipefail
src="$(cd "${1:?Fluent source folder}" && pwd)"
out="${2:?icons folder}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[ -f "${src}/src/index.theme" ] && [ -d "${src}/links" ] || { echo "Not a Fluent icon theme checkout: ${src}"; exit 1; }
mkdir -p "${out}"
out="$(cd "${out}" && pwd)"
std="${out}/Fluent"
dark="${out}/Fluent-dark"
rm -rf "${std}" "${dark}"
mkdir -p "${std}" "${dark}"

# Folders whose icons get light colours in the dark variant, and folders the dark variant shares with Fluent.
dark_dirs="16/actions 16/devices 16/places 22/actions 22/categories 22/devices 22/places 24/actions 24/devices
           24/places 32/actions 32/devices 32/status symbolic"
shared_dirs="scalable 16/mimetypes 16/status 16/panel 22/emblems 22/mimetypes 22/panel 24/animations 24/panel
             32/categories 256"

# Fluent: every size folder, then Fluent's alias links (other icon names that point to the same drawing).
for d in 16 22 24 32 256 scalable symbolic; do
  mkdir -p "${std}/${d}"
  cp -a "${src}/src/${d}/." "${std}/${d}/"
  if [ -d "${src}/links/${d}" ]; then cp -a "${src}/links/${d}/." "${std}/${d}/"; fi
done
sed -e 's/%NAME%/Fluent/' -e 's/^Inherits=hicolor$/Inherits=breeze,hicolor/' "${src}/src/index.theme" > "${std}/index.theme"

# Fluent-dark
for d in ${dark_dirs}; do
  [ -d "${src}/src/${d}" ] || continue
  mkdir -p "${dark}/${d}"
  cp -a "${src}/src/${d}/." "${dark}/${d}/"
  find "${dark}/${d}" -type f -name '*.svg' -exec sed -i 's/#363636/#dedede/g' {} +
  if [ -d "${src}/links/${d}" ]; then cp -a "${src}/links/${d}/." "${dark}/${d}/"; fi
done
for d in ${shared_dirs}; do
  [ -e "${std}/${d}" ] || continue
  parent="$(dirname "${dark}/${d}")"
  mkdir -p "${parent}"
  ln -s "$(realpath --relative-to="${parent}" "${std}/${d}")" "${dark}/${d}"
done
sed -e 's/%NAME%/Fluent dark/' -e 's/^Inherits=hicolor$/Inherits=breeze-dark,hicolor/' "${src}/src/index.theme" \
  > "${dark}/index.theme"

# The index also lists @2x and @3x folders for high-resolution screens: the same (vector) icons.
for t in "${std}" "${dark}"; do
  for m in 2 3; do
    for d in 16 22 24 32 256 scalable; do ln -s "${d}" "${t}/${d}@${m}x"; done
  done
done

# No Microsoft product logos, no Windows or Apple logo (Fluent's own links into removed icons go too).
python3 -I "${here}/../tools/icon-audit.py" strip "${std}" "${here}/assets/floppaos-start.svg"
python3 -I "${here}/../tools/icon-audit.py" strip "${dark}" "${here}/assets/floppaos-start.svg"

# Fluent itself has a few alias links to an icon it does not ship (c8a244f: ten links to scalable/apps/search.svg,
# e.g. kfind). They are removed, so those names fall back to Breeze like the removed logos.
dangling="$(find "${std}" "${dark}" -xtype l -print -delete | wc -l)"
echo "Removed ${dangling} alias links that point to icons Fluent does not have."
[ -z "$(find "${std}" "${dark}" -xtype l -print -quit)" ] || { echo "Broken links are left."; exit 1; }
echo "Fluent and Fluent-dark built in ${out}"
