#!/bin/sh
# FloppaOS: apply the full FloppaOS look once per user, at the first login (autostart from floppaos-defaults).
# Needed because a distribution can copy its own panel and settings into new accounts (/etc/skel; CachyOS does).
#
# Kept out of the autostart file's Exec= line on purpose: systemd's autostart converter escaped "$HOME" there,
# so floppaos-defaults 0.2-0.4 wrote the marker to a folder literally called "$HOME" inside the home folder.
marker="${XDG_DATA_HOME:-$HOME/.local/share}/floppaos/firstlogin-done"

# Old marker from 0.2-0.4: count it as done and remove that stray folder (only its empty folders, nothing else).
legacy="$HOME/\$HOME"
if [ -f "$legacy/.local/share/floppaos/firstlogin-done" ]; then
  mkdir -p "${marker%/*}" && touch "$marker"
  rm -f "$legacy/.local/share/floppaos/firstlogin-done"
  rmdir "$legacy/.local/share/floppaos" "$legacy/.local/share" "$legacy/.local" "$legacy" 2>/dev/null
fi

[ -f "$marker" ] && exit 0
mkdir -p "${marker%/*}" && touch "$marker" || exit 0
sleep 3
exec floppaos-look
