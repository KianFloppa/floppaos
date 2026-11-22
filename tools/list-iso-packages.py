#!/usr/bin/env python3
"""List the packages inside a FloppaOS image, for the source code offer (docs/source-code.md).

Usage: list-iso-packages.py LOCAL_DB OUT_DIR
  LOCAL_DB  the image's pacman database folder (var/lib/pacman/local, unpacked from airootfs.sfs)
  OUT_DIR   gets two files:
    packages.tsv  one line per installed package: name, version, source package (pkgbase), licences
    sources.tsv   one line per source package: pkgbase, version, licences, where its source is
                  ("floppaos" = this repository, "arch" = Arch Linux's packaging repository + upstream)

SPDX-License-Identifier: GPL-3.0-or-later
"""
import os
import re
import sys

# FloppaOS's own packages: their source is this repository (packages/<name>/PKGBUILD).
OWN = re.compile(r"^(floppaos-.*|calamares|ckbcomp)$")


def read_desc(path):
    fields, key = {}, None
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if line.startswith("%") and line.endswith("%"):
                key = line.strip("%")
                fields[key] = []
            elif line and key:
                fields[key].append(line)
            else:
                key = None
    return fields


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    db, out = sys.argv[1], sys.argv[2]
    os.makedirs(out, exist_ok=True)
    pkgs, bases = [], {}
    for entry in sorted(os.listdir(db)):
        desc = os.path.join(db, entry, "desc")
        if not os.path.isfile(desc):
            continue
        d = read_desc(desc)
        name, ver = d["NAME"][0], d["VERSION"][0]
        base = d.get("BASE", [name])[0]
        lic = " ".join(d.get("LICENSE", [])) or "unknown"
        pkgs.append((name, ver, base, lic))
        b = bases.setdefault((base, ver), set())
        b.update(lic.split(" "))
    with open(os.path.join(out, "packages.tsv"), "w", encoding="utf-8") as f:
        f.write("# name\tversion\tsource package\tlicences\n")
        for p in pkgs:
            f.write("\t".join(p) + "\n")
    with open(os.path.join(out, "sources.tsv"), "w", encoding="utf-8") as f:
        f.write("# source package\tversion\tlicences\twhere\n")
        for (base, ver), lic in sorted(bases.items()):
            where = "floppaos" if OWN.match(base) else "arch"
            f.write(f"{base}\t{ver}\t{' '.join(sorted(lic))}\t{where}\n")
    print(f"{len(pkgs)} packages from {len(bases)} source packages")


if __name__ == "__main__":
    main()
