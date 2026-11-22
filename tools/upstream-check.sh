#!/usr/bin/env bash
# FloppaOS: is there a newer upstream version of something we build from source? (README Phase 4, "Daily job")
#
#   tools/upstream-check.sh            print one line per source ("ok", "UPDATE" or "??" = could not check)
#   tools/upstream-check.sh --issues   also open one GitHub issue per outdated source (label "upstream"),
#                                      or update the open one when upstream moved on again (needs GH_TOKEN)
#
# Nothing in the repo is changed here. A person reads upstream's changes, bumps the PKGBUILD, and the packages
# workflow builds and tests it. Exit code 1 only if a source could not be checked (so a broken check is noticed).
# Arch packages and Arch's releng profile are not listed: every ISO build takes their newest versions anyway.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ISSUES=false
[ "${1:-}" = "--issues" ] && ISSUES=true

# Value of NAME=... in a file (quotes and trailing comments dropped).
field() { sed -n "s/^$2=['\"]\{0,1\}\([^'\" #]*\).*/\1/p" "${ROOT}/$1" | head -n1; }
# True if version $2 is newer than version $1.
newer() { [ "$1" != "$2" ] && [ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n1)" = "$2" ]; }
json() { python3 -I -c "import json,sys; d=json.load(sys.stdin); print(eval(sys.argv[1], {'d': d}) or '')" "$1"; }

unreadable=0
outdated=0

issue() {  # issue <name> <ours> <latest> <changes url> <file>
  local name="$1" ours="$2" latest="$3" changes="$4" file="$5"
  local title="Upstream update: ${name} ${latest} (we build ${ours})"
  local body
  body="Found by the daily upstream check (\`tools/upstream-check.sh\`, workflow \`upstream\`).

- What: **${name}**
- We build: \`${ours}\` (\`${file}\`)
- Upstream now: \`${latest}\`
- Changes: ${changes}

To do:
- [ ] Read upstream's changes (new or removed options, licence, anything that touches our files)
- [ ] Bump \`${file}\` (version and checksum, or the pinned commit after reviewing it)
- [ ] Let the \`packages\` workflow build it (for Calamares also validate \`installer/calamares/modules\`, see installer/README.md)
- [ ] If it is part of the ISO: build one and test it in the VM"
  gh label create upstream --color c5def5 --description "A newer upstream version of something FloppaOS builds" >/dev/null 2>&1 || true
  local open
  open="$(gh issue list --label upstream --state open --limit 100 --json number,title \
    --jq ".[] | select(.title | startswith(\"Upstream update: ${name} \")) | \"\(.number)|\(.title)\"" | head -n1)"
  if [ -z "${open}" ]; then
    gh issue create --title "${title}" --label upstream --body "${body}" >/dev/null && echo "   opened an issue"
  elif [ "${open#*|}" != "${title}" ]; then
    gh issue edit "${open%%|*}" --title "${title}" --body "${body}" >/dev/null && echo "   updated issue #${open%%|*}"
  else
    echo "   issue #${open%%|*} is already open"
  fi
}

check() {  # check <name> <ours> <latest> <changes url> <file> <version|commit>
  local name="$1" ours="$2" latest="$3" changes="$4" file="$5" kind="$6"
  if [ -z "${ours}" ] || [ -z "${latest}" ]; then
    echo "?? ${name}: could not read the version (ours: '${ours}', upstream: '${latest}')"
    unreadable=$((unreadable + 1)); return
  fi
  if [ "${ours}" = "${latest}" ] || { [ "${kind}" = version ] && ! newer "${ours}" "${latest}"; }; then
    echo "ok ${name} ${ours}"; return
  fi
  echo "UPDATE ${name}: we build ${ours}, upstream has ${latest} (${changes})"
  outdated=$((outdated + 1))
  if ${ISSUES}; then issue "${name}" "${ours}" "${latest}" "${changes}" "${file}"; fi
}

# Calamares (installer): releases on Codeberg.
ours="$(field packages/calamares/PKGBUILD pkgver)"
latest="$(curl -fsSL -m 30 https://codeberg.org/api/v1/repos/Calamares/calamares/releases/latest 2>/dev/null \
  | json "d.get('tag_name', '').lstrip('v')" 2>/dev/null || true)"
check calamares "${ours}" "${latest}" "https://codeberg.org/Calamares/calamares/releases/tag/v${latest}" \
  packages/calamares/PKGBUILD version

# ckbcomp (keyboard picture in the installer): Debian's console-setup tags on Salsa, newest first.
ours="$(field packages/ckbcomp/PKGBUILD pkgver)"
latest="$(curl -fsSL -m 30 'https://salsa.debian.org/api/v4/projects/installer-team%2Fconsole-setup/repository/tags?order_by=updated&per_page=20' 2>/dev/null \
  | json "next((t['name'] for t in d if __import__('re').fullmatch(r'[0-9]+(\.[0-9]+)+', t['name'])), '')" 2>/dev/null || true)"
check ckbcomp "${ours}" "${latest}" "https://salsa.debian.org/installer-team/console-setup/-/tags/${latest}" \
  packages/ckbcomp/PKGBUILD version

# shim (Secure Boot, decision 27): Fedora's Microsoft-signed build; Fedora's package database (mdapi) says which
# signed shim-x64 its development branch ships now.
ours="$(field packages/floppaos-shim/PKGBUILD pkgver)"
latest="$(curl -fsSL -m 30 https://mdapi.fedoraproject.org/rawhide/pkg/shim-x64 2>/dev/null \
  | json "'%s+fedora+%s' % (d['version'], d['release']) if d.get('version') else ''" 2>/dev/null || true)"
check shim "${ours}" "${latest}" "https://koji.fedoraproject.org/koji/packageinfo?packageID=14502" \
  packages/floppaos-shim/PKGBUILD version

# SBAT: shim refuses GRUB generations that its revocation list names. secureboot/floppaos-secureboot.sh writes
# the generation that matches the installed GRUB version; a newer revocation needs a GRUB with the fix and a new
# line in that table.
ours="$(sed -n 's/.*for v in "\([0-9.]*\) \([0-9]*\)".*/\2/p' "${ROOT}/secureboot/floppaos-secureboot.sh" | head -n1)"
latest="$(curl -fsSL -m 30 https://raw.githubusercontent.com/rhboot/shim/main/SbatLevel_Variable.txt 2>/dev/null \
  | sed -n 's/^grub,\([0-9]\+\)$/\1/p' | sort -n | tail -n1 || true)"
check "sbat-grub-generation" "${ours}" "${latest}" "https://github.com/rhboot/shim/blob/main/SbatLevel_Variable.txt" \
  secureboot/floppaos-secureboot.sh version

# Pinned, reviewed commits of theme parts: any new commit is news (it gets reviewed before we move the pin).
#   Fluent: the icons (decision 24). Willow: window decoration (its Plasma 6 version lives on the branch
#   plasma-6). WinSur: cursors. Utterly-Round: Plasma style.
pinned() {  # pinned <name> <PKGBUILD variable> <fetch-parts.sh variable> <repository URL> [branch]
  local ours pack latest ref="HEAD"
  [ -n "${5:-}" ] && ref="refs/heads/$5"
  ours="$(field packages/floppaos-theme-parts/PKGBUILD "$2")"
  pack="$(field look/fetch-parts.sh "$3")"
  if [ "${ours}" != "${pack}" ]; then
    echo "?? $1: packages/floppaos-theme-parts/PKGBUILD (${ours:0:7}) and look/fetch-parts.sh (${pack:0:7}) pin different commits"
    unreadable=$((unreadable + 1))
  fi
  latest="$(git ls-remote "$4" "${ref}" 2>/dev/null | cut -f1 | head -n1 || true)"
  check "$1" "${ours}" "${latest}" "$4/compare/${ours:0:7}...${latest:0:7}" packages/floppaos-theme-parts/PKGBUILD commit
}
pinned fluent _fluent FLUENT_COMMIT https://github.com/vinceliuice/Fluent-icon-theme
pinned willow _willow WILLOW_COMMIT https://github.com/doncsugar/willow-theme plasma-6
pinned winsur _winsur WINSUR_COMMIT https://github.com/yeyushengfan258/WinSur-dark-cursors
pinned utterly-round _utterly UTTERLY_COMMIT https://github.com/HimDek/Utterly-Round-Plasma-Style

echo "${outdated} outdated, ${unreadable} not checked."
[ "${unreadable}" -eq 0 ]
