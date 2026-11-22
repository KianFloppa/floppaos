#!/usr/bin/env bash
# FloppaOS look: the settings a Plasma global theme cannot carry:
# Windows-like keyboard shortcuts, non-Microsoft sounds, night light off, window borders, Alt+Tab style.
# Only touches the current user's KDE settings.
set -euo pipefail

TAB=$'\t'
ks() { kwriteconfig6 --file kglobalshortcutsrc --group services --group "$1" --key _launch "$2"; }

# Windows-like shortcuts, added next to KDE's own (which keep working). They take effect at the next login, because
# the shortcut service only reads this file when it starts; the FloppaOS ISO therefore also puts the same entries
# into /etc/skel (iso/airootfs/etc/skel/.config/kglobalshortcutsrc) so new accounts have them from the first login.
# Already the same on KDE by default: Win+E files, Win+D show desktop, Win+L lock, Win+V clipboard.
ks org.kde.plasma-systemmonitor.desktop "Meta+Esc${TAB}Ctrl+Shift+Esc"   # Task Manager
ks systemsettings.desktop               "Meta+I"                          # Settings
ks org.kde.krunner.desktop              "Alt+Space${TAB}Alt+F2${TAB}Search${TAB}Meta+R"   # Run
ks org.kde.konsole.desktop              "Ctrl+Alt+T"
# Win+Tab = Task View: KWin's Overview (Meta+W stays). Meta+Tab is free on Plasma 6.8 (activity switching has no
# shortcut there any more). Set through the running shortcut service, which takes effect at once and keeps it: it
# rewrites KWin's lines in kglobalshortcutsrc from memory, so a plain file edit was lost (seen in the VM, research
# section 14). Qt key codes: Meta 0x10000000 + W 0x57 = 268435543, Meta + Tab 0x01000001 = 285212673.
if ! gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
     --method org.kde.KGlobalAccel.setForeignShortcutKeys "['kwin', 'Overview', 'KWin', 'Toggle Overview']" \
     "[([268435543],), ([285212673],)]" >/dev/null 2>&1; then
  # No session bus (or no gdbus): write the file; it is read when the shortcut service starts next time.
  kwriteconfig6 --file kglobalshortcutsrc --group kwin --key Overview "Meta+W${TAB}Meta+Tab,Meta+W,Toggle Overview"
fi

# Sounds: use KDE's own sound theme. The Windows sound files that the NeoWin theme installs
# belong to Microsoft and must not be part of FloppaOS, so remove them from this user.
kwriteconfig6 --file kdeglobals --group Sounds --key Theme ocean
rm -rf "${HOME}/.local/share/sounds/neowin"

# No night light: it tints the whole screen orange in the evening. --notify is needed,
# otherwise the running window manager keeps the old setting.
kwriteconfig6 --notify --file kwinrc --group NightColor --key Active --type bool false

# Windows without side borders; Alt+Tab as a grid of window thumbnails, like Windows.
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize "NoSides"
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto "false"
kwriteconfig6 --file kwinrc --group TabBox --key LayoutName "thumbnail_grid"

# Pure black lock screen and no splash screen at login (OLED). The login screen itself is a system
# setting; the floppaos-defaults package makes it black.
kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin "org.kde.color"
kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.color --group General --key Color "0,0,0"
kwriteconfig6 --file ksplashrc --group KSplash --key Engine "none"
kwriteconfig6 --file ksplashrc --group KSplash --key Theme "None"

[ -x /usr/lib/plasma-changeicons ] && /usr/lib/plasma-changeicons Fluent-dark >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true

echo "FloppaOS shortcuts, sounds, window and lock screen settings applied (shortcuts work after the next login)."
