#!/usr/bin/env python3
"""Find icons that show Microsoft product logos or the Windows logo in an icon theme (README rule 3).

  icon-audit.py report <theme dir> [<tsv file>]   count and list the matches (nothing is changed)
  icon-audit.py strip <theme dir> <start-here svg> delete the matches in place, and draw every start-here
                                                   icon with our own mark instead of the Windows logo

Matching goes by icon name (file name without extension), so it finds the logo icons that are named after a
product. It cannot judge drawings: an icon with a neutral name that was drawn after a Windows 11 icon is not
found. docs/research.md section 15 says how the lists were made and what was checked by eye.
Deleted icons fall back to the inherited themes (the theme's index.theme: breeze, hicolor).
Run with python3 -I; the theme folder is only read (report) or has files deleted (strip), never executed.
"""
import os
import re
import sys

# Whole-name patterns, matched against the lower-case icon name. Each list was checked against the names in
# NeoWin 1f01da8 (research section 15); false hits found there are listed in KEEP below.
RULES = {
    # The Windows logo itself.
    "windows-logo": [
        r"start-here(-.*)?", r"distributor-logo-window.*", r".*\bwindows(1[01])?\b(?<!system-windows).*",
        r"win(10|11|ver|dows)", r"os-windows.*", r".*-windows-logo.*",
    ],
    # Other companies' logos used as "this system's" logo (start-here and distributor-logo showed the Apple and
    # Ubuntu logos in NeoWin), and Apple-logo folders.
    "other-os-logo": [r"distributor-logo", r"folder-apple(-symbolic)?"],
    # Microsoft products and companies (Microsoft, GitHub, LinkedIn, Mojang/Minecraft, Xbox).
    "microsoft-product": [
        r".*microsoft.*", r"(com\.)?(ms|microsoft)[-_.]?edge.*", r"edge(-(beta|dev|canary))?", r".*msedge.*",
        r".*\bms-?teams\b.*", r"teams(-for-linux|-insiders)?", r".*skype.*", r".*onedrive.*", r".*skydrive.*",
        r".*outlook.*", r".*onenote.*", r".*sharepoint.*", r".*yammer.*", r".*\bxbox.*", r".*minecraft.*",
        r".*mojang.*", r"(ms-?)?bing(-.*)?", r".*cortana.*", r".*copilot.*", r"msn(-.*)?", r".*hotmail.*",
        r".*\bazure.*", r".*powershell.*", r"pwsh", r".*nuget.*", r"wsl(-.*)?", r".*vscode.*",
        r".*visual-?studio.*", r"vs-?code(-.*)?", r"code(-(oss|insiders|url-handler))?", r"com\.visualstudio\..*",
        r"(appimagekit-)?github(-desktop)?", r"folder-github(-symbolic)?", r"io\.github\.shiftey\.desktop", r".*linkedin.*", r".*power-?bi.*", r".*\b(win|ms-?)word\b.*", r"ms-?excel.*", r"excel",
        r"(ms-?)?powerpoint.*", r"ms-?access", r"ms-?publisher", r"(ms-?)?visio(-.*)?", r"ms-?project",
        r"ms-?paint", r"mspaint", r"wordpad", r".*internet-?explorer.*", r"iexplore", r"clipchamp.*",
        r"ms-?store", r"winstore", r"mstsc", r"ms-?todo", r".*dotnet.*", r"typescript",
    ],
    # File-type icons for Microsoft formats and Windows programs (these often carry an Office or Windows logo).
    "microsoft-file-type": [
        r"application-msword.*", r"application-vnd\.ms-.*", r"application-vnd\.openxmlformats-officedocument.*",
        r"application-vnd\.visio.*", r"application-x-ms(i|download|-dos-executable|-shortcut|-wim).*",
        r"application-vnd\.microsoft\..*", r"application-x-msdos-program", r"application-x-mswrite",
        r"application-x-mswinurl", r"application-x-ms-.*", r"application-x-wine-extension-.*",
    ],
}
# Names that a pattern catches but that are not Microsoft logos (found while checking the lists by eye).
# KDE's window-behaviour settings icons (preferences-system-windows*) are already excluded by the pattern itself.
KEEP = {"cs-windows", "kde-windows", "gnome-windows", "focus-windows-symbolic",  # drawn as a plain window
        "image-vnd.microsoft.icon"}  # .ico files: a plain picture icon
