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

The `iso` workflow uploads each finished image with a `.sha256` file to the Cloudflare R2 bucket
`floppaos-iso`, which is private. Two folders:

- `iso/`: test builds (`release` left empty), named by date. The newest 3 are kept. Nobody can download them;
  the run summary shows the file name, size and checksum, but no link, because this repository's runs are public.
- `release/`: release builds, named by version (`floppaos-0.1.0-preview-x86_64.iso`). Never deleted by the
  workflow. The website serves them to everyone at `https://floppaos.pages.dev/download/<file>`: the Pages
  Function `functions/download/[[path]].js` reads them through the binding `RELEASES` (Pages project `floppaos`,
  production settings) and answers only for file names of that form inside `release/`, with HEAD and byte ranges
  (resumable downloads). Downloads cost nothing: R2 has no egress fees, and the function only passes the file on.

The upload needs four repository secrets (Settings → Secrets and variables → Actions → Secrets):
`R2_ACCOUNT_ID`, `R2_BUCKET`, `R2_ACCESS_KEY_ID` and `R2_SECRET_ACCESS_KEY` (an R2 API token with Object Read &
Write on that one bucket). Without them the workflow still builds and tests the image; it just skips the upload.

## Releases

1. Set the file `VERSION` to the release version (for example `0.1.0-preview`) and note the release in
   `CHANGELOG.md`.
2. Actions → `iso` → Run workflow with `release` = that version. The run builds and tests the image, uploads it to
   `release/` (so `floppaos.pages.dev/download/floppaos-<version>-x86_64.iso` works from then on), makes the
   **draft** GitHub release `v<version>` with the checksum and the package lists, makes the release
   `sources-<version>` and archives the source code of every copyleft package into it (`sources.yml`, about an
   hour; `docs/source-code.md` says what is in it).
3. Download the image from the website, check the checksum and install it in a virtual machine.
4. Publish: write the notes of `v<version>` (what is new, the no-warranty notice, the download link, the
   checksum, the source code) and publish the draft; put the link and the checksum in the website's download
   section (`site/index.html`), the status line and `llms.txt`.
