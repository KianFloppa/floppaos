#!/usr/bin/env bash
# FloppaOS Phase 4 feasibility: build the CachyOS kernel from its public source (CachyOS/linux-cachyos, GPL-2.0)
# in an Arch container, to see whether it fits a GitHub runner and which CachyOS optimisations survive a self-build.
# Nothing here is published. Runs as root inside archlinux:base-devel (see .github/workflows/kernel.yml).
#
#   build-kernel.sh <linux-cachyos commit> <lto: none|thin> <cpu: generic_v1..generic_v4> <output folder>
#
# The CPU target must be set: the recipe's default (empty) is "native", which would tune the kernel for the
# build machine's own CPU and could crash on other PCs. "generic" alone is not one of the recipe's values.
set -euo pipefail
COMMIT="$1" LTO="$2" CPU="$3" OUT="$4"
mkdir -p "${OUT}" && chmod 777 "${OUT}"   # makepkg runs as the user "builder" and writes the packages here
REPORT="${OUT}/report.txt"
log() { echo "[$(date -u +%H:%M:%S)] $*" | tee -a "${REPORT}"; }

log "Runner: $(nproc) CPUs, $(free -g | awk '/^Mem:/{print $2}') GB memory, $(df -h "${OUT}" | awk 'NR==2{print $4}') disk free"

pacman -Syu --noconfirm --needed --noprogressbar git sudo base-devel >/dev/null
id builder >/dev/null 2>&1 || useradd -m builder
echo 'builder ALL=(ALL) NOPASSWD: /usr/bin/pacman' > /etc/sudoers.d/builder
B=/home/builder
sudo -u builder git clone -q https://github.com/CachyOS/linux-cachyos "${B}/lc"
sudo -u builder git -C "${B}/lc" checkout -q "${COMMIT}"
cd "${B}/lc/linux-cachyos"
log "Recipe: CachyOS/linux-cachyos $(sudo -u builder git -C "${B}/lc" log -1 --format='%h %cs') kernel $(sed -n 's/^_major=//p' PKGBUILD).$(sed -n 's/^_minor=//p' PKGBUILD)"

# The source tarball is signed; import the keys the recipe trusts (its validpgpkeys list).
for key in $(sed -n '/^validpgpkeys=(/,/)/p' PKGBUILD | grep -oE '[0-9A-F]{40}'); do
  sudo -u builder gpg --batch --quiet --keyserver hkps://keyserver.ubuntu.com --recv-keys "${key}" \
    || sudo -u builder gpg --batch --quiet --keyserver hkps://keys.openpgp.org --recv-keys "${key}"
done

# CachyOS's checksum list (b2sums) fits the recipe's default source list, which (with LTO) includes a clang patch.
# For other options, take each source's checksum from that list by name, so every checksum still comes from CachyOS.
pkgvar() {  # pkgvar <array> [option=value ...]: print one array of the recipe, one item per line
  local name="$1"; shift
  sudo -u builder env "$@" bash -c 'source ./PKGBUILD >/dev/null 2>&1; declare -n a="$1"; printf "%s\n" "${a[@]}"' _ "${name}"
}
mapfile -t dsrc < <(pkgvar source)
mapfile -t dsum < <(pkgvar b2sums)
mapfile -t osrc < <(pkgvar source _use_llvm_lto="${LTO}" _processor_opt="${CPU}")
if [ "${#dsrc[@]}" -ne "${#dsum[@]}" ]; then log "The recipe's own lists differ: ${#dsrc[@]} sources, ${#dsum[@]} checksums"; exit 1; fi
osum=()
for src in "${osrc[@]}"; do
  for i in "${!dsrc[@]}"; do
    if [ "${dsrc[i]}" = "${src}" ]; then osum+=("${dsum[i]}"); continue 2; fi
  done
  log "No CachyOS checksum for ${src}"; exit 1
done
if [ "${#osrc[@]}" -ne "${#dsrc[@]}" ]; then
  printf "\n# FloppaOS build: the checksums above, picked by source name for these options\nb2sums=(%s)\n" \
    "$(printf "'%s' " "${osum[@]}")" >> PKGBUILD
  log "Checksums: these options use ${#osrc[@]} of the recipe's ${#dsrc[@]} sources"
fi

# Progress every 10 minutes, so a run that hits the time limit still shows how far it got.
( while sleep 600; do
    log "progress: $(find src -name '*.o' 2>/dev/null | wc -l) object files, $(free -m | awk '/^Mem:/{print $7}') MB memory free, $(df -h "${OUT}" | awk 'NR==2{print $4}') disk free"
  done ) &
progress=$!
trap 'kill "${progress}" 2>/dev/null || true' EXIT

log "Options: _use_llvm_lto=${LTO} _processor_opt=${CPU}; everything else as in the recipe"
t0=$(date +%s)
if ! sudo -u builder env _use_llvm_lto="${LTO}" _processor_opt="${CPU}" _build_debug=no _localmodcfg=no \
       _use_current=no CI=true PKGDEST="${OUT}" \
       makepkg --syncdeps --noconfirm --noprogressbar > "${OUT}/makepkg.log" 2>&1; then
  log "makepkg FAILED after $(( ($(date +%s) - t0) / 60 )) min; last lines:"
  tail -n 60 "${OUT}/makepkg.log" | tee -a "${REPORT}"
  df -h "${OUT}" | tee -a "${REPORT}"
  exit 1
fi
log "makepkg took $(( ($(date +%s) - t0) / 60 )) min"

# Keep the packages first: the report below must never cost the result (it did once: run 44917494861, where a
# missing config line stopped the script after 171 minutes of a successful build).
ls -la "${OUT}"/*.pkg.tar.zst | tee -a "${REPORT}"
# Only the kernel itself is kept as an artifact (GitHub's free artifact storage is small); headers are rebuilt anyway.
mkdir -p "${OUT}/keep" && find "${OUT}" -maxdepth 1 -name '*.pkg.tar.zst' ! -name '*-headers-*' -exec mv {} "${OUT}/keep/" \;

# What the self-built kernel got (the config makepkg actually used); options this kernel does not have are
# reported as "not in this kernel".
set +e +o pipefail
cfg="$(find src -maxdepth 2 -name .config -path '*cachyos*' | head -n1)"
for opt in CACHY SCHED_BORE LTO_CLANG_THIN LTO_NONE GENERIC_CPU X86_64_VERSION X86_NATIVE_CPU HZ PREEMPT \
           TRANSPARENT_HUGEPAGE_ALWAYS AUTOFDO_CLANG PROPELLER_CLANG RUST; do
  line="$(grep -E "^(# )?CONFIG_${opt}[= ]" "${cfg}" | head -n1)"
  echo "${line:-CONFIG_${opt}: not in this kernel}" | tee -a "${REPORT}"
done
df -h "${OUT}" | tee -a "${REPORT}"
chmod -R a+rX "${OUT}"
