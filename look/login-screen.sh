#!/usr/bin/env bash
# FloppaOS Setup Pack, optional extra: the login screen in FloppaOS's black. It changes system files, so it needs
# admin rights and is not part of install.sh.
#
#   sudo ./look/login-screen.sh          black login screen
#   sudo ./look/login-screen.sh --undo   back to the system's own login screen
#
# Covers KDE's Plasma Login Manager (CachyOS's login screen since March 2026) and SDDM, with the same settings the
# FloppaOS ISO uses (packages/floppaos-defaults). Plasma Login Manager always dims its wallpaper behind the login
# form, so black shows as a very dark grey (18,18,18): the darkest it can show (research §26).
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "Needs admin rights: sudo $0 ${*}"; exit 1; }

PLM=/etc/plasmalogin.conf.d/10-floppaos.conf
SDDM=/etc/sddm.conf.d/floppaos.conf
SDDM_THEME=/usr/share/sddm/themes/breeze/theme.conf.user
MARK="# FloppaOS Setup Pack (look/login-screen.sh)"

if [ "${1:-}" = --undo ]; then
  for f in "${PLM}" "${SDDM}" "${SDDM_THEME}"; do
    [ -f "${f}" ] && head -n1 "${f}" | grep -qxF "${MARK}" && rm -f "${f}"
  done
  echo "Login screen back to the system's own (shown at the next login)."
  exit 0
fi

# A file the ISO's package or the user made stays as it is.
write() {  # write <file> < content
  # An empty file counts as ours (seen on a CachyOS install 2026-11-22: an empty 10-floppaos.conf was left
  # alone, so the login screen stayed CachyOS's own).
  if [ -s "$1" ] && ! head -n1 "$1" | grep -qxF "${MARK}"; then
    echo "Left $1 alone (not made by the Setup Pack)."
    cat > /dev/null
    return 0
  fi
  install -d "$(dirname "$1")"
  { echo "${MARK}"; cat; } > "$1"
  chmod 644 "$1"
}

# Only the login screens that are installed. The Breeze SDDM theme folder alone says nothing: Plasma itself
# brings it, also on systems without SDDM (CachyOS 2026, seen in the VM 2026-11-22).
done_any=0

# Plasma Login Manager: plain black wallpaper. Its own settings page writes /etc/plasmalogin.conf, which wins.
if command -v plasmalogin >/dev/null 2>&1; then
  write "${PLM}" <<'CFG'
[Greeter]
WallpaperPluginId=org.kde.color

[Greeter][Wallpaper][org.kde.color][General]
Color=0,0,0
CFG
  done_any=1
fi

# SDDM (older installs): KDE's Breeze login theme on black.
if command -v sddm >/dev/null 2>&1 && [ -d /usr/share/sddm/themes/breeze ]; then
  write "${SDDM}" <<'CFG'
[Theme]
Current=breeze
CFG
  write "${SDDM_THEME}" <<'CFG'
[General]
type=color
color=#000000
background=
CFG
  done_any=1
fi

if [ "${done_any}" -eq 0 ]; then
  echo "No KDE login screen found (Plasma Login Manager or SDDM): nothing changed."
  exit 0
fi
echo "Black login screen set (shown at the next login). Undo: sudo $0 --undo"
