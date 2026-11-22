# FloppaOS installer

The graphical installer of the FloppaOS ISO: **Calamares 3.4.3** (built in `packages/calamares`) with FloppaOS
settings and branding (this folder, packaged as `packages/floppaos-installer`). On the live system it is
"Install FloppaOS" on the desktop and in the start menu.

## How it installs

1. **Pages:** welcome (checks: 20 GiB disk, 2 GiB RAM, power), **Before you start**, language and time zone,
   keyboard, disk (erase disk, install alongside another system, or manual), user account, **Floppa games**,
   **Secure Boot**, summary. Nothing touches the disk before the user confirms on the summary page.

   The last step before the unmount, "Writing everything to the disk" (`calamares-modules/floppaflush`), freezes
   and thaws every real file system of the new system (`fsfreeze`), which writes ext4's journal out completely.
   Calamares gives the final unmount only 10 seconds; in a slow VM, unmounting right after the copy took longer
   and the installer ended with "Could not unmount the root of the target system" although everything was
   written (2026-11-22).

   The "Before you start" page (`calamares/branding/floppaos/before-you-start.qml`) is text only: FloppaOS is a
   hobby project by one person with no warranty, installing is at your own risk, back up your files first
   (especially next to Windows), and this is a preview tested in virtual machines. Same wording as the website.

   The "Floppa games" page (`calamares/branding/floppaos/floppa-games.qml`, shown by Calamares' notesqml
   module) has three tick boxes: install the Floppa Launcher (ticked), pin it to the taskbar (ticked), install
   Wine (not ticked). Nothing is downloaded during the installation. The step "Saving the Floppa games
   choices" (`calamares-modules/floppasetup`) writes them with the new user's login name to
   `/etc/floppaos/setup-choices.conf`; at that user's first login Floppa Setup does them once, without asking
   again (`setup/floppa-setup.py`; offline it says so and tries again at the next login). Other accounts get
   Floppa Setup's normal checklist.

   The "Secure Boot" page (`calamares/branding/floppaos/secure-boot.qml`) has one tick box, "Start FloppaOS with
   Secure Boot on" (not ticked). Ticked, it shows an 8-digit code and the four steps for the blue key-confirmation
   screen at the next start. The step "Setting up Secure Boot" (`calamares-modules/floppasecureboot`, right after
   the boot loader step) runs `floppaos-secureboot setup` in the new system: a key for this PC, GRUB and the
   kernel signed with it, Fedora's Microsoft-signed shim in front of GRUB (see `secureboot/README.md`). The code
   goes in a root-only file that is deleted right after, and never into the install log. If the setup fails, the
   installation still finishes and FloppaOS starts with Secure Boot off.
2. **Copy the live system** (`modules/unpackfs.conf`): Arch's live boot keeps the read-only system image
   mounted at `/run/archiso/airootfs`, also when it copied itself into RAM and unmounted the USB stick.
   The installer copies that image with rsync, so it needs no internet and installs exactly what was
   tested live, without anything that changed during the live session.
