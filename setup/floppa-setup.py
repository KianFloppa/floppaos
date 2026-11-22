#!/usr/bin/env python3
"""Floppa Setup (FloppaOS Phase 2).

Checks that this PC is ready for the Floppa games and offers to set up what is missing.

How the pieces fit together:
  * The Floppa Launcher installs, updates and starts the games (Floppa Mining, Floppa Mystery, ...).
  * FloppaNet is the overlay built into every Floppa game (F2 in a game). It is not installed
    separately: a game that is up to date has the current FloppaNet.
So "FloppaNet ready" means: launcher installed, games installed, F2 free.

On a PC installed from the FloppaOS ISO, the installer's "Floppa games" page has tick boxes for the
launcher, the taskbar pin and Wine (/etc/floppaos/setup-choices.conf). At the first login of the user the
installer created, Floppa Setup does what was ticked without asking again (once; offline it tries again at
the next login). Everyone else gets the checklist below.

Only the Python standard library is used. Dialogs use kdialog (part of KDE). Without it, a notification
says how to get it (start menu, login) or everything is printed in the terminal; --check always prints.
"""
import argparse
import hashlib
import io
import json
import os
import pwd
import re
import shutil
import subprocess
import sys
import time
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

VERSION = "0.6"
SITE = "https://floppamining.com"
HOME = Path.home()
_xdg = os.environ.get("XDG_DATA_HOME", "")
DATA = Path(_xdg) if _xdg.startswith("/") else HOME / ".local/share"
LAUNCHER_DATA = DATA / "FloppaMining"       # the launcher's own folder, games are inside it
LAUNCHER_DIR = DATA / "FloppaLauncher"      # where Floppa Setup puts the launcher program
LAUNCHER_EXE = LAUNCHER_DIR / "FloppaLauncher.x86_64"
DESKTOP_ENTRY = HOME / ".local/share/applications/floppa-launcher.desktop"
MAX_DOWNLOAD = 200 * 1024 * 1024
# Written by the FloppaOS installer's "Floppa games" page (installer/calamares-modules/floppasetup).
INSTALLER_CHOICES = Path("/etc/floppaos/setup-choices.conf")
_xdg_state = os.environ.get("XDG_STATE_HOME", "")
STATE = Path(_xdg_state) if _xdg_state.startswith("/") else HOME / ".local/state"
CHOICES_DONE = STATE / "floppa-setup" / "installer-choices-done"
# Optional: Wine runs Windows games (over 1 GB with its 32-bit parts, so never ticked by default).
# The 32-bit packages need the multilib repository, which FloppaOS turns on.
WINE_PACKAGES = ["wine", "wine-mono", "wine-gecko", "winetricks"]
# id, title, folder inside the launcher's folder, manifest path (same list as the launcher's)
GAMES = [
    ("mining", "Floppa Mining", "game", "/launcher/latest.json"),
    ("mystery", "Floppa Mystery", "mystery", "/launcher/mystery.json"),
    ("felony", "Floppa Felony", "felony", "/launcher/felony.json"),
]
OK, TODO, INFO, FAIL = "ok", "todo", "info", "fail"
MARK = {OK: "✔", TODO: "✘", INFO: "•", FAIL: "✘"}
NEEDS_KDIALOG = ("Floppa Setup needs kdialog, a small KDE program, for its window (missing or too new for this "
                 "system). In Konsole: sudo pacman -Syu --needed kdialog (this also updates the system), then open "
                 "Floppa Setup again.")


def fetch(url, limit=MAX_DOWNLOAD):
    """Download over https only (plain http is allowed for a local test site)."""
    u = urllib.parse.urlparse(url)
    local = u.scheme == "http" and u.hostname in ("127.0.0.1", "localhost")
    if u.scheme != "https" and not local:
        raise ValueError("refusing to download from a non-https address: " + url)
    req = urllib.request.Request(url, headers={"User-Agent": "FloppaSetup/" + VERSION})
    with urllib.request.urlopen(req, timeout=20) as r:
        data = r.read(limit + 1)
    if len(data) > limit:
        raise ValueError("download is larger than expected")
    return data


