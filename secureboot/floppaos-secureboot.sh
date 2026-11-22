#!/usr/bin/env bash
# FloppaOS Secure Boot: lets FloppaOS start with Secure Boot on, next to Windows (decision 27).
#
# How it works: a boot loader signed by Microsoft (shim, from Fedora; package floppaos-shim) starts GRUB.
# GRUB and the Linux kernels are signed with a key made on this PC (a "Machine Owner Key", MOK). The key is
# added to shim's list once, on a blue screen (MokManager) at the next start, with a one-time code. After
# that FloppaOS starts with Secure Boot on. Microsoft's keys in the firmware are not touched, so Windows
# keeps working.
#
#   floppaos-secureboot setup [--code-file FILE]   set it up (the installer's "Secure Boot" tick box runs this)
#   floppaos-secureboot enroll [--code-file FILE]  ask again to add the key at the next start (prints a new code)
#   floppaos-secureboot status                     what is set up, signed and confirmed
#   floppaos-secureboot update                     rebuild and sign GRUB, copy shim, sign kernels (pacman hook)
#   floppaos-secureboot sign-kernels               sign new kernels (pacman hook after kernel updates)
#   floppaos-secureboot check                      at every start: forget the code once the key is confirmed
#   floppaos-secureboot remind                     at login (as the user): show the code until it is confirmed
#   floppaos-secureboot off                        back to plain GRUB (turn Secure Boot off in the firmware first)
#
# The code is 8 digits: MokManager uses the firmware's US keyboard layout, and digits are in the same place on
# every layout. The code only confirms this PC's own key at the next start; it is not a password.
# SPDX-License-Identifier: GPL-3.0-or-later
set -euo pipefail

LABEL="FloppaOS"                              # boot entry name and folder on the EFI partition (installer: efiBootloaderId)
STATE=/var/lib/floppaos-secureboot
KEY="${STATE}/MOK.key"                        # private key, root only
CRT="${STATE}/MOK.crt"
DER="${STATE}/MOK.der"                        # the same certificate in the format mokutil wants
CODE_FILE="${STATE}/enroll-code"              # shown by the reminder until the key is confirmed, then deleted
SHIM=/usr/share/floppaos-shim
GRUB_LIB=/usr/lib/grub/x86_64-efi
SBAT_CSV="${STATE}/sbat.csv"                  # GRUB's SBAT data, made by grub_sbat (see there)

# GRUB may not load modules from the disk while Secure Boot is on (they are not signed), so every module the
# boot menu can need is built into the signed GRUB file: disks and file systems, encryption, the FloppaOS menu
# theme (gfxterm, png, fonts), starting Windows (chain, ntfs), and whatever /boot/grub/grub.cfg loads.
GRUB_MODULES="all_video bli boot btrfs cat chain configfile cpuid cryptodisk echo efifwsetup efinet ext2 f2fs fat
 font gcry_rijndael gcry_sha256 gcry_sha512 gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus
 iso9660 jpeg keystatus linux loadenv loopback ls lsefi lsefimmap lsefisystab luks luks2 lvm mdraid09 mdraid1x
 memdisk minicmd normal ntfs part_apple part_gpt part_msdos password_pbkdf2 png probe reboot regexp search
 search_fs_file search_fs_uuid search_label serial sleep smbios squash4 test tpm true video xfs zstd"

say() { printf '%s\n' "$*"; }
die() { printf 'floppaos-secureboot: %s\n' "$*" >&2; exit 1; }
need_root() { [ "$(id -u)" -eq 0 ] || die "run it as root (sudo floppaos-secureboot $1)"; }
is_setup() { [ -f "${KEY}" ] && [ -f "${CRT}" ] && [ -f "${DER}" ]; }
efivars() { [ -d /sys/firmware/efi/efivars ] && [ -n "$(ls -A /sys/firmware/efi/efivars 2>/dev/null)" ]; }

esp_path() {  # the mounted EFI system partition
  local p
  p="$(bootctl --print-esp-path 2>/dev/null || true)"
  if [ -n "${p}" ] && [ -d "${p}/EFI" ]; then printf '%s\n' "${p}"; return; fi
  for p in /boot/efi /efi /boot; do
    if mountpoint -q "${p}" && [ "$(findmnt -n -o FSTYPE --target "${p}")" = vfat ]; then printf '%s\n' "${p}"; return; fi
  done
  die "no mounted EFI system partition found (/boot/efi)"
}

