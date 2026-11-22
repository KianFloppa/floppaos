# FloppaOS Start (start menu widget)

The start menu of the FloppaOS taskbar: a search box at the top, a grid of pinned apps with an "All apps"
page, recent documents, and your name and the power buttons at the bottom, like the Windows 11 start menu.

- Plasma widget id: `org.floppaos.startmenu` (version in `metadata.json`).
- Licence: GPL-2.0-or-later, like the code it comes from.
- Based on **Menu 11 Enhanced** 1.1.2 by kurojs, https://github.com/kurojs/Menu-11-Enhanced, commit `0a54ba7`
  (2025-12-24), itself based on Eisteed's "Menu 11" and on Eike Hein's Kicker from KDE. The upstream files keep
  their copyright headers. Code review and the two failed tests of the original: `docs/research.md` section 10.

## What FloppaOS changed

1. **The popup.** Upstream opened its own window (`PlasmaCore.Dialog`) and moved it to a position it worked out
   itself. On Plasma 6.8 (Wayland only) that window never appeared. Now the menu is the widget's normal
   popup (`fullRepresentation` in `contents/ui/main.qml`), which Plasma places next to the start button.
   Changed files: `main.qml`, `CompactRepresentation.qml` (the button: click opens and closes, the Windows key
   too, dragging a file onto it opens it), `MenuRepresentation.qml` (no own window, no hand-made positioning).
2. **Settings.** The "Menu position" choice is gone (Plasma decides). Defaults: FloppaOS start icon,
   6 x 3 pinned apps, pinned: browser, Dolphin, System Settings, Konsole, Kate, KCalc, Gwenview, Haruna,
   Okular, Spectacle, System Monitor, Ark (apps that are not installed are left out).
3. **Hidden apps.** Technical tools that come with the system (Qt Assistant, Designer, Linguist and D-Bus
   Viewer, the Qt V4L2 tools, Software Token, lftp, lstopo, Vim, mpv, Avahi browsers, XTerm) are left out of
   "All apps" (`hiddenApplications` in `contents/config/main.xml`). Search still finds them; the widget's
   settings have "Unhide all hidden applications". For this to work at all on Plasma 6, `main.qml` gives KDE's
   launcher code the `configuration` property it looks for (see `docs/research.md` section 10).
4. **Small Windows 11 touches:** headings without icons, "All apps >" and "Show more >" with the arrow after
   the text, the button's tooltip says "Start", and the right-click menu says "Pin to Start",
   "Unpin from Start" and "Pin to taskbar" (`code/tools.js`, `ActionMenu.qml`), and an empty "Recent
   documents" area says "Files you open will show up here".
5. **Name and id**, so it never clashes with the original if someone also installs that one. The
   translations (`translate/*.po`, compiled in `contents/locale/`) were renamed to the new id.

## Install by hand (for testing)

```sh
kpackagetool6 -t Plasma/Applet -i look/start-menu      # or -u to update
```

`look/install.sh` and the `floppaos-look` package install it, and the FloppaOS taskbar layout uses it when it
is there (otherwise KDE's own launcher).
