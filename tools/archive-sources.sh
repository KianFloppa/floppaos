#!/bin/bash
# Archive the source code of the copyleft packages (GPL, LGPL, AGPL, MPL, EPL, CDDL, EUPL) in a FloppaOS image,
# for the source code offer (docs/source-code.md). Runs as root in an archlinux:base-devel container.
#
# Usage: archive-sources.sh SOURCES_TSV OUT_DIR [SHARD SHARDS]
#   SOURCES_TSV  sources.tsv from tools/list-iso-packages.py (pkgbase, version, licences, where)
#   OUT_DIR      gets one <pkgbase>-<version>.src.tar.gz per source package (files over 1.9 GiB are split into
#                .part00, .part01, ...; join them with cat), plus index-<SHARD>.tsv and failed-<SHARD>.txt
#   SHARD SHARDS this run does every SHARDS-th package, starting at SHARD (0-based), so several runs can share
#                the work. Default: 0 1 (all).
#   UPLOAD_TO    optional environment variable: a GitHub release tag. Each archive is uploaded there right away
#                (gh release upload) and deleted, so the disk never holds more than one package.
#
# Each archive is what Arch Linux's own makepkg --allsource makes from the package's build recipe at the exact
# version in the image (gitlab.archlinux.org/archlinux/packaging/packages/<pkgbase>, tag = version): the
# PKGBUILD, Arch's patches and every upstream source file, with the checksums from the PKGBUILD checked. Git
# sources pinned to a tag or commit are fetched with only that one snapshot (git fetch --depth 1), not their
# whole history; the archive still holds the exact files the package was built from.
#
# SPDX-License-Identifier: GPL-3.0-or-later
set -uo pipefail

list=${1:?SOURCES_TSV}
out=${2:?OUT_DIR}
shard=${3:-0}
shards=${4:-1}
work=${WORK:-/tmp/floppaos-sources}
COPYLEFT='(GPL|MPL|EPL|CDDL|EUPL)'
user=floppaos-sources

mkdir -p "${out}"
out=$(cd "${out}" && pwd)
id -u "${user}" >/dev/null 2>&1 || useradd -m "${user}"
index="${out}/index-${shard}.tsv"
failed="${out}/failed-${shard}.txt"
: > "${index}"
: > "${failed}"

# GitHub renames asset characters outside [A-Za-z0-9._-]; name the files so they keep their names.
safe() { printf '%s' "$1" | tr -c 'A-Za-z0-9._-' '_'; }