code_from() {  # code_from [file]: 8 digits from the file, or a new random code
  local c
  if [ -n "${1:-}" ]; then
    c="$(tr -cd '0-9' < "$1")"
    [ "${#c}" -eq 8 ] || die "the code in $1 must be 8 digits"
  else
    c="$(shuf -i 10000000-99999999 -n 1 --random-source=/dev/urandom)"
  fi
  printf '%s\n' "${c}"
}

make_key() {
  install -d -m 755 "${STATE}"   # the key inside stays root-only; the reminder reads the code
  is_setup && return 0
  local host
  host="$(cat /etc/hostname 2>/dev/null || true)"
  ( umask 077
    openssl req -new -x509 -newkey rsa:2048 -nodes -sha256 -days 36500 \
      -subj "/CN=FloppaOS Secure Boot key (${host:-this PC}, $(date +%F))/" \
      -keyout "${KEY}" -out "${CRT}" 2>/dev/null ) || die "could not make the key"
  openssl x509 -in "${CRT}" -outform DER -out "${DER}"
  chmod 600 "${KEY}"
  chmod 644 "${CRT}" "${DER}"
  say "Made this PC's Secure Boot key (${CRT})."
}

signed() { sbverify --cert "${CRT}" "$1" >/dev/null 2>&1; }
sign() {  # sign <EFI file>: signs it with this PC's key unless it already is
  signed "$1" && return 0
  sbsign --key "${KEY}" --cert "${CRT}" --output "$1.signed" "$1" >/dev/null 2>&1 || die "could not sign $1"
  cat "$1.signed" > "$1"
  rm -f "$1.signed"
  signed "$1" || die "$1 is not signed after signing"
}

sign_kernels() {
  local k
  for k in /boot/vmlinuz-*; do
    [ -f "${k}" ] || continue
    signed "${k}" && continue
    sign "${k}"
    say "Signed ${k}."
  done
}

grub_modules() {  # the module list above plus what grub.cfg loads, only modules this GRUB has
  local m list
  list="${GRUB_MODULES} $(sed -n 's/^[[:space:]]*insmod[[:space:]]\+\([a-z0-9_]\+\).*/\1/p' /boot/grub/grub.cfg 2>/dev/null | sort -u | tr '\n' ' ')"
  for m in ${list}; do
    [ -f "${GRUB_LIB}/${m}.mod" ] && printf '%s ' "${m}"
  done | tr ' ' '\n' | sort -u | tr '\n' ' '
}

# SBAT: shim refuses GRUB files whose "grub" generation is lower than the newest revocation it knows
# (github.com/rhboot/shim, SbatLevel_Variable.txt). Arch's /usr/share/grub/sbat.csv still says generation 4 for
# GRUB 2.16, but 2.16 has the fixes of every revocation up to generation 7 (February 2025 CVEs: 5; November 2025,
# fixed in 2.14: 6; CVE-2026-97876, fixed in 2.16: 7). So FloppaOS writes the generation that matches the
# installed GRUB version. tools/upstream-check.sh says when shim revokes a newer generation.
grub_sbat() {
  local full up v gen=""
  full="$(grub-install --version 2>/dev/null | awk '{print $NF}')"   # e.g. 2:2.16-1
  up="${full#*:}"
  up="${up%%-*}"                                                    # 2.16
  for v in "2.16 7" "2.14 6" "2.12 4"; do                           # newest first: GRUB version, generation
    if [ "$(printf '%s\n%s\n' "${v% *}" "${up}" | sort -V | head -n1)" = "${v% *}" ]; then gen="${v#* }"; break; fi
  done
  [ -n "${gen}" ] || die "GRUB ${full:-?} is too old for Secure Boot (2.12 or newer needed)"
  printf '%s\n' "sbat,1,SBAT Version,sbat,1,https://github.com/rhboot/shim/blob/main/SBAT.md" \
    "grub,${gen},Free Software Foundation,grub,${up},https://www.gnu.org/software/grub/" \
    "grub.arch,1,Arch Linux,grub,${full},https://archlinux.org/packages/core/x86_64/grub/" > "${SBAT_CSV}"
}

