#!/bin/sh
# Starts the FloppaOS installer (Calamares) from the live USB system. Installed as /usr/bin/floppaos-install.
if [ ! -d /run/archiso ]; then
  msg="The FloppaOS installer only runs from the FloppaOS USB stick."
  kdialog --error "${msg}" 2>/dev/null || echo "${msg}" >&2
  exit 1
fi

# Keep the live desktop's keyboard layout in step with the installer's keyboard page (see live-keyboard).
/usr/lib/floppaos-installer/live-keyboard &
helper=$!

# While the installer creates and mounts partitions, Plasma's "Disks & Devices" pop-up (the device notifier in
# the system tray) would open by itself for new partitions. Take the device notifier out of the live session's
# tray until the installer closes. (Plasma 6.8 keeps the tray's applets inside the tray, so the scripting API
# cannot change the notifier's own "pop up on new device" setting while it runs; the tray's list of enabled
# items, extraItems, takes effect at once.) An installed FloppaOS keeps the notifier and its pop-up.
tray_items_js() {  # $1 = off | on
  cat <<JS
var n = 0, ps = panels(), id = "org.kde.plasma.devicenotifier";
for (var i = 0; i < ps.length; i++) {
    var trays = ps[i].widgets("org.kde.plasma.systemtray");
    for (var j = 0; j < trays.length; j++) {
        var t = trays[j];
        t.currentConfigGroup = ["General"];
        var items = String(t.readConfig("extraItems") || "").split(",").filter(function (x) { return x !== ""; });
        var has = items.indexOf(id) >= 0;
        if ("$1" === "off" && has) { t.writeConfig("extraItems", items.filter(function (x) { return x !== id; })); n++; }
        if ("$1" === "on" && !has) { items.push(id); t.writeConfig("extraItems", items); n++; }
    }
}
print(n);
JS
}
devices_changed="$(qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(tray_items_js off)" 2>/dev/null || true)"

# Calamares has to run as root. The live user may use sudo without a password (iso/airootfs).
# On the Wayland desktop: give it the full path of the Wayland socket (so it does not depend on the live
# user's runtime folder) and make Qt use Wayland. sudo's clean environment would otherwise make Qt fall back
# to X11 (Xwayland), and then the keyboard page changes only X11 programs, not the live desktop.
case "${WAYLAND_DISPLAY:-}" in
  "") ;;
  /*) QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}" ;;
  *) WAYLAND_DISPLAY="${XDG_RUNTIME_DIR}/${WAYLAND_DISPLAY}"; QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-wayland;xcb}" ;;
esac
export WAYLAND_DISPLAY QT_QPA_PLATFORM
# Draw the slideshow (Qt Quick) without OpenGL. With OpenGL the whole installer window stayed black on a
# machine without working 3D (seen in a test VM, 2026-11-21); the slideshow is only text.
QT_QUICK_BACKEND=software
export QT_QUICK_BACKEND
sudo --preserve-env=WAYLAND_DISPLAY,DISPLAY,XAUTHORITY,QT_QPA_PLATFORM,QT_QUICK_BACKEND,XDG_CURRENT_DESKTOP,LANG,LANGUAGE,LC_ALL calamares "$@"
status=$?

kill "${helper}" 2>/dev/null
# Give the tray its device notifier back if it was taken out above (when the installer closes without a restart).
case "${devices_changed}" in
  ""|0) ;;
  *) qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$(tray_items_js on)" >/dev/null 2>&1 || true ;;
esac
exit "${status}"
