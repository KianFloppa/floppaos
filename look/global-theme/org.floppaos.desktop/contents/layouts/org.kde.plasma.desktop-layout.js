// FloppaOS desktop layout (Plasma 6). Run by Plasma when the FloppaOS global theme sets up a desktop:
// for a new user, or with `plasma-apply-lookandfeel -a org.floppaos.desktop --resetLayout`.
//
// One Windows 11-style taskbar: bottom, start button far left, pinned and running apps
// next to it, tray and a small time-over-date clock on the right. Pure-black desktop (OLED).

var old = panels();
for (var i = 0; i < old.length; i++) { old[i].remove(); }

var p = new Panel;
p.location = "bottom";
p.height = 54;
try { p.lengthMode = "fill"; } catch (e) {}
try { p.floating = false; } catch (e) {}

// Start menu: "FloppaOS Start" (look/start-menu, Windows 11 style) when it is installed, otherwise KDE's own
// launcher (Kickoff). Both get the FloppaOS mark. See docs/research.md section 10.
var menuWidget = "org.kde.plasma.kickoff";
try {
    if (knownWidgetTypes.indexOf("org.floppaos.startmenu") >= 0) { menuWidget = "org.floppaos.startmenu"; }
} catch (e) {}
var start = p.addWidget(menuWidget);
start.currentConfigGroup = ["General"];
start.writeConfig("icon", "floppaos");

var tasks = p.addWidget("org.kde.plasma.icontasks");
tasks.currentConfigGroup = ["General"];
tasks.writeConfig("iconSpacing", 1);
var pinned = [
    "applications:org.kde.dolphin.desktop",
    "applications:firefox.desktop",
    "applications:org.kde.konsole.desktop",
    "applications:systemsettings.desktop"
];
try {
    if (applicationExists("floppa-launcher.desktop")) { pinned.push("applications:floppa-launcher.desktop"); }
    // Only on the live USB system: the installer removes itself from the systems it installs.
    if (applicationExists("floppaos-install.desktop")) { pinned.push("applications:floppaos-install.desktop"); }
} catch (e) {}
tasks.writeConfig("launchers", pinned);

p.addWidget("org.kde.plasma.panelspacer");
p.addWidget("org.kde.plasma.systemtray");

var clock = p.addWidget("org.kde.plasma.digitalclock");
clock.currentConfigGroup = ["Appearance"];
clock.writeConfig("showDate", true);
clock.writeConfig("autoFontAndSize", false);
clock.writeConfig("fontSize", 11);
clock.writeConfig("fontFamily", "Noto Sans");
clock.writeConfig("fontWeight", 400);
clock.writeConfig("fontStyleName", "Regular");
clock.writeConfig("dateFormat", "custom");
clock.writeConfig("customDateFormat", "d MMM yyyy");
clock.writeConfig("dateDisplayFormat", "BelowTime");
clock.writeConfig("showSeconds", "Always");

// Pure-black desktop background.
var ds = desktops();
for (var j = 0; j < ds.length; j++) {
    ds[j].wallpaperPlugin = "org.kde.color";
    ds[j].currentConfigGroup = ["Wallpaper", "org.kde.color", "General"];
    ds[j].writeConfig("Color", "0,0,0");
    try { ds[j].reloadConfig(); } catch (e) {}
}