build_grub() {  # build_grub <esp>: GRUB with all modules inside, signed, in <esp>/EFI/FloppaOS/grubx64.efi
  local esp="$1" mods
  grub_sbat
  mods="$(grub_modules)"
  grub-install --target=x86_64-efi --efi-directory="${esp}" --bootloader-id="${LABEL}" --no-nvram \
    --modules="${mods}" --sbat="${SBAT_CSV}" >/dev/null 2>&1 || die "grub-install failed"
  sign "${esp}/EFI/${LABEL}/grubx64.efi"
  say "Built and signed GRUB (${esp}/EFI/${LABEL}/grubx64.efi)."
}

ours() {  # ours <file>: a boot file FloppaOS may replace (GRUB or shim), not Windows' or another system's
  [ -f "$1" ] && grep -a -q -e 'grub_efidisk' -e 'UEFI SHIM' "$1"
}

put_shim() {  # put_shim <esp>: shim + MokManager in front of GRUB, also at the fallback path if that is ours
  local esp="$1" d="$1/EFI/${LABEL}" b="$1/EFI/BOOT"
  [ -f "${SHIM}/shimx64.efi" ] && [ -f "${SHIM}/mmx64.efi" ] || die "the shim files are missing (package floppaos-shim)"
  install -m 644 "${SHIM}/shimx64.efi" "${d}/shimx64.efi"
  install -m 644 "${SHIM}/mmx64.efi" "${d}/mmx64.efi"
  if [ ! -e "${b}/BOOTX64.EFI" ] || ours "${b}/BOOTX64.EFI"; then
    install -d "${b}"
    install -m 644 "${SHIM}/shimx64.efi" "${b}/BOOTX64.EFI"
    install -m 644 "${SHIM}/mmx64.efi" "${b}/mmx64.efi"
    install -m 644 "${d}/grubx64.efi" "${b}/grubx64.efi"
    rm -f "${b}/fbx64.efi"   # shim would start the fallback tool instead of GRUB
  else
    say "Left ${b}/BOOTX64.EFI alone (it belongs to another system)."
  fi
}

boot_entry() {  # boot_entry <esp> <file>: the firmware's "FloppaOS" entry starts \EFI\FloppaOS\<file>, first in the order
  local esp="$1" file="$2" src dev disk part n
  if ! efivars || ! efibootmgr >/dev/null 2>&1; then
    say "Firmware boot entries can't be changed here; the PC starts FloppaOS through the fallback path."
    return 0
  fi
  src="$(findmnt -n -o SOURCE --target "${esp}")"
  dev="$(basename "${src}")"
  disk="/dev/$(lsblk -n -o PKNAME "${src}" | head -n1)"
  part="$(cat "/sys/class/block/${dev}/partition" 2>/dev/null || true)"
  [ -b "${disk}" ] && [ -n "${part}" ] || { say "Could not find the disk of ${src}; boot entry not changed."; return 0; }
  for n in $(efibootmgr | sed -n "s/^Boot\([0-9A-Fa-f]\{4\}\)\*\{0,1\} ${LABEL}[[:space:]].*/\1/p"); do
    efibootmgr -q -b "${n}" -B || true
  done
  efibootmgr -q --create --disk "${disk}" --part "${part}" --label "${LABEL}" --loader "\\EFI\\${LABEL}\\${file}" \
    || { say "Could not write the boot entry; the PC starts FloppaOS through the fallback path."; return 0; }
  say "Boot entry \"${LABEL}\" starts \\EFI\\${LABEL}\\${file}."
}

key_state() {  # prints enrolled, pending or missing
  local out fp
  out="$(mokutil --test-key "${DER}" 2>&1 || true)"
  case "${out}" in
    *"already enrolled"*) say enrolled; return ;;
    *"enrollment request"*) say pending; return ;;
  esac
  fp="$(openssl x509 -in "${CRT}" -noout -fingerprint -sha1 | cut -d= -f2 | tr -d ':' | tr 'A-F' 'a-f')"
  if mokutil --list-new 2>/dev/null | tr -d ':' | tr 'A-F' 'a-f' | grep -q "${fp}"; then say pending; else say missing; fi
}