def manifest(path):
    try:
        m = json.loads(fetch(SITE + path, 1024 * 1024).decode("utf-8"))
        return m if isinstance(m, dict) else None
    except Exception:
        return None


def find_launcher():
    """Path of the installed launcher program, or None."""
    if DESKTOP_ENTRY.is_file():
        m = re.search(r'^Exec="?([^"\n]+?)"?(?:\s+--\S+)*\s*$', DESKTOP_ENTRY.read_text(errors="replace"), re.M)
        if m and Path(m.group(1)).is_file():
            return Path(m.group(1))
    return LAUNCHER_EXE if LAUNCHER_EXE.is_file() else None


def f2_conflict():
    """Name of a KDE global shortcut that uses plain F2, or None."""
    rc = HOME / ".config/kglobalshortcutsrc"
    if not rc.is_file():
        return None
    for line in rc.read_text(errors="replace").splitlines():
        if "=" not in line or line.startswith("["):
            continue
        name, value = line.split("=", 1)
        if name.startswith("_k_"):
            continue
        active = value.split(",", 1)[0]
        if "F2" in [k.strip() for k in active.split("\\t")]:
            return name
    return None


def has_vulkan():
    for d in ("/usr/share/vulkan/icd.d", "/etc/vulkan/icd.d"):
        if os.path.isdir(d) and any(n.endswith(".json") for n in os.listdir(d)):
            return True
    return False


def run_checks():
    """Returns (results, latest) where results is a list of (status, text) and latest is Floppa Mining's manifest."""
    res = []
    latest = manifest(GAMES[0][3])
    if latest:
        res.append((OK, "Floppa servers reachable"))
    else:
        res.append((FAIL, "Floppa servers not reachable (no internet, or the site is down)"))

    exe = find_launcher()
    if exe:
        res.append((OK, "Floppa Launcher installed"))
    elif latest and not (isinstance(latest.get("linux"), dict) and latest["linux"].get("launcher_url")):
        res.append((INFO, "Floppa Launcher: no Linux build offered right now"))
    else:
        res.append((TODO, "Floppa Launcher not installed"))

    for i, (gid, title, folder, mpath) in enumerate(GAMES):
        m = latest if i == 0 else manifest(mpath)
        lx = m.get("linux") if isinstance(m, dict) else None
        if not isinstance(lx, dict) or not lx.get("exe"):
            res.append((INFO, title + ": " + ("no Linux build yet" if m else "could not check")))
            continue
        if (LAUNCHER_DATA / folder / os.path.basename(str(lx["exe"]))).is_file():
            res.append((OK, title + " installed (FloppaNet included, F2 in the game)"))
        else:
            res.append((TODO, title + " not installed yet (install it in the Floppa Launcher)"))

    clash = f2_conflict()
    if clash:
        res.append((TODO, "F2 is used by the desktop shortcut \"" + clash + "\" (FloppaNet opens with F2)"))
    else:
        res.append((OK, "F2 is free for FloppaNet"))

    res.append((OK, "Graphics driver for games found (Vulkan)") if has_vulkan()
               else (TODO, "No Vulkan graphics driver found (games may not start)"))
    return res, latest


