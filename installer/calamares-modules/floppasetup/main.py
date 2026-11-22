#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""FloppaOS installer step "floppasetup": saves the "Floppa games" page's tick boxes into the new system.

The page (/etc/calamares/branding/floppaos/floppa-games.qml) stores its choices in GlobalStorage as
"floppaos_setup" = {"launcher": bool, "pin": bool, "wine": bool}. This step writes them, together with the
new user's login name, to /etc/floppaos/setup-choices.conf on the new system. At that user's first login,
Floppa Setup (setup/floppa-setup.py) does what is set to yes, once. Nothing is downloaded here.

This step never stops the installation: if something is missing it logs a warning, and Floppa Setup then
simply asks at the first login, as it does without the installer.
"""
import os
import re

import libcalamares

CHOICES_FILE = "etc/floppaos/setup-choices.conf"
# The same rule as Calamares' users page uses for login names.
LOGIN_NAME = re.compile(r"[a-z_][a-z0-9_-]{0,30}\$?")
DEFAULTS = {"launcher": True, "pin": True, "wine": False}


def pretty_name():
    return "Saving the Floppa games choices"


def _yes(value):
    return value is True or str(value).strip().lower() in ("true", "yes", "1")


def choices_text(choices, user):
    """The file's content. choices: whatever the page stored (normally a dict), user: login name."""
    if not isinstance(choices, dict):
        choices = {}
    picked = {k: _yes(choices.get(k, d)) for k, d in DEFAULTS.items()}
    if not picked["launcher"]:
        picked["pin"] = False
    if not (isinstance(user, str) and LOGIN_NAME.fullmatch(user)):
        user = ""
    lines = [
        "# Written by the FloppaOS installer (page \"Floppa games\"). At the first login of this user, Floppa",
        "# Setup does once what is set to yes. To change things later, open Floppa Setup from the start menu.",
        "user=" + user,
    ]
    lines += ["%s=%s" % (k, "yes" if picked[k] else "no") for k in DEFAULTS]
    return "\n".join(lines) + "\n"


def run():
    gs = libcalamares.globalstorage
    root = gs.value("rootMountPoint") if gs.contains("rootMountPoint") else None
    if not root or not os.path.isdir(root):
        libcalamares.utils.warning("floppasetup: no target system mounted, choices not saved")
        return None
    choices = gs.value("floppaos_setup") if gs.contains("floppaos_setup") else None
    if not isinstance(choices, dict):
        libcalamares.utils.warning("floppasetup: the Floppa games page stored nothing, saving its defaults")
    user = gs.value("username") if gs.contains("username") else ""
    text = choices_text(choices, user)
    path = os.path.join(root, CHOICES_FILE)
    try:
        os.makedirs(os.path.dirname(path), mode=0o755, exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        os.chmod(path, 0o644)
    except OSError as e:
        libcalamares.utils.warning("floppasetup: could not write %s: %s" % (path, e))
        return None
    libcalamares.utils.debug("floppasetup: wrote /%s:\n%s" % (CHOICES_FILE, text))
    return None