enroll() {  # enroll [code file]: ask shim to add this PC's key at the next start
  local code hash state
  efivars || die "the firmware's variables are not reachable (start FloppaOS in UEFI mode)"
  state="$(key_state)"
  if [ "${state}" = enrolled ]; then
    rm -f "${CODE_FILE}"
    say "The key is already confirmed. Nothing to do."
    return 0
  fi
  code="$(code_from "${1:-}")"
  [ "${state}" = pending ] && mokutil --revoke-import >/dev/null 2>&1 || true
  hash="$(mktemp)"
  mokutil --generate-hash="${code}" > "${hash}"
  if ! mokutil --import "${DER}" --hash-file "${hash}" >/dev/null 2>&1; then
    rm -f "${hash}"
    die "mokutil could not ask for the key (firmware variables full or locked?)"
  fi
  rm -f "${hash}"
  [ "$(key_state)" = pending ] || die "the request for the key was not saved"
  printf '%s\n' "${code}" > "${CODE_FILE}"
  chmod 644 "${CODE_FILE}"
  systemctl enable floppaos-secureboot-check.service >/dev/null 2>&1 || true
  if [ ! -t 1 ]; then   # the installer and the reminder show the code themselves; keep it out of logs
    say "Asked to confirm the key at the next start (code saved for the reminder)."
    return 0
  fi
  say ""
  say "One step left, at the next start of the PC:"
  say "  1. A blue screen appears (\"Press any key to perform MOK management\"). Press any key within 10 seconds."
  say "  2. Choose \"Enroll MOK\", then \"Continue\", then \"Yes\"."
  say "  3. At \"Password:\" type the code ${code:0:4} ${code:4:4} (only the 8 digits) and press Enter."
  say "  4. Choose \"Reboot\". Then FloppaOS also starts with Secure Boot on."
}

cmd_setup() {
  local code_file=""
  [ "${1:-}" = --code-file ] && code_file="${2:-}"
  need_root setup
  local t
  for t in grub-install sbsign sbverify mokutil efibootmgr openssl; do
    command -v "${t}" >/dev/null || die "${t} is missing"
  done
  [ -d /sys/firmware/efi ] || die "this PC started in BIOS mode; Secure Boot needs UEFI"
  local esp
  esp="$(esp_path)"
  make_key
  sign_kernels
  build_grub "${esp}"
  put_shim "${esp}"
  boot_entry "${esp}" shimx64.efi
  # The confirmation request is the last part. If the firmware refuses it now, everything else stays set up:
  # an empty code file makes the login reminder offer a new code (pkexec floppaos-secureboot enroll).
  if ! ( enroll "${code_file}" ); then
    : > "${CODE_FILE}"
    chmod 644 "${CODE_FILE}"
    systemctl enable floppaos-secureboot-check.service >/dev/null 2>&1 || true
    say "Could not ask for the key confirmation now; after the next login FloppaOS offers a new code."
  fi
}

cmd_update() {  # pacman hook after GRUB or shim updates; does nothing unless Secure Boot support is set up
  is_setup || exit 0
  need_root update
  local esp
  esp="$(esp_path)"
  build_grub "${esp}"
  put_shim "${esp}"
  sign_kernels
}

cmd_sign_kernels() {
  is_setup || exit 0
  need_root sign-kernels
  sign_kernels
}

cmd_check() {  # boot service: once the key is confirmed, the code is not needed any more
  is_setup || exit 0
  if [ "$(key_state)" = enrolled ]; then
    rm -f "${CODE_FILE}"
    systemctl disable floppaos-secureboot-check.service >/dev/null 2>&1 || true
  fi
}

