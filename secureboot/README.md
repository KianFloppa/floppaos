# FloppaOS Secure Boot

Lets FloppaOS start with Secure Boot on, so a PC that needs Secure Boot for Windows games with anti-cheat never has
to switch it off and on again. Windows keeps working: Microsoft's keys in the firmware are not touched.

## How it works

1. **shim** (package `floppaos-shim`): Fedora's boot loader, signed by Microsoft. Fedora's build 16.1-7 carries
   two Microsoft signatures (Microsoft Corporation UEFI CA 2011 and Microsoft UEFI CA 2023), so it starts on old
   and new PCs. shim only starts what is signed by a key the PC's owner confirmed.
2. **A key for this PC** ("Machine Owner Key", made by `floppaos-secureboot setup` in `/var/lib/floppaos-secureboot`,
   the private part readable by root only). GRUB and every kernel are signed with it.
3. **GRUB with everything inside**: with Secure Boot on, GRUB may not load its modules from the disk, so the
   signed `grubx64.efi` contains every module the boot menu needs, including FloppaOS's menu theme and starting
   Windows. Its SBAT data (shim's list of GRUB security generations) matches the installed GRUB version.
4. **One confirmation**: at the next start shim's blue screen (MokManager) asks to add the key, with an 8-digit
   code. Digits only, because that screen uses the firmware's US keyboard layout.
5. **Updates**: pacman hooks sign new kernels and rebuild and sign GRUB after GRUB or shim updates.

```
firmware (Microsoft keys) -> shimx64.efi (Microsoft-signed) -> grubx64.efi (this PC's key) -> vmlinuz (this PC's key)
```

## What the user sees

The installer's **Secure Boot** page has one tick box. When it is ticked the page shows the code and these steps:

1. At the first start of FloppaOS a blue screen appears ("Press any key to perform MOK management"). Press any key within 10 seconds.
2. Choose **Enroll MOK**, then **Continue**, then **Yes**.
3. At "Password:" type the code (only the 8 digits) and press Enter.
4. Choose **Reboot**. Then turn Secure Boot back on in the PC's settings (UEFI).

The USB stick itself starts only with Secure Boot **off** (like Arch Linux's own ISO), so Secure Boot is switched off
for installing and on again after the key is confirmed.

Until the key is confirmed, a reminder shows the code after every login. If the blue screen was missed (it waits
10 seconds, then the request is gone), the reminder offers a new code (asks for the password).

## Commands

```
sudo floppaos-secureboot setup     # set it up on an installed FloppaOS (prints a new code)
sudo floppaos-secureboot enroll    # ask for the confirmation again, with a new code
floppaos-secureboot status         # firmware state, key confirmed or not, GRUB/shim/kernels signed
sudo floppaos-secureboot update    # rebuild and sign GRUB, copy shim, sign kernels (the hooks do this)
sudo floppaos-secureboot off       # back to plain GRUB (switch Secure Boot off in the firmware first)
```

If FloppaOS does not start with Secure Boot on (for example "bad shim signature" after a kernel was copied by hand):
switch Secure Boot off in the PC's settings, start FloppaOS, run `sudo floppaos-secureboot update`, switch it on again.

## Files

| File | Installed as |
|---|---|
| `floppaos-secureboot.sh` | `/usr/bin/floppaos-secureboot` |
| `95-floppaos-secureboot-kernel.hook` | `/usr/share/libalpm/hooks/`: signs new kernels |
| `95-floppaos-secureboot-boot.hook` | `/usr/share/libalpm/hooks/`: rebuilds and signs GRUB after GRUB or shim updates |
| `floppaos-secureboot-check.service` | at start-up: forgets the code once the key is confirmed |
| `floppaos-secureboot-reminder.desktop` | `/etc/xdg/autostart/`: the reminder at login |

Packages: `packages/floppaos-secureboot`, `packages/floppaos-shim`. Installer: `installer/calamares/branding/floppaos/secure-boot.qml`
(page) and `installer/calamares-modules/floppasecureboot` (step, runs `floppaos-secureboot setup` right after the
boot loader is installed; it never stops the installation).

## Tested (2026-11-22, QEMU with OVMF's Secure Boot firmware and Microsoft's keys)

- Setup on the installed FloppaOS next to the stand-in Windows: key made, kernel and GRUB signed, shim in place,
  boot entry "FloppaOS" -> `shimx64.efi`, fallback path replaced only because it held FloppaOS's GRUB.
- Next start: the blue screen, the key added with the 8-digit code. A missed screen (no key pressed) drops the
  request; `enroll` asks again.
- With Secure Boot on: the FloppaOS menu in its theme (Windows entry included), the kernel starts, the desktop works.
  `mokutil --sb-state`: "SecureBoot enabled"; the kernel loads this PC's key ("integrity: Loaded X.509 cert").
- Kernel and GRUB reinstalled with pacman: both hooks signed again, FloppaOS started again with Secure Boot on.
- An unsigned kernel is refused ("bad shim loader signature"); after `sign-kernels` it starts again.
- The installer page (tick box, code, steps) and the reminder were shown in the desktop.
