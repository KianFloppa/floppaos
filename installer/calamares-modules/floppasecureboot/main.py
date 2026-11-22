#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""FloppaOS installer step "floppasecureboot": Secure Boot support, if the "Secure Boot" page's box is ticked.

The page (/etc/calamares/branding/floppaos/secure-boot.qml) stores "floppaos_secureboot" = {"enabled": bool,
"code": "8 digits"} in GlobalStorage. When enabled, this step runs `floppaos-secureboot setup --code-file FILE`
in the new system (package floppaos-secureboot, secureboot/): a key for this PC, GRUB and the kernels signed
with it, the Microsoft-signed shim in front of GRUB, and a request to confirm the key with the code on the blue
screen at the next start. It runs after the boot loader step, so GRUB is already installed.

This step never stops the installation: if the setup fails, FloppaOS still starts with Secure Boot off (the
plain GRUB from the boot loader step stays usable) and the log says why; `sudo floppaos-secureboot setup` can be
run later. The code is passed in a root-only file that is deleted right after, and is never written to the log.
"""
import os
import re
import subprocess

import libcalamares

CODE = re.compile(r"[0-9]{8}")
CODE_FILE = "root/.floppaos-secureboot-code"


def pretty_name():
    return "Setting up Secure Boot"


def _yes(value):
    return value is True or str(value).strip().lower() in ("true", "yes", "1")


def wanted(choice):
    """(enabled, code) from what the page stored; enabled only with a valid code."""
    if not isinstance(choice, dict) or not _yes(choice.get("enabled", False)):
        return False, ""
    code = str(choice.get("code", "")).strip()
    return bool(CODE.fullmatch(code)), code


def _run():
    gs = libcalamares.globalstorage
    choice = gs.value("floppaos_secureboot") if gs.contains("floppaos_secureboot") else None
    enabled, code = wanted(choice)
    if not enabled:
        if isinstance(choice, dict) and _yes(choice.get("enabled", False)):
            libcalamares.utils.warning("floppasecureboot: the page stored no valid code, Secure Boot not set up")
        return None
    root = gs.value("rootMountPoint") if gs.contains("rootMountPoint") else None
    if not root or not os.path.isdir(root):
        libcalamares.utils.warning("floppasecureboot: no target system mounted, Secure Boot not set up")
        return None
    path = os.path.join(root, CODE_FILE)
    try:
        fd = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
        with os.fdopen(fd, "w") as f:
            f.write(code + "\n")
        lines = []
        try:
            # Returns 0, or raises CalledProcessError with the output; the lines also go to the callback list.
            libcalamares.utils.target_env_process_output(
                ["floppaos-secureboot", "setup", "--code-file", "/" + CODE_FILE], lines)
            libcalamares.utils.debug("floppasecureboot: %s" % " | ".join(lines).replace(code, "********"))
        except subprocess.CalledProcessError as e:
            text = e.output if isinstance(e.output, str) else " | ".join(lines)
            libcalamares.utils.warning("floppasecureboot: setup failed (exit %s): %s"
                                       % (e.returncode, text.replace(code, "********")))
    except OSError as e:
        libcalamares.utils.warning("floppasecureboot: %s" % e)
    finally:
        try:
            os.remove(path)
        except OSError:
            pass
    return None


def run():
    """The step, then everything written to the disk. Calamares gives the final unmount only 10 seconds; in a
    slow VM the freshly built and signed GRUB was still being written then ("could not unmount the root of the
    target system", 2026-11-22). This is the last step before the unmount that changes the installed system."""
    try:
        return _run()
    finally:
        try:
            subprocess.run(["sync"], timeout=600)
        except (OSError, subprocess.TimeoutExpired):
            pass