cmd_remind() {  # autostart at login, as the user: until the key is confirmed, say what to do
  [ -r "${CODE_FILE}" ] || exit 0
  [ -n "${XDG_RUNTIME_DIR:-}" ] && [ -e "${XDG_RUNTIME_DIR}/floppaos-secureboot-reminded" ] && exit 0
  command -v kdialog >/dev/null || exit 0
  [ -n "${XDG_RUNTIME_DIR:-}" ] && : > "${XDG_RUNTIME_DIR}/floppaos-secureboot-reminded"
  local code state
  code="$(tr -cd '0-9' < "${CODE_FILE}")"
  state="$(key_state)"
  [ "${state}" = pending ] && [ "${#code}" -ne 8 ] && state=missing
  case "${state}" in
    enrolled) exit 0 ;;
    pending)
      kdialog --title "Secure Boot: one step left" --msgbox "When the PC starts the next time, a blue screen appears (\"Press any key to perform MOK management\").

1. Press any key within 10 seconds.
2. Choose \"Enroll MOK\", then \"Continue\", then \"Yes\".
3. At \"Password:\" type the code ${code:0:4} ${code:4:4} (only the 8 digits) and press Enter.
4. Choose \"Reboot\".

Then FloppaOS also starts with Secure Boot on." ;;
    *)
      if kdialog --title "Secure Boot: key not confirmed" --yesno "The FloppaOS key was not confirmed on the blue screen, so FloppaOS can't start with Secure Boot on yet.

Make a new code now? (Asks for your password.)"; then
        if pkexec /usr/bin/floppaos-secureboot enroll >/dev/null 2>&1; then
          rm -f "${XDG_RUNTIME_DIR:-/nonexistent}/floppaos-secureboot-reminded"
          exec "$0" remind
        else
          kdialog --title "Secure Boot" --sorry "That did not work. In Konsole: sudo floppaos-secureboot enroll"
        fi
      fi ;;
  esac
}

cmd_status() {
  local esp sb
  sb="$(mokutil --sb-state 2>/dev/null | head -n1 || true)"
  say "Firmware: ${sb:-unknown (not started in UEFI mode?)}"
  if ! is_setup; then say "FloppaOS Secure Boot support: not set up (sudo floppaos-secureboot setup)"; return 0; fi
  say "FloppaOS Secure Boot support: set up (${CRT})"
  say "Key: $(key_state)"
  esp="$(esp_path)"
  signed "${esp}/EFI/${LABEL}/grubx64.efi" && say "GRUB: signed" || say "GRUB: NOT signed (sudo floppaos-secureboot update)"
  [ -f "${esp}/EFI/${LABEL}/shimx64.efi" ] && say "shim: in place" || say "shim: missing (sudo floppaos-secureboot update)"
  local k
  for k in /boot/vmlinuz-*; do
    [ -f "${k}" ] || continue
    signed "${k}" && say "Kernel ${k}: signed" || say "Kernel ${k}: NOT signed (sudo floppaos-secureboot sign-kernels)"
  done
  [ -r "${CODE_FILE}" ] && say "Code for the blue screen: $(cat "${CODE_FILE}")" || true
}

cmd_off() {
  need_root off
  local esp d b
  esp="$(esp_path)"
  d="${esp}/EFI/${LABEL}"
  b="${esp}/EFI/BOOT"
  grub-install --target=x86_64-efi --efi-directory="${esp}" --bootloader-id="${LABEL}" --no-nvram >/dev/null 2>&1 \
    || die "grub-install failed"
  rm -f "${d}/shimx64.efi" "${d}/mmx64.efi"
  if ours "${b}/BOOTX64.EFI"; then
    install -m 644 "${d}/grubx64.efi" "${b}/BOOTX64.EFI"
    rm -f "${b}/grubx64.efi" "${b}/mmx64.efi"
  fi
  boot_entry "${esp}" grubx64.efi
  systemctl disable floppaos-secureboot-check.service >/dev/null 2>&1 || true
  rm -rf "${STATE}"
  say "Back to plain GRUB. Keep Secure Boot off in the firmware settings."
}

case "${1:-}" in
  setup) shift; cmd_setup "$@" ;;
  enroll) shift; need_root enroll; is_setup || die "not set up yet (sudo floppaos-secureboot setup)"
          if [ "${1:-}" = --code-file ]; then enroll "${2:-}"; else enroll; fi ;;
  update) cmd_update ;;
  sign-kernels) cmd_sign_kernels ;;
  check) cmd_check ;;
  remind) cmd_remind ;;
  status) cmd_status ;;
  off) cmd_off ;;
  *) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 2 ;;
esac