def install_launcher(latest):
    lx = latest["linux"]
    url, want = str(lx["launcher_url"]), str(lx["launcher_sha256"]).lower()
    data = fetch(url)
    got = hashlib.sha256(data).hexdigest()
    if got != want:
        raise ValueError("the download does not match its checksum; nothing was installed")
    with zipfile.ZipFile(io.BytesIO(data)) as z:
        names = [n for n in z.namelist() if n.endswith(".x86_64") and "/" not in n and "\\" not in n]
        if len(names) != 1:
            raise ValueError("unexpected content in the launcher download")
        blob = z.read(names[0])
    LAUNCHER_DIR.mkdir(parents=True, exist_ok=True)
    tmp = LAUNCHER_DIR / "FloppaLauncher.x86_64.new"
    tmp.write_bytes(blob)
    tmp.chmod(0o755)
    os.replace(tmp, LAUNCHER_EXE)
    if not DESKTOP_ENTRY.is_file():   # the launcher rewrites this itself (with its own icon) when it runs
        DESKTOP_ENTRY.parent.mkdir(parents=True, exist_ok=True)
        icon = LAUNCHER_DATA / "launcher_icon.png"
        DESKTOP_ENTRY.write_text(
            "[Desktop Entry]\nType=Application\nName=Floppa Launcher\n"
            "Comment=Install, update and play the Floppa games\n"
            'Exec="%s"\nIcon=%s\nTerminal=false\nCategories=Game;\nStartupWMClass=Floppa Launcher\n'
            % (LAUNCHER_EXE, icon if icon.is_file() else "applications-games"))
        DESKTOP_ENTRY.chmod(0o755)
    return LAUNCHER_EXE


PIN_JS = r'''
var entry = "applications:floppa-launcher.desktop", done = 0;
var ps = panels();
for (var i = 0; i < ps.length; i++) {
    var ws = ps[i].widgets("org.kde.plasma.icontasks");
    for (var j = 0; j < ws.length; j++) {
        var w = ws[j];
        w.currentConfigGroup = ["General"];
        var cur = String(w.readConfig("launchers") || "");
        var list = cur ? cur.split(",") : [];
        if (list.indexOf(entry) < 0) { list.push(entry); w.writeConfig("launchers", list); w.reloadConfig(); }
        done++;
    }
}
print(done);
'''


def pin_to_taskbar(wait=0):
    """Adds the launcher to the taskbar. wait: seconds to keep trying while the desktop is still starting
    (right after login the taskbar may not be there yet)."""
    if not shutil.which("qdbus6"):
        return False
    deadline = time.monotonic() + wait
    while True:
        try:
            out = subprocess.run(["qdbus6", "org.kde.plasmashell", "/PlasmaShell",
                                  "org.kde.PlasmaShell.evaluateScript", PIN_JS],
                                 capture_output=True, text=True, timeout=20).stdout
            if re.sub(r"\D", "", out) not in ("", "0"):
                return True
        except Exception:
            pass
        if time.monotonic() >= deadline:
            return False
        time.sleep(3)


