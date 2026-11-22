#!/usr/bin/env bash
# Test helper for virtual machines: turns an EMPTY disk into a stand-in for a Windows 11 install, so the
# FloppaOS installer's "Install alongside" mode and the boot menu can be tested without a Windows licence or
# a Windows download. It is not Windows and cannot run Windows programs.
#
# Layout like Windows 11 makes on a GPT disk:
#   1. EFI system partition, 100 MiB, FAT32 (label SYSTEM)
#   2. Microsoft reserved partition, 16 MiB
#   3. "C:" NTFS (label Windows): Windows-like folders and 2 GiB of random "user data" (checksum printed, so a
#      test can show that shrinking the partition kept the data)
#   4. Recovery partition, 750 MiB, NTFS, at the end of the disk
# The EFI system partition holds \EFI\Microsoft\Boot\bootmgfw.efi and \EFI\Microsoft\Boot\BCD: os-prober
# (and so GRUB's menu) only reports the Windows Boot Manager when both exist (os-probes/mounted/efi/20microsoft;
# the first test on 2026-11-21 had no BCD and the boot menu did not list Windows). Here bootmgfw.efi is the UEFI
# shell (the live ISO's edk2-shell package), so choosing "Windows Boot Manager" visibly starts something, and
# BCD is an empty placeholder (Windows keeps its boot settings in that file).
#
# Usage (as root on the FloppaOS live system, in a VM): tools/windows-standin.sh /dev/vdX
# Refuses disks that already have a partition table.
set -euo pipefail
disk="${1:?disk, for example /dev/vda}"
[ "$(id -u)" = 0 ] || { echo "Run as root."; exit 1; }
[ -b "${disk}" ] || { echo "Not a disk: ${disk}"; exit 1; }
if [ -n "$(blkid -p -o value -s PTTYPE "${disk}" 2>/dev/null || true)" ] || [ "$(lsblk -nro NAME "${disk}" | wc -l)" != 1 ]; then
  echo "Refusing: ${disk} is not empty (it has a partition table). This tool only prepares blank test disks."
  exit 1
fi
shell=/usr/share/edk2-shell/x64/Shell.efi
[ -s "${shell}" ] || { echo "Missing ${shell} (package edk2-shell)."; exit 1; }
part() { case "${disk}" in *[0-9]) echo "${disk}p$1" ;; *) echo "${disk}$1" ;; esac; }

echo "== Partitions (GPT, like Windows 11)"
sgdisk -n1:1MiB:+100MiB -t1:ef00 -c1:"EFI system partition" \
       -n2:0:+16MiB -t2:0c01 -c2:"Microsoft reserved partition" \
       -n3:0:-750MiB -t3:0700 -c3:"Basic data partition" \
       -n4:0:0 -t4:2700 "${disk}" >/dev/null
partprobe "${disk}" 2>/dev/null || true
udevadm settle
mkfs.fat -F 32 -n SYSTEM "$(part 1)" >/dev/null
mkntfs -Q -L Windows "$(part 3)" >/dev/null
mkntfs -Q -L Recovery "$(part 4)" >/dev/null

m="$(mktemp -d)"
echo "== EFI system partition: stand-in Windows Boot Manager (the UEFI shell)"
mount "$(part 1)" "${m}"
mkdir -p "${m}/EFI/Microsoft/Boot" "${m}/EFI/Boot"
cp "${shell}" "${m}/EFI/Microsoft/Boot/bootmgfw.efi"
cp "${shell}" "${m}/EFI/Boot/bootx64.efi"
: > "${m}/EFI/Microsoft/Boot/BCD"
printf 'Stand-in for a Windows install, made by FloppaOS tools/windows-standin.sh for tests. Not Windows.\r\n' \
  > "${m}/EFI/Microsoft/Boot/README.txt"
umount "${m}"

echo "== C: (NTFS): folders and 2 GiB of user data"
mount -t ntfs3 "$(part 3)" "${m}" 2>/dev/null || mount -t ntfs-3g "$(part 3)" "${m}"
mkdir -p "${m}/Windows/System32" "${m}/Program Files" "${m}/Users/Public" "${m}/Users/Tester/Documents"
printf 'Stand-in for a Windows install (FloppaOS test). Not Windows.\r\n' > "${m}/Windows/README.txt"
dd if=/dev/urandom of="${m}/Users/Tester/Documents/data.bin" bs=4M count=512 status=none
sum="$(sha256sum "${m}/Users/Tester/Documents/data.bin" | cut -d' ' -f1)"
umount "${m}"
rmdir "${m}"

sgdisk -p "${disk}" | tail -n 5
echo "data.bin sha256 ${sum}"
echo "Done. Start the FloppaOS installer and choose \"Install alongside\" on this disk."
