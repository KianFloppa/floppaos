# FloppaOS

A Windows 11-style gaming Linux with FloppaNet built in: KDE Plasma 6 with a Windows-like taskbar and start
menu, pure-black colours for OLED screens, and **Floppa Setup**, which installs the Floppa Launcher and the Floppa
games.

**Status: not released yet.** Everything here has been built and tested in virtual machines only. There is no
public download yet. What has changed so far: [CHANGELOG.md](CHANGELOG.md).

## Two ways to get it

| | **Setup Pack** | **FloppaOS ISO** |
|---|---|---|
| What it is | Scripts you run on a normal CachyOS install (KDE Plasma) | FloppaOS's own live and installer image |
| Base | Your CachyOS install, updated by CachyOS as usual | Arch Linux plus FloppaOS's own packages |
| How | `./install.sh`, no admin rights needed (except once for kdialog, if missing) | Start the image, then "Install FloppaOS" (like a Windows setup) |

Setup Pack, in Konsole on CachyOS with KDE Plasma 6:

```sh
git clone https://github.com/KianFloppa/floppaos.git
cd floppaos
./install.sh      # undo: ./uninstall.sh (back to KDE's own look)
```

More: [docs/install-guide.md](docs/install-guide.md).

## How to build

On Arch Linux, or in an `archlinux:base-devel` container, as root:

```sh
pacman -Syu --needed git python archiso librsvg plymouth grub noto-fonts
bash tools/build-packages.sh /tmp/floppaos-repo     # the FloppaOS packages + a pacman repository
bash iso/build.sh /tmp/floppaos-repo                # the ISO, in out/ (a container needs --privileged)
bash tools/test-installer-cleanup.sh out/*.iso /tmp/installer-test   # checks the installer's clean-up
```

GitHub Actions do the same: [`packages`](.github/workflows/packages.yml) on every push that changes a package,
[`iso`](.github/workflows/iso.yml) when started by hand. Details: [iso/README.md](iso/README.md) and
[installer/README.md](installer/README.md).

| Folder | What is in it |
|---|---|
| `look/` | The look: global theme, FloppaOS Start menu, colours, theme parts (from their own projects) |
| `setup/` | Floppa Setup (first-login helper for the Floppa games) |
| `installer/` | Calamares settings, branding and FloppaOS's install steps |
| `secureboot/` | Starting FloppaOS with Secure Boot on (shim, signed GRUB and kernels) |
| `iso/` | The live image (Arch Linux's `releng` profile plus FloppaOS) |
| `packages/` | Package recipes (`PKGBUILD`) |
| `tools/` | Build, test and check scripts |

## Rules FloppaOS follows

Comments in the code refer to these as "README rule 1-4".

1. **CachyOS:** its binary packages are never put in the ISO, its servers are never added to the image, and no
   script turns them on. Building from its public source is fine. Not affiliated with CachyOS.
2. **Arch Linux:** FloppaOS is "based on Arch Linux"; it is not called Arch and does not use Arch's logo.
3. **Microsoft:** "Windows 11-*style*" only. No Windows logo, no Microsoft wallpapers, icons or sound files,
   no Segoe UI font, no "Windows" in the product name. The start button shows FloppaOS's own logo.
4. **Credits:** every part taken from another project keeps its licence and has a line in
   [CREDITS.md](CREDITS.md).

Comments also mention "decision N" and "research §N": FloppaOS's planning notes, which are kept private.

## Licence

FloppaOS's own code and files: **GPL-3.0-or-later** ([LICENSE](LICENSE)), except the logo and artwork files
listed in [TRADEMARKS.md](TRADEMARKS.md). Parts from other projects keep their own licences
([CREDITS.md](CREDITS.md)).

The name **FloppaOS**, the FloppaOS logo and FloppaOS's own artwork are **not** free to use for other projects:
see [TRADEMARKS.md](TRADEMARKS.md). Forks are welcome under a different name and logo.

Not affiliated with Microsoft, CachyOS or Arch Linux.