3. **Turn the copy into an installed system** (`target-cleanup.sh`, step "Preparing FloppaOS for its first
   start"). The live image is made for a USB stick, so it carries things an installed PC must not have:

   | What | Why it is changed |
   |---|---|
   | Empty `/boot` | The live kernel is on the stick. The kernel package keeps a copy in `/usr/lib/modules/<version>/vmlinuz`; it is copied to `/boot`, like Arch's own install hook does. |
   | Root logs in on the text console without a password; SSH allows root login with a password | Removed (`getty@tty1` autologin, `sshd_config.d/10-archiso.conf`, SSH server switched off). |
   | Root has no password | Locked, unless the user set an administrator password (the default reuses the user's password). |
   | Live user `floppa` (no password, sudo without password, automatic login) | Account, home, `sudoers.d/floppa-live` and the Plasma Login Manager autologin file removed. "floppa" cannot be chosen as the new account's name. |
   | Package keyring only in RAM (`etc-pacman.d-gnupg.mount`, `pacman-init.service`) | Removed; a real keyring is created and Arch's keys are added. Without this every update fails. |
   | 32-bit repository (multilib) | Switched on in `pacman.conf` (games need the 32-bit packages; the ISO now also ships it on). |
   | System log only in RAM, never suspend, live boot helpers, "wait for the clock" | Removed. |
   | Live-only packages (archiso boot hooks, memtest, UEFI shell, syslinux, live sounds) | Removed. |
   | Keyboard layout | Written as KDE's default (`/etc/xdg/kxkbrc`): Plasma on Wayland does not read the X11 keyboard file. |

4. **Boot image and bootloader:** mkinitcpio builds the boot image (with the FloppaOS boot screen: Calamares
   adds plymouth's hook and `splash` by itself because plymouth is installed); GRUB is installed (UEFI and
   BIOS, also at the UEFI fallback path) with "FloppaOS" in the menu and os-prober on, so Windows shows up too.
5. **Quiet start** (`grub-quiet.sh`): when GRUB found no other system, the boot menu is hidden (1 second,
   Esc shows it) and GRUB's "Loading Linux" text is left out, so the PC goes from the maker's logo straight to
   the FloppaOS boot screen. With Windows on the disk the menu is shown at every start (5 seconds) in FloppaOS's
   look: black, the caracal head, "Choose an operating system" (GRUB theme from `floppaos-defaults`), also
   without the "Loading" text. GRUB 2.16's extra firmware entries ("(EFI BootNext)") are switched off in
   `modules/grubcfg.conf`.
6. **Remove the installer** from the new system (`calamares`, `floppaos-installer`) and keep the log in
   `/var/log/floppaos-install.log` (root only).

## The live desktop during the install

**Disks & Devices pop-up.** Plasma's device notifier opens its pop-up by itself whenever a new device shows
up, and while the installer creates and mounts partitions that happened several times. `floppaos-install`
takes the device notifier out of the live session's system tray before Calamares starts and puts it back
when the installer closes (the tray's list of enabled items, `extraItems`, changed through Plasma's scripting
interface; tested in the VM 2026-11-21). Changing the notifier's own `popupOnNewDevice` setting does not work
in Plasma 6.8 while it runs: the tray keeps its applets inside itself, and the scripting interface cannot
reach them (research §19). Installed systems keep the notifier, so plugging in a USB stick still shows it.

**Keyboard.** On the Wayland live desktop Calamares sets the chosen layout through systemd-localed, but Plasma's KWin does
not follow localed. `live-keyboard.sh` (started by `floppaos-install`) applies each change to the live
session the way KDE's keyboard settings do. Without it, someone choosing a German layout would type the new
password with the US layout (y and z swapped) and could not log in afterwards.

## Files

| File | Installed as |
|---|---|
| `calamares/settings.conf` | `/etc/calamares/settings.conf`: page and step order |
| `calamares/modules/*.conf` | `/etc/calamares/modules/`: one file per step, each with a comment saying why |
| `calamares/branding/floppaos/` | branding: logo, welcome banner, slideshow (`show.qml`), sidebar colours, the "Floppa games" page (`floppa-games.qml`) |
| `calamares-modules/floppasetup/` | `/usr/lib/floppaos-installer/calamares-modules/floppasetup/`: FloppaOS's own step that saves the "Floppa games" choices |
| `calamares-modules/floppasecureboot/` | `/usr/lib/floppaos-installer/calamares-modules/floppasecureboot/`: FloppaOS's own step that runs `floppaos-secureboot setup` when the "Secure Boot" box is ticked |
| `art/*.svg`, `art/render.sh` | sources of the branding PNGs (FloppaOS logo: the caracal head) |
| `target-cleanup.sh` | `/usr/lib/floppaos-installer/target-cleanup` |
| `live-keyboard.sh` | `/usr/lib/floppaos-installer/live-keyboard` |
| `grub-quiet.sh` | `/usr/lib/floppaos-installer/grub-quiet` (last step, `modules/shellprocess-removeinstaller.conf`) |
| `floppaos-install.sh` | `/usr/bin/floppaos-install` (starts Calamares as root with the live session's display) |
| `floppaos-install.desktop` | start menu entry, and the icon on the live desktop (`iso/build.sh`) |

## Tests

- `tools/test-installer-cleanup.sh <iso> <empty folder> --initramfs` unpacks an ISO's system image, does what
  the installer does before the cleanup (remove the live user, create a user, write a German keyboard
  layout), runs `target-cleanup.sh` inside it (chroot) and checks 68 things (70 once FloppaOS's signing key exists) (also the boot screen theme,
  `grub-quiet.sh` with and without a Windows entry, the "Floppa games" page and the step that saves its
  choices, the "Secure Boot" page and step, Fedora's shim files, and signing the image's kernel with a
  throwaway key), then builds the boot image.
  The `iso` workflow runs it on every new image **before** uploading it. First run 2026-11-21 against the
  ISO of 2026-11-21 (3rd build): all checks passed, boot image built.
- All `calamares/modules/*.conf` validate against the schemas shipped with Calamares 3.4.2 and 3.4.3.
- **Calamares started inside the built image** (ISO of 2026-11-21, 4th build; chroot, invisible "offscreen" screen,
  45 seconds): settings, all 31 modules, the FloppaOS branding and the slideshow (`show.qml`) loaded without
  errors; all 12 Python steps compile under the image's Python 3.14; no missing libraries. The disk checks
  failed only because the test has no system D-Bus, so the partition library sees no disks. This found
  `ckbcomp` missing (keyboard picture on the keyboard page), now packaged (`packages/ckbcomp`).
- **Live VM test** (2026-11-21, ISO of the 7th build, QEMU without hardware acceleration, UEFI, blank 30 GB
  disk): every page shown and used (welcome, location, keyboard with the
  keyboard picture, erase disk, user, summary, confirmation, slideshow during the copy). Three bugs found and
  fixed in the launcher and keyboard helper: Qt fell back to X11 under sudo, the window stayed black with
  OpenGL Qt Quick, and Plasma 6.8 needs KConfig change notifications for the keyboard layout (research §14).
  After the fix, picking German switched the live desktop to German (US "z"/"y" keys typed "yz").
- **Full install test** (2026-11-21, ISO of the 7th build, UEFI, whole disk): all 37 jobs without an error; the installed
  system boots, logs in, gets the FloppaOS look, Floppa Setup and the German keyboard; no live leftovers. Five
  follow-up fixes (first-login splash, root's shell, GRUB title, live writable space, live indexing) are in
  research §14.
- **Next to Windows** (2026-11-22): tested in a VM with a stand-in Windows disk (`tools/windows-standin.sh`): Windows
  is found, the themed boot menu shows both systems, and the Windows partition's data is unchanged.
- Not tested yet: next to a real Windows installation; a run on real hardware.
