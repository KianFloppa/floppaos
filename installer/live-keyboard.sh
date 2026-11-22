#!/usr/bin/env bash
# FloppaOS installer helper: keeps the live Plasma desktop's keyboard layout in step with the layout picked
# on the installer's keyboard page. Started (as the live user) by floppaos-install, stopped when it exits.
#
# Why: on Wayland, Calamares sets the layout through systemd-localed, but Plasma's KWin does not follow
# localed. Without this, a German user would type the new password with the US layout (y and z swapped)
# and could not log in afterwards. This applies the layout the way KDE's own keyboard settings do: KWin
# (Plasma 6.8) watches kxkbrc with KConfigWatcher, so every change is written with --notify. KConfig only
# notifies about values that really change. Tested in the live system 2026-11-21: choosing German on the
# installer's keyboard page switched KWin to German within seconds (research §14).
set -uo pipefail

# Layout|variant|model|options from systemd-localed, with one D-Bus call (checked every second, so it must be
# cheap: the first version started eight programs per second, which slowed the emulated test VM).
state() {
  local lines=() v s=""
  mapfile -t lines < <(busctl get-property org.freedesktop.locale1 /org/freedesktop/locale1 \
    org.freedesktop.locale1 X11Layout X11Variant X11Model X11Options 2>/dev/null)
  [ "${#lines[@]}" -eq 4 ] || return 1
  for v in "${lines[@]}"; do v="${v#s \"}"; s+="${v%\"}|"; done   # busctl prints: s "de"
  printf '%s' "${s%|}"
}

last="$(state)"   # leave whatever the live session uses now alone; only follow changes
while sleep 1; do
  now="$(state)" || continue
  [ "${now}" = "${last}" ] && continue
  last="${now}"
  IFS='|' read -r layout variant model options <<<"${now}"
  [ -n "${layout}" ] || continue
  kwriteconfig6 --notify --file kxkbrc --group Layout --key Use true
  kwriteconfig6 --notify --file kxkbrc --group Layout --key LayoutList "${layout}"
  kwriteconfig6 --notify --file kxkbrc --group Layout --key VariantList "${variant}"
  [ -n "${model}" ] && kwriteconfig6 --notify --file kxkbrc --group Layout --key Model "${model}"
  if [ -n "${options}" ]; then
    kwriteconfig6 --notify --file kxkbrc --group Layout --key Options "${options}"
    kwriteconfig6 --notify --file kxkbrc --group Layout --key ResetOldOptions true
  fi
  # Older Plasma versions listened for this signal instead (harmless on 6.8).
  dbus-send --session --type=signal /Layouts org.kde.keyboard.reloadConfig
done
