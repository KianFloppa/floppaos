# Credits

FloppaOS's look is built on other people's open-source work. Thank you.

| Part | Project | Author | Licence | Used how |
|---|---|---|---|---|
| Window decoration | [Willow](https://github.com/doncsugar/willow-theme): "Willow Dark Blur" (+ Alt) | doncsugar | GPL-3.0 | Since 2026-11-22 straight from Willow's `plasma-6` branch, pinned commit 59b4e62 (2024-04-03). `look/parts-build.sh` puts the theme together the way Willow's `genThemes.sh` does (button pictures, blur frame, settings file); Willow's scripts are not run |
| Cursors | [WinSur dark cursors](https://github.com/yeyushengfan258/WinSur-dark-cursors), based on capitaine-cursors | yeyushengfan258 | GPL-3.0 | Since 2026-11-22 straight from pinned commit 022b4aa (2020-09-18), its built `dist/` folder copied unchanged |
| Plasma style | [Utterly-Round](https://github.com/HimDek/Utterly-Round-Plasma-Style) 2.1, see-through version | Himprakash Deka (HimDek) | GPL-2.0-or-later | Since 2026-11-22 straight from pinned commit 7e011c1 (2024-08-08), `desktoptheme/translucent` copied unchanged; FloppaOS adds a `colors` file (FloppaOS Black) so the taskbar and its pop-ups stay pure black |
| Colour scheme `look/color-schemes/FloppaOSBlack.colors` | KDE's [Breeze](https://invent.kde.org/plasma/breeze) Dark colour scheme | Andrew Lake, Marco Martin, Nate Graham, Noah Davis, Neal Gompa, David Redondo, Thomas Duckworth (KDE); changed by FloppaOS | LGPL-2.0-or-later | Since 2026-11-22: Breeze Dark (commit b0832e7) with pure-black backgrounds, pure-white text and black title bars |
| Icons | [Fluent icon theme](https://github.com/vinceliuice/Fluent-icon-theme) | vinceliuice | GPL-3.0 | Since 2026-11-22 (decision 24). Files of pinned commit c8a244f assembled into `Fluent` and `Fluent-dark` by `look/fluent-build.sh` (Fluent's install script is not run); icons of Microsoft products and the Windows/other systems' logos removed by `tools/icon-audit.py`, `start-here` and `distributor-logo` replaced with the FloppaOS mark |
| Global theme layout | KDE Plasma's desktop scripting; the idea of a look-and-feel package follows KDE Breeze | KDE | LGPL/GPL | `look/global-theme/` is our own file set |
| Start menu (`look/start-menu`, "FloppaOS Start") | [Menu 11 Enhanced](https://github.com/kurojs/Menu-11-Enhanced) 1.1.2, based on Eisteed's Menu 11 and KDE's Kicker | kurojs, Eisteed, Eike Hein (KDE), changed by FloppaOS | GPL-2.0-or-later | Copied from commit 0a54ba7; the menu now opens as Plasma's own popup (works on Plasma 6.8), own id and defaults; changes listed in `look/start-menu/README.md` |

## Installer

| Part | Project | Author | Licence | Used how |
|---|---|---|---|---|
| Graphical installer | [Calamares](https://codeberg.org/Calamares/calamares) 3.4.3 | The Calamares team | GPL-3.0-or-later | Built unchanged from the release tarball (`packages/calamares`); settings and branding in `installer/` are our own |
| Secure Boot loader | [shim](https://github.com/rhboot/shim) 16.1, Fedora's build 16.1-7 (`shimx64.efi`, MokManager `mmx64.efi`), signed by Microsoft | The shim authors; built and submitted for signing by the Fedora Project | BSD-2-Clause | Files taken unchanged from Fedora's `shim-x64` package (`packages/floppaos-shim`, checksum-pinned) |
| Install slideshow | `installer/calamares/branding/floppaos/show.qml`, structure from Calamares' sample slideshow | Teo Mrnjavac, Adriaan de Groot (Calamares), changed by FloppaOS | GPL-3.0-or-later | Text, colours and timing are ours |
| Live system base | Arch Linux's `releng` archiso profile | Arch Linux | GPL-3.0-or-later | Copied at build time by `iso/build.sh`; boot menu texts changed to FloppaOS |
| Boot screen spinner and settings | [Plymouth](https://gitlab.freedesktop.org/plymouth/plymouth)'s `spinner` pictures and `bgrt` theme (Arch package) | The Plymouth authors | GPL-2.0-or-later | Copied into FloppaOS's own theme by `floppaos-defaults` (ISO only); the Arch-logo watermark is replaced by the FloppaOS mark |
| Boot menu fonts | [Noto Sans](https://notofonts.github.io/) (Arch package `noto-fonts`) | Google and the Noto project | SIL Open Font License 1.1 | Converted to GRUB's font format with `grub-mkfont` when `floppaos-defaults` is built (`packages/floppaos-defaults/grub-theme/`) |

## No longer used

| Part | Project | Author | Until | Why |
|---|---|---|---|---|
| Window decoration, cursors, Plasma style, colour scheme | [NeoWin](https://github.com/TuxLux40/NeoWin) (a collection of the parts above) | TuxLux40 | 2026-11-22 | FloppaOS now takes each part from its own project; NeoWin also carries Windows icons and sounds |
| Icons | Windows-Eleven icon set (basis of NeoWin's icons) | zayronXIO | 2026-11-21 | It copies Microsoft's own drawings (research §15) |

Not affiliated with Microsoft, CachyOS or Arch Linux.
