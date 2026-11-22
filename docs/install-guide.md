# Install guide

Two ways to get FloppaOS. The ISO is a preview (0.1.1-preview), tested in virtual machines so far
(see `CHANGELOG.md`).

> **No warranty.** FloppaOS is a free hobby project made by one person. Installing it, or the Setup Pack, is at
> your own risk. Back up your files first, especially if you install FloppaOS next to Windows.

| | Way 1: Setup Pack | Way 2: FloppaOS ISO |
|---|---|---|
| You install | CachyOS (KDE Plasma), then run one command | FloppaOS itself, from its own installer |
| Updates | CachyOS updates as usual | Arch Linux updates, FloppaOS packages later |
| Good for | Trying the look on an existing CachyOS | Testing the real FloppaOS |

## Way 1: Setup Pack on CachyOS

1. **Install CachyOS with KDE Plasma** (from cachyos.org), on a PC or in a virtual machine such as
   VirtualBox. In the CachyOS installer pick **KDE Plasma**.
2. **Get FloppaOS.** In CachyOS open **Konsole** and type:
   ```sh
   git clone https://github.com/KianFloppa/floppaos.git
   cd floppaos
   ./install.sh
   ```
   Floppa Setup uses **kdialog**, a small KDE program, for its windows. CachyOS with KDE has it; if it is
   missing (for example on the CachyOS live system), `install.sh` asks: press **Enter** and type your
   password. This updates CachyOS and adds kdialog (a few minutes).
3. **What happens:** the FloppaOS look is applied (black taskbar, FloppaOS Start menu, icons, shortcuts) and
   **Floppa Setup** opens. Tick what you want and press the button: it installs the Floppa Launcher and pins
   it to the taskbar. The launcher then installs the games.
4. **Log out and back in once**, so all Windows shortcuts work.
5. **Optional:** a black login screen too (asks for your password): `sudo ./look/login-screen.sh`.

Update later: `cd floppaos && git pull && ./install.sh`. Undo: `./uninstall.sh` (back to KDE's own look).

## Way 2: FloppaOS ISO (virtual machine or USB stick)

1. **Get the ISO** from [floppaos.pages.dev](https://floppaos.pages.dev/#download) and check it: the
   SHA-256 checksum next to the download must match. On Windows, in PowerShell:
   `Get-FileHash floppaos-0.1.1-preview-x86_64.iso`; on Linux: `sha256sum floppaos-0.1.1-preview-x86_64.iso`.
2. **Start it** in a new virtual machine, for example in VirtualBox: type Arch Linux (64-bit), **UEFI on**,
   6 GB memory, 4 cores, a new 20 GB disk, 3D acceleration on, the ISO in the optical drive. On a real PC:
   write the ISO to a USB stick of 4 GB or more (everything on it is deleted), for example with Rufus in
   **DD Image mode**, switch **Secure Boot off** in the PC's settings first (the USB stick does not start with it
   on), and start the PC from the stick.
3. **Install.** On the live desktop double-click **Install FloppaOS** (also pinned on the taskbar). Pick
   language, time zone and keyboard, then **Erase disk** (only the VM's own empty disk), then your name and
   password. On **Floppa games** tick what Floppa Setup should do after the first start (Floppa Launcher and
   taskbar pin are ticked; Wine is not). On **Secure Boot** tick the box if your PC needs Secure Boot (some Windows
   games with anti-cheat do), and write the 8-digit code down. Wait until it says it is done, close the installer
   and shut down.
4. **First start.** Remove the ISO from the VM (VirtualBox: Settings → Storage → remove the disk image),
   start the VM, log in. Floppa Setup does what you ticked (it needs internet; offline it tries again at the
   next login) and shows what it did. There is no boot menu when FloppaOS is the only
   system; press **Esc** right after the maker's logo to see it (for example for the "Advanced options").
5. **Secure Boot** (only if you ticked it): at the first start a blue screen appears. Press a key within 10
   seconds, choose **Enroll MOK**, **Continue**, **Yes**, type the code at "Password:", choose **Reboot**. Then
   switch Secure Boot back on in the PC's settings. Missed it? After login FloppaOS offers a new code.

## If something goes wrong

- **Do not start games in the VirtualBox VM.** Starting a game crashed VirtualBox itself (2026-11-21); a VM
  cannot use the real graphics card anyway. Games are tested on real hardware later.
- The desktop is slow in the VM: give the VM more cores and memory, and keep 3D acceleration on.
- Report problems as a GitHub issue in this repository, with a photo or screenshot.
