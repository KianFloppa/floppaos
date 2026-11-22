#!/usr/bin/env bash
# Renders the installer images from their SVG sources (needs rsvg-convert, from librsvg).
# The PNGs are committed, so building FloppaOS does not need this; run it after changing an SVG.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="${here}/../calamares/branding/floppaos"
rsvg-convert -w 256 -h 256 "${here}/logo.svg" -o "${out}/logo.png"
rsvg-convert -w 800 -h 240 "${here}/welcome.svg" -o "${out}/welcome.png"
echo "Rendered ${out}/logo.png and ${out}/welcome.png"
