# FloppaOS's package signing key

Installed FloppaOS PCs get FloppaOS's own packages (look, Floppa Setup, installer parts, Secure Boot tool) from a
pacman repository on the release [`packages-x86_64`](https://github.com/KianFloppa/floppaos/releases/tag/packages-x86_64)
of this repo. pacman installs them only when they are signed with this key.

**Status: no key yet.** Until `floppaos.gpg` is in this folder nothing is signed or published, the ISO has no
`[floppaos]` repository, and FloppaOS's own packages on an installed PC stay as the ISO installed them.

## How it is set up

| Part | Where |
|---|---|
| Main key (signs and certifies, ed25519) | Only on Kian's PC. Never in this repo, never on GitHub. |
| Signing subkey (ed25519) | Its secret part is the Actions secret `PACKAGE_SIGNING_KEY` of this repo. The `publish` job of [packages.yml](../.github/workflows/packages.yml) signs with it ([tools/publish-packages.sh](../tools/publish-packages.sh)). |
| `floppaos.gpg` | The public key (main key and subkeys). Public, safe to share. |
| `floppaos-trusted` | The main key's fingerprint, `<fingerprint>:4:`. pacman trusts this key and every valid subkey of it. |
| `floppaos-revoked` | Fingerprints of main keys that must no longer be trusted (empty). |
| `floppaos-keyring` package | Puts the three files into `/usr/share/pacman/keyrings/`; `pacman-key --populate` adds them (the installer does that for every key). |
| pacman.conf on FloppaOS | `[floppaos]`, `SigLevel = Required`, `Server = https://github.com/KianFloppa/floppaos/releases/download/packages-$arch` (added by [iso/build.sh](../iso/build.sh)) |

The publish script refuses a secret that does not belong to the key in `floppaos-trusted`, signs every package and
the repository database, and checks every signature with only `floppaos.gpg` before it uploads anything. Tested
2026-11-22 with a throwaway key in a VM: pacman with only the public key trusted installed from the repository
(also a file renamed because of a `+` in its version), refused a package changed after signing, and the script
refused a secret of another key.

## Switching it on (once)

1. Kian makes the key on his PC and pastes the subkey into the secret `PACKAGE_SIGNING_KEY` himself (a helper script
   does the rest; the main key never leaves his PC).
2. `floppaos.gpg` and `floppaos-trusted` are committed here. The packages workflow then builds `floppaos-keyring`,
   signs everything and publishes the release.
3. Only after that release exists, build a new ISO: it carries the key and the `[floppaos]` repository. (An ISO
   with the repository but no release yet would make `pacman -Syu` fail.)

## If something goes wrong

- **The signing subkey leaked** (for example the secret was pasted somewhere): the main key on Kian's PC makes a
  new subkey and revokes the old one, and signs a new `floppaos-keyring` with the new public key. PCs accept that
  package because they trust the main key. Then the new subkey goes into `PACKAGE_SIGNING_KEY`.
- **Kian's PC is lost:** updates keep working (GitHub has the subkey). A new main key is made and shipped in a new
  `floppaos-keyring`, signed with the old subkey while it still works.
- Neither key expires; there is nothing to renew.
