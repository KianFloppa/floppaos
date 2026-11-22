#!/usr/bin/env bash
# Signs FloppaOS's own packages and publishes them as a pacman repository on the GitHub release
# "packages-x86_64". Installed FloppaOS systems get their FloppaOS updates from there: iso/build.sh adds the
# [floppaos] repository to the image once keyring/floppaos.gpg exists (keyring/README.md).
#
# Runs in .github/workflows/packages.yml after the build, in an archlinux container, only when the signing key
# is there. Needs:
#   PACKAGE_SIGNING_KEY  the secret signing subkey, ASCII-armored (made on Kian's PC; the main key stays there)
#   GH_TOKEN             a token that may write releases (the workflow's own), and the gh program
#   DRY_RUN=1            optional: sign and check everything, print what would be uploaded, upload nothing
#                        (DRY_RUN_OUT=<folder> keeps the signed repository there)
#
# Usage: tools/publish-packages.sh <folder with the built packages>
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
IN="$(cd "${1:?folder with the built packages}" && pwd)"
TAG="packages-x86_64"
REPO="${GITHUB_REPOSITORY:-KianFloppa/floppaos}"
: "${PACKAGE_SIGNING_KEY:?the signing key is missing (PACKAGE_SIGNING_KEY)}"
[ -s "${ROOT}/keyring/floppaos.gpg" ] || { echo "keyring/floppaos.gpg is missing: nothing to publish."; exit 1; }

WORK="$(mktemp -d)"
export GNUPGHOME="${WORK}/gnupg"
mkdir -m 700 "${GNUPGHOME}"
trap 'gpgconf --kill gpg-agent >/dev/null 2>&1 || true; rm -rf "${WORK}"' EXIT

# The signing key from the secret. Only the subkey's secret part is in it; the main key stays on Kian's PC.
printf '%s\n' "${PACKAGE_SIGNING_KEY}" | gpg --batch --quiet --import 2>/dev/null
main_fpr="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1=="fpr" {print $10; exit}')"
sub_fpr="$(gpg --batch --with-colons --list-secret-keys | awk -F: '$1=="ssb" && $12 ~ /s/ && $2 !~ /[erd]/ {want=1; next} want && $1=="fpr" {print $10; exit}')"
trusted="$(cut -d: -f1 "${ROOT}/keyring/floppaos-trusted" | head -n1)"
[ -n "${sub_fpr}" ] || { echo "The secret has no usable signing subkey."; exit 1; }
[ "${main_fpr}" = "${trusted}" ] || { echo "The secret belongs to another key than keyring/floppaos-trusted."; exit 1; }
echo "Signing with subkey ${sub_fpr} of ${main_fpr}"

# GitHub renames release files with characters other than letters, digits, '.', '-' and '_' (for example the
# '+' in floppaos-shim's version). The repository lists the files under the names they will have.
out="${WORK}/repo"
mkdir "${out}"
for f in "${IN}"/*.pkg.tar.zst; do
  name="$(basename "${f}" | sed 's/[^A-Za-z0-9._-]/./g')"
  cp "${f}" "${out}/${name}"
  gpg --batch --yes --quiet --local-user "${sub_fpr}!" --detach-sign --no-armor \
      --output "${out}/${name}.sig" "${out}/${name}"
done
cd "${out}"
repo-add --quiet --sign --key "${sub_fpr}" floppaos.db.tar.gz ./*.pkg.tar.zst
# floppaos.db and floppaos.files are links; a release needs real files.
for l in floppaos.db floppaos.db.sig floppaos.files floppaos.files.sig; do
  [ -L "${l}" ] && cp --remove-destination "$(readlink -f "${l}")" "${l}"
done

# Check every signature with only the public key from keyring/, the way pacman on a FloppaOS PC will.
check="${WORK}/check"
mkdir -m 700 "${check}"
gpg --homedir "${check}" --batch --quiet --import "${ROOT}/keyring/floppaos.gpg" 2>/dev/null
for s in ./*.sig; do
  gpg --homedir "${check}" --batch --quiet --verify "${s}" "${s%.sig}" 2>/dev/null \
    || { echo "Signature check failed: ${s}"; exit 1; }
done
echo "$(find . -maxdepth 1 -name '*.pkg.tar.zst' | wc -l) packages signed and checked."

notes="FloppaOS's own packages as a pacman repository. Installed FloppaOS systems update from here. Not a download.
Signed with the key in keyring/ (fingerprint ${main_fpr})."
pkgs=(./*.pkg.tar.zst ./*.pkg.tar.zst.sig)
dbs=(floppaos.db floppaos.db.sig floppaos.db.tar.gz floppaos.db.tar.gz.sig floppaos.files floppaos.files.sig
     floppaos.files.tar.gz floppaos.files.tar.gz.sig)
if [ "${DRY_RUN:-}" = 1 ]; then
  echo "DRY_RUN: would upload to release ${TAG} of ${REPO}: ${#pkgs[@]} package files, then ${dbs[*]}"
  [ -n "${DRY_RUN_OUT:-}" ] && cp -a "${out}/." "${DRY_RUN_OUT}/"   # keep the signed repository to look at
  exit 0
fi

if ! gh release view "${TAG}" -R "${REPO}" >/dev/null 2>&1; then
  gh release create "${TAG}" -R "${REPO}" --prerelease --latest=false \
     --title "FloppaOS packages (for pacman, not a download)" --notes "${notes}"
fi
# Packages first, the database last: a PC that updates in between never sees a list with missing files.
gh release upload "${TAG}" -R "${REPO}" --clobber "${pkgs[@]}"
gh release upload "${TAG}" -R "${REPO}" --clobber "${dbs[@]}"
# Remove files of versions that are no longer in the repository.
gh release view "${TAG}" -R "${REPO}" --json assets --jq '.assets[].name' | while read -r a; do
  [ -e "${a}" ] || gh release delete-asset "${TAG}" "${a}" -R "${REPO}" --yes
done
echo "Published: https://github.com/${REPO}/releases/tag/${TAG}" | tee -a "${GITHUB_STEP_SUMMARY:-/dev/null}"
