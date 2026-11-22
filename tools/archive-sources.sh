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
#   ONLY         optional environment variable: space-separated source package names; only these are done
#                (to redo the ones in FAILED.txt).
#
# Each archive is what Arch Linux's own makepkg --allsource makes from the package's build recipe at the exact
# version in the image (gitlab.archlinux.org/archlinux/packaging/packages/<pkgbase>, tag = version): the
# PKGBUILD, Arch's patches and every upstream source file, with the checksums from the PKGBUILD checked. Git
# sources pinned to a tag or commit are fetched with only that one snapshot (git fetch --depth 1), not their
# whole history; the archive still holds the exact files the package was built from.
#
# Upstream servers are not always there (some block cloud runners, some moved or are gone). When makepkg fails,
# the script tries again with copies: GNU's mirror network for ftp.gnu.org and gmplib.org, GNU's own mirrors of
# Savannah's git (gnulib on GitHub, Savannah's second https address), and the Internet Archive's copy of the
# exact URL. makepkg still checks every file against the checksums in the PKGBUILD, so a copy is only used if it
# is byte for byte the same file. If that fails too, Arch Linux's own source archive of that exact version is
# taken from sources.archlinux.org when it has one (made by Arch with the same makepkg --allsource).
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
    shallow_fetch "${dir}" "${url}" "${url}" "${kind}" "${val}" || rm -rf "${dir}"
  done < <(grep -E '^\s*source(_[a-z0-9_]+)? = ' "${srcinfo}")
}

# One-snapshot bare repository of a tag or commit from FROM; its origin says URL (what the PKGBUILD names).
shallow_fetch() {
  local dir=$1 url=$2 from=$3 kind=$4 val=$5 try
  rm -rf "${dir}"; git init -q --bare "${dir}"
  git -C "${dir}" remote add origin "${url}"
  for try in 1 2; do
    if [ "${kind}" = tag ]; then
      timeout 900 git -C "${dir}" fetch -q --depth 1 "${from}" "refs/tags/${val}:refs/tags/${val}" 2>/dev/null && return 0
    else
      timeout 900 git -C "${dir}" fetch -q --depth 1 "${from}" "${val}" 2>/dev/null \
        && git -C "${dir}" update-ref "refs/heads/pinned-${val}" "${val}" && return 0
    fi
    sleep 20
  done
  return 1
}

# Other places for the same files and repositories (see the top of this file). Only used after a failure.
# mirrors_for URL git|file
mirrors_for() {
  local url=$1 type=$2
  case "${url}" in
    https://git.savannah.gnu.org/git/gnulib.git) echo "https://github.com/coreutils/gnulib.git" ;;
  esac
  case "${url}" in
    https://git.savannah.gnu.org/git/*) echo "https://https.git.savannah.gnu.org/git/${url#https://git.savannah.gnu.org/git/}" ;;
    https://ftp.gnu.org/gnu/*) echo "https://ftpmirror.gnu.org/gnu/${url#https://ftp.gnu.org/gnu/}" ;;
    https://ftp.gnu.org/pub/gnu/*) echo "https://ftpmirror.gnu.org/gnu/${url#https://ftp.gnu.org/pub/gnu/}" ;;
    https://gmplib.org/download/gmp/*) echo "https://ftpmirror.gnu.org/gnu/gmp/${url##*/}" ;;
  esac
  # The Internet Archive keeps files, not git repositories
  [ "${type}" = file ] && echo "https://web.archive.org/web/2026id_/${url}"
  return 0
}

