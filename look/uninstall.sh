#!/usr/bin/env bash
# FloppaOS look: undo. Puts the desktop back to KDE's default dark look and default panel,
# and removes everything look/install.sh added for the current user.
set -euo pipefail
S="${HOME}/.local/share"

# KDE default look, including the default panel layout, icons, cursors and window decoration.
plasma-apply-lookandfeel -a org.kde.breezedark.desktop --resetLayout || true

# Our shortcut additions (back to KDE's defaults).
for svc in org.kde.plasma-systemmonitor.desktop systemsettings.desktop org.kde.krunner.desktop org.kde.konsole.desktop; do
  kwriteconfig6 --file kglobalshortcutsrc --group services --group "${svc}" --key _launch --delete
done
# Four numbers per shortcut, unused ones 0 (see apply-extras.sh: with one number KWin crashed).
gdbus call --session --dest org.kde.kglobalaccel --object-path /kglobalaccel \
  --method org.kde.KGlobalAccel.setForeignShortcutKeys "['kwin', 'Overview', 'KWin', 'Toggle Overview']" \
  "[([268435543, 0, 0, 0],)]" >/dev/null 2>&1 \
  || kwriteconfig6 --file kglobalshortcutsrc --group kwin --key Overview "Meta+W,Meta+W,Toggle Overview"
kwriteconfig6 --file kwinrc --group TabBox --key LayoutName --delete
kwriteconfig6 --file kscreenlockerrc --group Greeter --key WallpaperPlugin --delete
kwriteconfig6 --file kscreenlockerrc --group Greeter --group Wallpaper --group org.kde.color --group General --key Color --delete
kwriteconfig6 --file ksplashrc --group KSplash --key Engine --delete
kwriteconfig6 --file ksplashrc --group KSplash --key Theme --delete
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSize --delete
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key BorderSizeAuto --delete
kwriteconfig6 --file kwinrc --group org.kde.kdecoration2 --key ButtonsOnLeft --delete

kpackagetool6 --type=Plasma/Applet --remove menu.11.enhanced >/dev/null 2>&1 || true
kpackagetool6 --type=Plasma/Applet --remove org.floppaos.startmenu >/dev/null 2>&1 || true

# Theme parts and our own files.
rm -rf "${S}/icons/NeoWin" "${S}/icons/Fluent" "${S}/icons/Fluent-dark" "${S}/icons/WinSur-dark-cursors" "${S}/icons/WinSur-white-cursors"
rm -rf "${S}/aurorae/themes"/Willow{Dark,Light}Blur "${S}/aurorae/themes"/Willow{Dark,Light}BlurAlt
rm -rf "${S}/plasma/desktoptheme/Utterly-Round"
rm -f  "${S}/color-schemes/FloppaOSBlack.colors" "${S}/icons/hicolor/scalable/apps/floppaos.svg"
rm -rf "${S}/plasma/look-and-feel/org.floppaos.desktop"
rm -rf "${S}/floppaos" "${HOME}/.cache/floppaos"

# Leftovers of NeoWin's own installer, which was used during early development.
rm -f  "${S}/color-schemes"/NeoWin{Dark,Light,Twilight}.colors
rm -rf "${S}/plasma/look-and-feel"/neowin-{dark,light,twilight} "${S}/sounds/neowin"
rm -rf "${HOME}/.config/Kvantum"/NeoWinKvantum{Dark,Light}
systemctl --user disable --now neowin-kvantum-sync.service >/dev/null 2>&1 || true
rm -f "${HOME}/.config/systemd/user/neowin-kvantum-sync.service" "${HOME}/.local/bin/neowin-kvantum-sync"
systemctl --user daemon-reload >/dev/null 2>&1 || true

kbuildsycoca6 --noincremental >/dev/null 2>&1 || true
qdbus6 org.kde.KWin /KWin org.kde.KWin.reconfigure >/dev/null 2>&1 || true
echo "FloppaOS look removed. Log out and back in to finish."
