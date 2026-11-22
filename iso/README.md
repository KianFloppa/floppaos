# FloppaOS ISO

`iso/build.sh` builds the FloppaOS live/installer image with `mkarchiso`:

1. Starts from Arch Linux's own `releng` profile (the official monthly ISO), copied from the `archiso` package.
2. Adds the packages in `packages.extra`: KDE Plasma, gaming drivers (AMD first), and the FloppaOS packages
   from this repository's `packages/` (built first and offered to pacman as a local repository).
3. Copies `airootfs/` on top: a live user `floppa` that logs in automatically, branding (`os-release`).
4. Builds `out/floppaos-<date>-x86_64.iso`.

The image is **based on Arch Linux** and uses only Arch's own servers plus our packages. It does not contain or
point at CachyOS's packages or servers (README rule 1).

It boots into the FloppaOS desktop with Floppa Setup; "Install FloppaOS" on the desktop starts the installer
(Calamares, see `installer/README.md`). Every ISO build also runs `tools/test-installer-cleanup.sh` on the new image
before uploading it.

## Build

On GitHub: Actions → **iso** → Run workflow (about 15 minutes). On an Arch system, as root:
`bash iso/build.sh <folder with the built FloppaOS packages and floppaos.db>` (build the packages first with
`tools/build-packages.sh`, see the main README). The image lands in `out/` (or in `$OUT`).

## Downloads

There is no public download yet; it comes with the first release. Until then the `iso` workflow uploads each
finished image to a private Cloudflare R2 bucket (folder `iso/`, the newest 3 images are kept, each with a
`.sha256` file). The run summary shows the file name, size and checksum, but no download link, because this
repository's workflow runs are public.

The upload needs four repository secrets (Settings → Secrets and variables → Actions → Secrets):
`R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` (an R2 API token with Object Read &
Write on that one bucket). Without them the workflow still builds and tests the image; it just skips the upload.