# Fetch git sources that are pinned to a tag or commit as a one-snapshot bare repository where makepkg looks
# for them (SRCDEST/<name>). makepkg --holdver then uses them as they are instead of cloning the whole history.
prefetch_git() {
  local srcinfo=$1 srcdest=$2 line netfile name url frag kind val dir
  while IFS= read -r line; do
    netfile=${line#*= }
    case "${netfile#*::}" in git+*) ;; *) continue ;; esac
    if [[ ${netfile} == *::* ]]; then
      name=${netfile%%::*}
    else
      name=${netfile%%#*}; name=${name%%\?*}; name=${name%/}; name=${name##*/}; name=${name%%.git*}
    fi
    url=${netfile#*::}; url=${url#git+}
    frag=""; [[ ${url} == *#* ]] && frag=${url#*#}; frag=${frag%\?*}
    url=${url%%#*}; url=${url%%\?*}
    kind=${frag%%=*}; val=${frag#*=}
    dir="${srcdest}/${name}"
    [ -e "${dir}" ] && continue
    case "${kind}" in
      tag|commit) ;;
      *) continue ;;   # no pin (or a branch): makepkg clones the whole repository, as usual
    esac
    git init -q --bare "${dir}"
    git -C "${dir}" remote add origin "${url}"
    if [ "${kind}" = tag ]; then
      git -C "${dir}" fetch -q --depth 1 origin "refs/tags/${val}:refs/tags/${val}" 2>/dev/null || { rm -rf "${dir}"; continue; }
    else
      git -C "${dir}" fetch -q --depth 1 origin "${val}" 2>/dev/null && git -C "${dir}" update-ref "refs/heads/pinned-${val}" "${val}" \
        || { rm -rf "${dir}"; continue; }
    fi
  done < <(grep -E '^\s*source(_[a-z0-9_]+)? = ' "${srcinfo}")
}

archive_one() {
  local base=$1 ver=$2 tag path d srcdest file name size
  tag=${ver//:/-}           # Arch's packaging tags write an epoch "1:2.0-1" as "1-2.0-1"
  path=${base//+/plus}      # and the GitLab project of "libsigc++" is "libsigcplusplus"
  d="${work}/pkg"; srcdest="${work}/srcdest"
  rm -rf "${work}"; mkdir -p "${d%/*}" "${srcdest}" "${work}/build" "${work}/srcpkg"
  git clone -q --depth 1 --branch "${tag}" "https://gitlab.archlinux.org/archlinux/packaging/packages/${path}.git" "${d}" \
    || { echo "${base} ${ver}: recipe not found at gitlab.archlinux.org (tag ${tag})" >> "${failed}"; return 1; }
  chown -R "${user}:" "${work}"
  if [ ! -s "${d}/.SRCINFO" ]; then
    (cd "${d}" && runuser -u "${user}" -- makepkg --printsrcinfo > .SRCINFO 2>/dev/null) || true
  fi
  prefetch_git "${d}/.SRCINFO" "${srcdest}"
  chown -R "${user}:" "${work}"
  if ! (cd "${d}" && runuser -u "${user}" -- env SRCDEST="${srcdest}" BUILDDIR="${work}/build" SRCPKGDEST="${work}/srcpkg" \
        makepkg --allsource --holdver --skippgpcheck --nodeps --noconfirm --noprogressbar > "${work}/makepkg.log" 2>&1); then
    echo "${base} ${ver}: makepkg --allsource failed: $(grep -E 'ERROR|==> ERROR|Failure' "${work}/makepkg.log" | head -n 2 | tr '\n' ' ')" >> "${failed}"
    return 1
  fi
  file=$(ls "${work}/srcpkg/"*.src.tar.* 2>/dev/null | head -n 1)
  [ -n "${file}" ] || { echo "${base} ${ver}: no source archive made" >> "${failed}"; return 1; }
  name=$(safe "${base}-${ver}").src.tar.${file##*.src.tar.}
  mv "${file}" "${out}/${name}"
  size=$(stat -c %s "${out}/${name}")
  local files=("${name}")
  if [ "${size}" -gt $((1900 * 1024 * 1024)) ]; then
    (cd "${out}" && split -b 1900M -d "${name}" "${name}.part" && rm -f "${name}")
    mapfile -t files < <(cd "${out}" && ls "${name}".part*)
  fi
  local f sum
  for f in "${files[@]}"; do
    sum=$(sha256sum "${out}/${f}" | cut -d' ' -f1)
    printf '%s\t%s\t%s\t%s\t%s\n' "${base}" "${ver}" "${f}" "$(stat -c %s "${out}/${f}")" "${sum}" >> "${index}"
    if [ -n "${UPLOAD_TO:-}" ]; then
      gh release upload "${UPLOAD_TO}" "${out}/${f}" --clobber --repo "${GITHUB_REPOSITORY}" >/dev/null \
        || { echo "${base} ${ver}: upload of ${f} failed" >> "${failed}"; return 1; }
      rm -f "${out}/${f}"
    fi
  done
  echo "ok ${base} ${ver} ($(numfmt --to=iec "${size}"))"
}

i=0
while IFS=$'\t' read -r base ver lic where; do
  [[ ${base} == \#* || -z ${base} ]] && continue
  i=$((i + 1))
  (( (i - 1) % shards == shard )) || continue
  [ "${where}" = arch ] || continue                   # FloppaOS's own packages: the source is this repository
  [[ ${lic} =~ ${COPYLEFT} ]] || continue
  archive_one "${base}" "${ver}" || echo "FAILED ${base} ${ver}"
done < "${list}"
rm -rf "${work}"
echo "Shard ${shard}/${shards}: $(wc -l < "${index}") files, $(wc -l < "${failed}") failed"
