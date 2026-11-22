# Changelog

FloppaOS has one version number for the Setup Pack (`install.sh`) and the ISO, in the file `VERSION`.
`-dev` means "not released yet". Each package in `packages/` also has its own version (`pkgver`), and every
ISO file carries its build date (`floppaos-YYYY.MM.DD-x86_64.iso`); the list of ISO builds is in
`iso/README.md`.

## 0.1.0-preview (2026-11-22)

The first public image: `floppaos-0.1.0-preview-x86_64.iso`, SHA-256 `5c9f73e2d8cc2b2df71dd8c470cb047fef37c6a86b5079115e7112d1c1738e6b`, from
[floppaos.pages.dev](https://floppaos.pages.dev/#download). Everything below was built and tested in virtual
machines (November 2026). Nothing has been installed on real hardware yet (Phase 6); the full 0.1.0 comes
after that. No warranty: a free hobby project by one person, install at your own risk, back up your files first.

### Release
- Release builds (`iso` with "release"), downloads from floppaos.pages.dev/download/ (R2, `functions/download/`),
  the source code of every copyleft package in the release `sources-0.1.0-preview` and the written offer
  (`docs/source-code.md`), published by the `release` workflow.

### Desktop look
- FloppaOS logo: an orange caracal head (the Floppa cat), on the start button, in the installer and on the
  boot screen.
- Windows 11 style taskbar: start button far left, pinned and open apps next to it,
  tray and a small clock (time with seconds over the date) on the right; solid black.
- Pure-black (OLED) colours, background, lock screen and login screen; no night-light tint; no splash screen.
- **FloppaOS Start**, a Windows 11 style start menu: search, pinned apps, "All apps", recent documents, user
  and power buttons. Opens with the start button and the Windows key.
- Windows shortcuts: Win (menu), Win+E, Win+D, Win+L, Win+V, Win+., Win+I, Win+R, Win+Tab,
  Ctrl+Shift+Esc (System Monitor), Print (Spectacle).
- Window decoration, icons, cursors and Plasma style from open-source projects (see `CREDITS.md`); icons of
  Microsoft products and other systems' logos removed.
- Icons: Fluent (its own drawings in a Windows 11-like style), in a dark variant for the black desktop.
- Each theme part comes straight from its own project (Willow, WinSur, Utterly-Round, Fluent) at a pinned,
  reviewed commit; the FloppaOS Black colours are KDE's Breeze Dark with black backgrounds
  (`floppaos-theme-parts` 0.5, `floppaos-look` 0.11).
- `install.sh` / `uninstall.sh` (Setup Pack, no admin rights), or the `floppaos-look` package.
- Setup Pack tested on the CachyOS live system (2026-11-22, Plasma 6.7.4). Fixed there: setting Win+Tab no
  longer crashes the window manager (KDE Frameworks up to 6.29 read every shortcut as exactly four numbers;
  `floppaos-look` 0.12); `install.sh` offers kdialog when it is missing, as on the CachyOS live system (one
  `pacman -Syu`); `look/login-screen.sh` only changes the login screen that is installed.

### Secure Boot
- New installer page **Secure Boot**: one tick box, and FloppaOS starts with Secure Boot on, next to Windows. A
  Microsoft-signed shim (Fedora's) starts GRUB; GRUB and the kernels are signed with a key made on the PC, which
  is confirmed once on a blue screen at the next start with an 8-digit code. Kernel and GRUB updates are signed
  automatically. A reminder after login shows the code until it is done. `floppaos-secureboot` sets it up on an
  installed FloppaOS too (`secureboot/README.md`). The USB stick itself still needs Secure Boot off.

### Floppa Setup
- Opens at first login until the Floppa Launcher is installed: checks the Floppa servers, the launcher, each
  game, that F2 is free for FloppaNet, and the graphics driver.
- Installs the launcher (SHA256-checked), pins it to the taskbar and opens it; optional "Install Wine".
- After the FloppaOS installer: does at the new user's first login what was ticked on the installer's
  "Floppa games" page, without asking again (offline it tries again at the next login), with a short
  "Floppa Setup" notification.
- Without a working kdialog (missing, or installed without updating the system) it no longer stays silent:
  a notification says how to get it (`floppaos-setup` 0.6).

### Website
- floppaos.pages.dev: the no-warranty notice in the download section and in "Good to know", a legal imprint
  link and its own privacy policy page (`/datenschutz/`, German with an English summary). `/etc/os-release`
  points to the website, the bug tracker and the privacy policy.

### FloppaOS PC check
- New: one text file with what works on this PC: graphics driver and Vulkan, screens (refresh rate, VRR, HDR),
  sound, Wi-Fi, Bluetooth, game controllers, Secure Boot, kernel errors. Read-only; no serial numbers or network
  addresses. On the live desktop of the ISO (for trying FloppaOS from the USB stick), in the start menu, and in
  the Setup Pack (`floppaos-setup` 0.7).

### FloppaOS ISO (Arch Linux based)
- Live desktop with "Install FloppaOS"; Calamares 3.4.3 installer with FloppaOS branding and dark pages.
- Installer page "Before you start", right after the welcome page: no warranty, installing is at your own
  risk, back up your files first (`floppaos-installer` 0.13). The installer calls itself "FloppaOS 0.1.0 preview".
- Installer page "Floppa games": tick boxes for the Floppa Launcher, pinning it to the taskbar and Wine
  (Floppa Setup does them at the first login; nothing is downloaded during the installation).
- The "Disks & Devices" pop-up no longer opens by itself while the installer works on the disk.
- The installer builds the boot image once instead of twice (faster install).
- Plasma Login Manager; installed systems call themselves FloppaOS (`/etc/os-release`, `/etc/lsb-release`,
  boot menus).
- Boot like Windows: the computer maker's logo with a spinner and the FloppaOS mark below; no boot menu when
  FloppaOS is the only system (press Esc during start to see it). Next to Windows: a black "Choose an
  operating system" menu with the FloppaOS logo.
- Everyday KDE apps (Dolphin, Firefox, Konsole, Kate, KCalc, Gwenview, Okular, Haruna, Spectacle, Ark,
  System Monitor, Info Center), Bluetooth, power profiles.
- Gaming set: MangoHud (64/32-bit), gamescope, GameMode (users join the `gamemode` group), Vulkan tools,
  zram swap.
- Built by GitHub Actions; downloads from a private Cloudflare R2 bucket (newest 3 kept).
- Updates for FloppaOS's own packages, ready but switched off until the signing key exists: the packages
  workflow signs them and publishes a pacman repository on the release `packages-x86_64`; the ISO then adds
  that repository and the `floppaos-keyring` package (`keyring/README.md`).

### Known issues
- Do not start games in the VirtualBox VM: it crashed VirtualBox (2026-11-21). Games are tested on real
  hardware later.
- "Next to Windows" was tested with a stand-in Windows disk in a VM, not with real Windows yet.
- 0.1.0-preview: in a very slow VM (no hardware acceleration) the installer can end with "Could not unmount the
  root of the target system" although everything was written; the system starts normally. Fixed after the
  preview: the installer step "Writing everything to the disk" (`floppaflush`, `floppaos-installer` 0.14).