# Fetch every source makepkg could not get from the copies in mirrors_for(), into SRCDEST.
prefetch_mirrors() {
  local srcinfo=$1 srcdest=$2 line netfile name url frag kind val dir alt got
  while IFS= read -r line; do
    netfile=${line#*= }
    url=${netfile#*::}
    if [[ ${url} == git+* ]]; then
      if [[ ${netfile} == *::* ]]; then name=${netfile%%::*}
      else name=${netfile%%#*}; name=${name%%\?*}; name=${name%/}; name=${name##*/}; name=${name%%.git*}; fi
      url=${url#git+}; frag=""; [[ ${url} == *#* ]] && frag=${url#*#}; frag=${frag%\?*}
      url=${url%%#*}; url=${url%%\?*}; kind=${frag%%=*}; val=${frag#*=}
      dir="${srcdest}/${name}"
      [ -d "${dir}" ] && [ -n "$(ls -A "${dir}" 2>/dev/null)" ] && continue
      got=""
      while IFS= read -r alt; do
        [ -n "${alt}" ] || continue
        if [[ ${kind} == tag || ${kind} == commit ]] && shallow_fetch "${dir}" "${url}" "${alt}" "${kind}" "${val}"; then got=1; break; fi
        rm -rf "${dir}"
        if timeout 1800 git clone -q --mirror "${alt}" "${dir}" 2>/dev/null; then git -C "${dir}" remote set-url origin "${url}"; got=1; break; fi
        rm -rf "${dir}"
      done < <(mirrors_for "${url}" git)
      [ -n "${got}" ] && echo "  ${name}: from a mirror"
    elif [[ ${url} =~ ^(https?|ftp):// ]]; then
      if [[ ${netfile} == *::* ]]; then name=${netfile%%::*}; else name=${url##*/}; fi
      [ -s "${srcdest}/${name}" ] && continue
      while IFS= read -r alt; do
        [ -n "${alt}" ] || continue
        if curl -fsSL --retry 2 --connect-timeout 30 --max-time 3600 -o "${srcdest}/${name}.part" "${alt}"; then
          mv "${srcdest}/${name}.part" "${srcdest}/${name}"; echo "  ${name}: from ${alt%%/${url#*://}*}"; break
        fi
        rm -f "${srcdest}/${name}.part"
      done < <(mirrors_for "${url}" file)
    fi
  done < <(grep -E '^\s*source(_[a-z0-9_]+)? = ' "${srcinfo}")
}

run_makepkg() {
  local d=$1 srcdest=$2
  chown -R "${user}:" "${work}"
  # A server that accepts the connection and then sends nothing would otherwise hang the run for hours
  (cd "${d}" && timeout 3600 runuser -u "${user}" -- env SRCDEST="${srcdest}" BUILDDIR="${work}/build" SRCPKGDEST="${work}/srcpkg" \
     makepkg --allsource --holdver --skippgpcheck --nodeps --ignorearch --noconfirm --noprogressbar -f > "${work}/makepkg.log" 2>&1)
}

# Arch Linux's own source archive of exactly this version, if sources.archlinux.org has it.
arch_srcpkg() {
  local base=$1 ver=$2 enc
  enc=$(printf '%s' "${base}-${ver}" | sed -e 's/%/%25/g' -e 's/:/%3A/g' -e 's/+/%2B/g' -e 's/@/%40/g')
  curl -fsSL --retry 2 --connect-timeout 30 --max-time 3600 -o "${work}/srcpkg/${base}-${ver}.src.tar.gz" \
    "https://sources.archlinux.org/sources/packages/${enc}.src.tar.gz" 2>/dev/null \
    && echo "  ${base}: Arch Linux's own source archive (sources.archlinux.org)"
}

archive_one() {
  local base=$1 ver=$2 tag path d srcdest file name size
  tag=${ver//:/-}           # Arch's packaging tags write an epoch "1:2.0-1" as "1-2.0-1"
  path=${base//+/plus}      # and the GitLab project of "libsigc++" is "libsigcplusplus"
  d="${work}/pkg"; srcdest="${work}/srcdest"
  rm -rf "${work}"; mkdir -p "${d%/*}" "${srcdest}" "${work}/build" "${work}/srcpkg"
  timeout 600 git clone -q --depth 1 --branch "${tag}" "https://gitlab.archlinux.org/archlinux/packaging/packages/${path}.git" "${d}" \
    || { echo "${base} ${ver}: recipe not found at gitlab.archlinux.org (tag ${tag})" >> "${failed}"; return 1; }
  chown -R "${user}:" "${work}"
  if [ ! -s "${d}/.SRCINFO" ]; then
    (cd "${d}" && runuser -u "${user}" -- makepkg --printsrcinfo > .SRCINFO 2>/dev/null) || true
  fi
  prefetch_git "${d}/.SRCINFO" "${srcdest}"
  if ! run_makepkg "${d}" "${srcdest}"; then
    local why
    why=$(grep -E 'ERROR|Failure' "${work}/makepkg.log" | head -n 2 | tr '\n' ' ')
    echo "  ${base}: ${why} -> trying copies"
    # A file that failed its checksum (an error page, a changed upload) must not stay for the next try
    grep -q 'did not pass the validity check' "${work}/makepkg.log" && \
      grep -E 'FAILED' "${work}/makepkg.log" | sed -E 's/^ *([^ ]+) \.\.\. FAILED.*/\1/' | while read -r f; do rm -rf "${srcdest:?}/${f}"; done
    prefetch_mirrors "${d}/.SRCINFO" "${srcdest}"
    if ! run_makepkg "${d}" "${srcdest}"; then
      rm -f "${work}/srcpkg/"*
      if ! arch_srcpkg "${base}" "${ver}"; then
        echo "${base} ${ver}: makepkg --allsource failed, also with copies: ${why}$(grep -E 'ERROR|Failure' "${work}/makepkg.log" | head -n 1)" >> "${failed}"
        return 1
      fi
    fi
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
  if [ -n "${ONLY:-}" ] && [[ " ${ONLY} " != *" ${base} "* ]]; then continue; fi
  [[ ${lic} =~ ${COPYLEFT} ]] || continue
  archive_one "${base}" "${ver}" || echo "FAILED ${base} ${ver}"
done < "${list}"
rm -rf "${work}"
echo "Shard ${shard}/${shards}: $(wc -l < "${index}") files, $(wc -l < "${failed}") failed"