# Icons that are deleted and then drawn again with our own mark, in the folders that had them.
REDRAW = {"start-here", "distributor-logo"}
COMPILED = {cat: [re.compile(p + r"\Z") for p in pats] for cat, pats in RULES.items()}


def icon_name(path):
    base = os.path.basename(path)
    for ext in (".svg", ".svgz", ".png", ".xpm"):
        if base.lower().endswith(ext):
            return base[: -len(ext)].lower()
    return base.lower()


def category(name):
    if name in KEEP:
        return None
    for cat, pats in COMPILED.items():
        if any(p.match(name) for p in pats):
            return cat
    return None


def walk(theme):
    for root, dirs, files in os.walk(theme):
        dirs.sort()
        for f in sorted(files):
            yield os.path.join(root, f)


def matches(theme):
    """Matching entries: files and links whose own name matches, plus links that end at a matching file."""
    hits = {}
    entries = list(walk(theme))
    for p in entries:
        cat = category(icon_name(p))
        if cat:
            hits[p] = (cat, "name")
    # Links (also chains of links) that end at a deleted icon would dangle, so they go too.
    changed = True
    while changed:
        changed = False
        for p in entries:
            if p in hits or not os.path.islink(p):
                continue
            target = os.path.normpath(os.path.join(os.path.dirname(p), os.readlink(p)))
            if target in hits:
                hits[p] = (hits[target][0], "link to " + os.path.relpath(target, theme))
                changed = True
    return entries, hits


def report(theme, tsv=None):
    entries, hits = matches(theme)
    by_cat = {}
    names = {}
    for p, (cat, why) in hits.items():
        by_cat[cat] = by_cat.get(cat, 0) + 1
        names.setdefault(cat, set()).add(icon_name(p))
    print(f"{len(entries)} entries in {theme} (files and links); {len(hits)} match:")
    for cat in RULES:
        print(f"  {cat}: {by_cat.get(cat, 0)} entries, {len(names.get(cat, ()))} icon names")
    if tsv:
        with open(tsv, "w") as out:
            out.write("category\tentry\tkind\twhy\n")
            for p in sorted(hits):
                cat, why = hits[p]
                kind = "link" if os.path.islink(p) else "file"
                out.write(f"{cat}\t{os.path.relpath(p, theme)}\t{kind}\t{why}\n")
        print(f"List written to {tsv}")


def strip(theme, mark):
    with open(mark, "rb") as f:
        svg = f.read()
    entries, hits = matches(theme)
    for p in sorted(hits, key=lambda q: not os.path.islink(q)):  # links first
        os.remove(p)
    # Our own mark instead, in every folder that had one of these (vector, so one drawing fits all sizes).
    folders = {}
    for p in hits:
        if icon_name(p) in REDRAW:
            folders.setdefault(icon_name(p), set()).add(os.path.dirname(p))
    for name, dirs in folders.items():
        for d in dirs:
            with open(os.path.join(d, name + ".svg"), "wb") as out:
                out.write(svg)
    drawn = sum(len(d) for d in folders.values())
    print(f"Removed {len(hits)} entries; drew our mark {drawn} times ({', '.join(sorted(folders))}).")
    # Check: nothing may match any more, except our own mark.
    _, left = matches(theme)
    bad = [p for p in left if not (os.path.isfile(p) and open(p, "rb").read() == svg)]
    if bad:
        sys.exit("Still matching: " + ", ".join(os.path.relpath(p, theme) for p in sorted(bad)[:10]))


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "report":
        report(sys.argv[2], sys.argv[3] if len(sys.argv) > 3 else None)
    elif len(sys.argv) == 4 and sys.argv[1] == "strip":
        strip(sys.argv[2], sys.argv[3])
    else:
        sys.exit(__doc__)
