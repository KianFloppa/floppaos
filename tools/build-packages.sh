#!/usr/bin/env bash
# Builds every package in packages/ and makes a pacman repository (floppaos.db) from them.
# Used by .github/workflows/packages.yml and iso.yml, in an archlinux:base-devel container, as root.
#
# Usage: tools/build-packages.sh <output folder> [cache folder]
#
# Two kinds of packages:
#  - FloppaOS's own (packages/floppaos-*): small; built every time, without installing dependencies
#    (they depend on each other, and pacman cannot install those from Arch's servers). Their few build
#    tools (librsvg, plymouth, grub and noto-fonts for floppaos-defaults) are installed by the workflows' "Tools" step.
#  - Compiled third-party packages (every other folder, e.g. packages/calamares): their build dependencies
#    are installed with pacman, and the built package is kept in the cache folder under a fingerprint of
#    the package folder. The slow compile only happens again when that folder changes.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${1:?output folder}"
CACHE="${2:-}"
mkdir -p "${OUT}"
OUT="$(cd "${OUT}" && pwd)"

[ "$(id -u)" = 0 ] || { echo "Run as root (in the build container)."; exit 1; }
id builder >/dev/null 2>&1 || useradd -m builder
# makepkg refuses to run as root; the builder user may install build dependencies with pacman.
echo 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/floppaos-builder
chmod 440 /etc/sudoers.d/floppaos-builder
chown -R builder:builder "${ROOT}/packages"
git config --global --add safe.directory "${ROOT}"

# Copies the built packages from folder $1 to folder $2, without the separate debug-symbols packages that
# Arch's makepkg makes for compiled programs (about 50 MB for Calamares, not needed on FloppaOS).
copy_packages() {
  find "$1" -maxdepth 1 -name '*.pkg.tar.zst' ! -name '*-debug-*' -exec cp -t "$2/" {} +
}

fingerprint() {  # of the files git tracks in a package folder (so downloads and build output don't count)
  git -C "${ROOT}" ls-files -s -- "packages/$1" | sha256sum | cut -c1-16
}

for dir in "${ROOT}"/packages/*/; do
  name="$(basename "${dir}")"
  if [ "${name}" = floppaos-keyring ] && [ ! -s "${ROOT}/keyring/floppaos.gpg" ]; then
    echo "floppaos-keyring: skipped, there is no signing key yet (keyring/README.md)"
    continue
  fi
  echo "::group::${name}"
  if [[ "${name}" == floppaos-* ]]; then
    (cd "${dir}" && sudo -u builder makepkg --force --nodeps --noconfirm)
    copy_packages "${dir}" "${OUT}"
  else
    key="$(fingerprint "${name}")"
    cached="${CACHE:+${CACHE}/${name}-${key}}"
    if [ -n "${cached}" ] && compgen -G "${cached}/*.pkg.tar.zst" >/dev/null; then
      echo "${name}: using the cached build (fingerprint ${key})"
      copy_packages "${cached}" "${OUT}"
    else
      echo "${name}: compiling (fingerprint ${key}, not in the cache)"
      (cd "${dir}" && sudo -u builder makepkg --force --syncdeps --noconfirm)
      copy_packages "${dir}" "${OUT}"
      if [ -n "${cached}" ]; then
        mkdir -p "${cached}"
        copy_packages "${dir}" "${cached}"
        # keep only this fingerprint of the package in the cache
        find "${CACHE}" -mindepth 1 -maxdepth 1 -type d -name "${name}-*" ! -name "${name}-${key}" -exec rm -rf {} +
      fi
    fi
  fi
  echo "::endgroup::"
done

cd "${OUT}"
repo-add --quiet floppaos.db.tar.gz ./*.pkg.tar.zst
ls -la "${OUT}"
