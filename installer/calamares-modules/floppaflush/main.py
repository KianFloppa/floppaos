#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-3.0-or-later
"""FloppaOS installer step "floppaflush": write everything to the disk before Calamares unmounts it.

Calamares gives each unmount 10 seconds (umount module, not configurable). Unmounting ext4 checkpoints its
journal: the metadata of the ~8 GB just copied is written from the journal to its final place. On a slow disk
that takes longer than 10 seconds, and the installer says "Installation failed: Could not unmount the root of
the target system" although everything was written (QEMU without hardware acceleration, 2026-11-22: "Process
umount timed out after 10000 ms", right after a sync). sync only commits the journal; freezing the file system
(fsfreeze) writes it out completely, so the unmount that follows has nothing left to do.

Runs right before the umount step, on every real file system mounted at or below the new system's root. It
never stops the installation: a file system that cannot be frozen (FAT, for example) is skipped, and every
freeze is undone at once.
"""
import os
import subprocess

import libcalamares

# Not disks (proc, tmpfs ...), or without a journal to write out and often not freezable (FAT): skipped
SKIP = {"proc", "sysfs", "devtmpfs", "devpts", "tmpfs", "efivarfs", "securityfs", "cgroup", "cgroup2",
           "pstore", "bpf", "debugfs", "tracefs", "configfs", "fusectl", "mqueue", "hugetlbfs", "binfmt_misc",
           "autofs", "rpc_pipefs", "nsfs", "ramfs", "overlay", "squashfs", "iso9660", "vfat", "msdos", "exfat"}


def pretty_name():
    return "Writing everything to the disk"


def _unescape(path):
    # /proc/self/mountinfo writes space, tab, newline and backslash as \040, \011, \012, \134
    return (path.replace("\\040", " ").replace("\\011", "\t").replace("\\012", "\n").replace("\\134", "\\"))


def mount_points(root, mountinfo="/proc/self/mountinfo"):
    """Real file systems mounted at root or below it, in mount order."""
    root = os.path.normpath(root)
    found = []
    try:
        with open(mountinfo, encoding="utf-8", errors="replace") as f:
            for line in f:
                left, _, right = line.partition(" - ")
                fields = left.split()
                if len(fields) < 5 or not right:
                    continue
                point = os.path.normpath(_unescape(fields[4]))
                fstype = right.split()[0]
                if fstype in SKIP:
                    continue
                if (point == root or point.startswith(root + "/")) and point not in found:
                    found.append(point)
    except OSError:
        pass
    return found


def _quiet(cmd, timeout):
    try:
        return subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, timeout=timeout).returncode
    except (OSError, subprocess.TimeoutExpired) as e:
        libcalamares.utils.warning("floppaflush: {}: {}".format(" ".join(cmd), e))
        return -1


def run():
    root = libcalamares.globalstorage.value("rootMountPoint")
    if not root or not os.path.isdir(root):
        return None
    _quiet(["sync"], 1800)
    for point in mount_points(root):
        frozen = -1
        try:
            frozen = _quiet(["fsfreeze", "--freeze", point], 1800)
        finally:
            # Always thaw, also after a timeout; thawing a file system that is not frozen does nothing
            _quiet(["fsfreeze", "--unfreeze", point], 120)
        libcalamares.utils.debug("floppaflush: " + point + (" written out" if frozen == 0 else " not frozen, skipped"))
    return None
