# Source code of FloppaOS

FloppaOS is made of free software. Many of its programs are under the GNU GPL, the LGPL or similar licences,
which let you get their source code. This page says where it is for every FloppaOS release. A copy of this page
is in every FloppaOS image and installed system as `/usr/share/doc/floppaos/SOURCE-CODE.md`.

## Where the source code is

For a release with the version `<version>` (for example `0.1.0-preview`):

| What | Where |
|---|---|
| FloppaOS's own scripts, settings, artwork and packages (`floppaos-*`, `calamares`, `ckbcomp`) | This repository at the tag `v<version>`: [github.com/KianFloppa/floppaos](https://github.com/KianFloppa/floppaos), build recipes in `packages/` |
| Which packages are in the image, at which version and under which licence | `packages.tsv` and `sources.tsv`, attached to the release `v<version>` on GitHub |
| The complete source of every package under a copyleft licence (GPL, LGPL, AGPL, MPL, EPL, CDDL, EUPL) | The release `sources-<version>` on GitHub: one `<package>-<version>.src.tar.gz` per source package, listed in `SOURCES-INDEX.tsv` with size and SHA-256 |
| The build recipes of all other packages | Arch Linux: `gitlab.archlinux.org/archlinux/packaging/packages/<package>`, tag `<version>` (an epoch `1:` is written `1-`) |

Each `.src.tar.gz` is what Arch Linux's `makepkg --allsource` makes from the package's recipe at exactly the
version in the image: the `PKGBUILD`, Arch's patches and all upstream source files, checked against the
checksums in the `PKGBUILD`. To build a package from it, unpack it on Arch Linux and run `makepkg` in the folder.
Archives over 1.9 GB are split into `.part00`, `.part01`, ...; join them with `cat` first.

**When a package is missing from the archive.** Upstream servers come and go: some block cloud servers, some
move or disappear. The archive tries copies first (GNU's mirrors, the Internet Archive, Arch Linux's own source
archives, each checked against the recipe's checksums). Packages it still could not archive are listed in
`FAILED.txt` in the source release. Their source is covered by the written offer below; where it was at release
time is in the release notes.

The FloppaOS image is built with [`iso/build.sh`](../iso/build.sh) from Arch Linux's packages and FloppaOS's
own; the GitHub Action [`iso`](../.github/workflows/iso.yml) shows every step.

## Written offer

For at least three years after the last time a FloppaOS release is offered for download, KianFloppa will give
anyone who asks a complete, machine-readable copy of the corresponding source code of every program in that
release that is under the GNU GPL or LGPL, for no more than the cost of making and sending the copy. Write to
the contact in the [legal imprint](https://mein.online-impressum.de/kianfloppa/) and name the release.

## No warranty

FloppaOS is a free hobby project made by one person. It comes with no warranty: installing it is at your own
risk. Back up your files first, especially if you install FloppaOS next to Windows. Each program keeps its own
licence; FloppaOS's own files are under the GPL-3.0-or-later ([LICENSE](../LICENSE)), whose sections 15 and 16
say the same. The name FloppaOS, the caracal logo and the artwork are not under the GPL
([TRADEMARKS.md](../TRADEMARKS.md)).
