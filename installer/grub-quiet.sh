#!/bin/sh
# FloppaOS installer, last step before the installer removes itself (runs inside the new system):
#  - FloppaOS is the only system: boot like Windows, no boot menu on screen. GRUB waits one second without
#    showing anything; pressing Esc in that second shows the menu.
#  - The installer found another system (Windows or another Linux): the menu is shown at every start, in
#    FloppaOS's look ("Choose an operating system", black, the caracal head; theme from floppaos-defaults).
#   FLOPPAOS_ROOT=<folder>  work on a system in that folder instead of / (tools/test-installer-cleanup.sh)
R="${FLOPPAOS_ROOT:-}"
cfg="${R}/boot/grub/grub.cfg"
def="${R}/etc/default/grub"
log() { echo "floppaos-grub: $*"; }
if [ ! -f "${cfg}" ] || [ ! -f "${def}" ]; then
  log "no GRUB boot menu found, nothing to do"; exit 0
fi
# Entries that os-prober adds for other systems are named "... (on /dev/...)".
theme=/usr/share/grub/themes/floppaos/theme.txt
if grep -q "^menuentry '.*(on /dev/" "${cfg}"; then
  if [ -f "${R}${theme}" ]; then
    sed -i -e 's/^#\{0,1\}GRUB_TERMINAL_OUTPUT=.*/GRUB_TERMINAL_OUTPUT=gfxterm/' -e '/^#\{0,1\}GRUB_THEME=/d' "${def}"
    grep -q '^GRUB_TERMINAL_OUTPUT=' "${def}" || echo 'GRUB_TERMINAL_OUTPUT=gfxterm' >> "${def}"
    echo "GRUB_THEME=\"${theme}\"" >> "${def}"
    if [ -z "${R}" ]; then
      grub-mkconfig -o "${cfg}" >/dev/null 2>&1 || { log "grub-mkconfig failed, the boot menu keeps the plain look"; exit 0; }
    fi
    sed -i "/^[[:space:]]*echo[[:space:]]*'Loading /d" "${cfg}"
    log "another system is installed: boot menu shown in FloppaOS's look"
  else
    log "another system is installed, the boot menu stays visible"
  fi
  exit 0
fi
sed -i -e 's/^#\{0,1\}GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' -e '/^#\{0,1\}GRUB_TIMEOUT_STYLE=/d' "${def}"
grep -q '^GRUB_TIMEOUT=' "${def}" || echo 'GRUB_TIMEOUT=1' >> "${def}"
echo 'GRUB_TIMEOUT_STYLE=hidden' >> "${def}"
if [ -z "${R}" ]; then
  grub-mkconfig -o "${cfg}" >/dev/null 2>&1 || { log "grub-mkconfig failed, the boot menu stays visible"; exit 0; }
fi
# No "Loading Linux ..." / "Loading initial ramdisk ..." text over the computer maker's logo either. Only in
# this file: running grub-mkconfig again later brings the two lines back, which does no harm.
sed -i "/^[[:space:]]*echo[[:space:]]*'Loading /d" "${cfg}"
log "only FloppaOS is installed: boot menu hidden (Esc during start shows it)"