def open_launcher():
    exe = find_launcher()
    if exe:
        subprocess.Popen([str(exe)], cwd=str(exe.parent), start_new_session=True,
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return bool(exe)


def install_wine():
    """Opens a terminal that installs Wine with pacman, so the user sees the progress and types their own
    password. Returns False if no terminal program was found."""
    cmd = "sudo pacman -S --needed " + " ".join(WINE_PACKAGES) + "; echo; read -r -p 'Done. Press Enter to close.' _"
    if not shutil.which("konsole"):
        return False
    subprocess.Popen(["konsole", "-p", "tabtitle=Floppa Setup: Wine", "-e", "bash", "-c", cmd],
                     start_new_session=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return True


def available_actions(latest):
    """(key, label, ticked by default)"""
    acts = []
    have = find_launcher() is not None
    can = bool(latest) and isinstance(latest.get("linux"), dict) and latest["linux"].get("launcher_url")
    if not have and can:
        acts.append(("launcher", "Install the Floppa Launcher", True))
    if have or can:
        acts.append(("pin", "Pin the Floppa Launcher to the taskbar", not have))
        acts.append(("open", "Open the Floppa Launcher now (to install or play the games)", True))
    if latest and not shutil.which("wine") and shutil.which("pacman"):   # online and not installed yet
        acts.append(("wine", "Install Wine for Windows games (about 1 GB, asks for your password)", False))
    return acts


def do_actions(keys, latest, pin_wait=0):
    notes = []
    if "launcher" in keys:
        try:
            install_launcher(latest)
            notes.append("Floppa Launcher installed.")
        except Exception as e:
            notes.append("Floppa Launcher could not be installed: %s" % e)
            return notes
    if "pin" in keys:
        notes.append("Pinned to the taskbar." if pin_to_taskbar(pin_wait) else "Could not pin to the taskbar.")
    if "open" in keys:
        notes.append("Floppa Launcher opened." if open_launcher() else "Floppa Launcher is not installed.")
    if "wine" in keys:
        notes.append("Wine is being installed in the terminal window." if install_wine()
                     else "No terminal found. Install Wine with: sudo pacman -S " + " ".join(WINE_PACKAGES))
    return notes


def installer_choices():
    """What was ticked on the installer's "Floppa games" page, if this is the user the installer created:
    {"launcher": bool, "pin": bool, "wine": bool}. None otherwise (or without the file)."""
    try:
        text = INSTALLER_CHOICES.read_text(encoding="utf-8", errors="replace")
        me = pwd.getpwuid(os.getuid()).pw_name
    except (OSError, KeyError):
        return None
    vals = {}
    for line in text.splitlines():
        line = line.strip()
        if line and not line.startswith("#") and "=" in line:
            k, v = line.split("=", 1)
            vals[k.strip()] = v.strip().lower()
    if not vals.get("user") or vals["user"] != me.lower():
        return None
    launcher = vals.get("launcher") == "yes"
    return {"launcher": launcher, "pin": launcher and vals.get("pin") == "yes", "wine": vals.get("wine") == "yes"}


def choices_done():
    return CHOICES_DONE.is_file()


def mark_choices_done():
    try:
        CHOICES_DONE.parent.mkdir(parents=True, exist_ok=True)
        CHOICES_DONE.write_text("Floppa Setup %s did the installer's choices on %s\n"
                                % (VERSION, time.strftime("%Y-%m-%d %H:%M")))
    except OSError:
        pass


def as_text(results):
    return "\n".join("%s  %s" % (MARK[s], t) for s, t in results)


def kdialog(*args):
    p = subprocess.run(["kdialog", "--title", "Floppa Setup", *args], capture_output=True, text=True)
    return p.returncode, p.stdout


def kdialog_works():
    """kdialog is there and starts. One installed with pacman -S alone, newer than the rest of the system,
    stops at once with a library error ("version Qt_6.12 not found", seen on CachyOS 2026-11-22)."""
    if not shutil.which("kdialog"):
        return False
    try:
        return subprocess.run(["kdialog", "--version"], capture_output=True, timeout=20).returncode == 0
    except (OSError, subprocess.TimeoutExpired):
        return False


def notify(text):
    """Small desktop notification that does not wait for the user. notify-send (libnotify) shows it as
    "Floppa Setup" with the FloppaOS icon and returns at once; kdialog's pop-up is the fallback (on Plasma 6 it
    is labelled "kdialog" and its process stays until the notification is closed, seen in the VM 2026-11-21)."""
    if shutil.which("notify-send"):
        cmd = ["notify-send", "--app-name=Floppa Setup", "--icon=floppaos", "--expire-time=8000", "Floppa Setup", text]
    else:
        cmd = ["kdialog", "--title", "Floppa Setup", "--passivepopup", text, "8"]
    try:
        subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    except OSError:
        pass


def show(gui, text):
    if gui:
        kdialog("--msgbox", text)
    else:
        print(text)


def report(gui, keys, notes, intro=""):
    """The message after Floppa Setup has done something: what happened, then a fresh check."""
    head = (intro + "\n\n" if intro else "") + "\n".join(notes)
    if "open" in keys and find_launcher():
        # The launcher installs and updates the games itself; checking them this second would be too early.
        show(gui, head + "\n\nThe Floppa Launcher now installs or updates the games. Press PLAY there when it is "
                         "ready.\nOpen Floppa Setup from the start menu any time to check again.")
    else:
        show(gui, head + "\n\n" + as_text(run_checks()[0]))


def apply_installer_choices(ch, gui):
    """First login after the FloppaOS installer: do once what was ticked on its "Floppa games" page.
    When the Floppa servers cannot be reached, nothing is marked as done, so it tries again next login."""
    if not any(ch.values()):
        mark_choices_done()
        return 0
    if gui:
        notify("Setting up what you chose in the FloppaOS installer …")
    results, latest = run_checks()
    if ch["launcher"] and not latest:
        show(gui, "Floppa Setup could not reach the Floppa servers, so it cannot set up what you chose in the "
                  "installer yet. It tries again the next time you log in. Or open Floppa Setup from the start "
                  "menu once this PC is online.\n\n" + as_text(results))
        return 0
    keys = []
    can = bool(latest) and isinstance(latest.get("linux"), dict) and latest["linux"].get("launcher_url")
    if ch["launcher"]:
        if find_launcher() is None and can:
            keys.append("launcher")
        if find_launcher() is not None or "launcher" in keys:
            if ch["pin"]:
                keys.append("pin")
            keys.append("open")
    if ch["wine"] and not shutil.which("wine") and shutil.which("pacman"):
        keys.append("wine")
    notes = do_actions(keys, latest, pin_wait=90) if keys else []
    mark_choices_done()
    if keys:
        report(gui, keys, notes, "Floppa Setup did what you chose in the FloppaOS installer:")
    else:
        show(gui, as_text(results))
    return 0


def main():
    global SITE
    ap = argparse.ArgumentParser(description="Checks and sets up the Floppa Launcher, the games and FloppaNet.")
    ap.add_argument("--check", action="store_true", help="only print the checklist in the terminal")
    ap.add_argument("--yes", action="store_true", help="terminal mode: do the default actions without asking")
    ap.add_argument("--first-run", action="store_true", help="login mode: stay silent once the launcher is installed")
    ap.add_argument("--site", help="other website to read the manifests from (for tests)")
    a = ap.parse_args()
    if a.site:
        SITE = a.site.rstrip("/")

    want_gui = bool(not a.check and not a.yes and (os.environ.get("WAYLAND_DISPLAY") or os.environ.get("DISPLAY")))
    if a.first_run:
        ch = installer_choices()
        if ch is not None and not choices_done():
            return apply_installer_choices(ch, want_gui and kdialog_works())
        if ch is not None and not ch["launcher"]:
            return 0   # no launcher wanted in the installer: stay quiet at login (the start menu still has it)
        if find_launcher():
            return 0

    gui = want_gui and kdialog_works()   # only now: a quiet login does not start kdialog at all
    if want_gui and not gui and not sys.stdout.isatty():
        # Started from the start menu or at login, but no kdialog for the window (the CachyOS live system has
        # none, seen in the VM 2026-11-22): say how to get it instead of doing nothing.
        notify(NEEDS_KDIALOG)
        return 0

    results, latest = run_checks()
    acts = available_actions(latest)

    if not gui:
        print("Floppa Setup " + VERSION + "\n" + as_text(results))
        if want_gui:
            print(NEEDS_KDIALOG)
        if a.yes:
            for n in do_actions([k for k, _, on in acts if on and k != "open"], latest):
                print(n)
            print(as_text(run_checks()[0]))
        return 0 if all(s in (OK, INFO) for s, _ in results) else 1

    text = as_text(results)
    if not acts:
        kdialog("--msgbox", text)
        return 0
    args = ["--separate-output", "--checklist", text + "\n\nTick what Floppa Setup should do:"]
    for k, label, on in acts:
        args += [k, label, "on" if on else "off"]
    code, out = kdialog(*args)
    keys = [k for k in out.split() if k]
    if code != 0 or not keys:
        return 0
    report(gui, keys, do_actions(keys, latest))
    return 0


if __name__ == "__main__":
    sys.exit(main())
