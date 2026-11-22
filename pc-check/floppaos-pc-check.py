#!/usr/bin/env python3
"""FloppaOS PC check: what works on this PC, as one text file to send along with a problem report.

Read-only: it changes nothing on the PC. It leaves out serial numbers, network addresses, disk IDs and user
files. Made for trying FloppaOS on a real PC from the USB stick (graphics, screens, sound, Wi-Fi, Bluetooth,
controllers), and useful later for any problem report.

  floppaos-pc-check            writes ~/floppaos-pc-check.txt and opens it
  floppaos-pc-check --print    prints the report instead
"""
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

VERSION = "0.1"
OUT = Path.home() / "floppaos-pc-check.txt"
OK, NO, INFO = "✔", "✘", "•"
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
MAC = re.compile(r"\b(?:[0-9A-Fa-f]{2}[:-]){5}[0-9A-Fa-f]{2}\b")
UUID = re.compile(r"\b[0-9A-Fa-f]{8}-(?:[0-9A-Fa-f]{4}-){3}[0-9A-Fa-f]{12}\b")
SB_VAR = Path("/sys/firmware/efi/efivars/SecureBoot-8be4df61-93ca-11d2-aa0d-00e098032b8c")


def clean(text):
    """No colour codes, no network hardware addresses, no disk or partition IDs."""
    text = ANSI.sub("", text)
    text = MAC.sub("xx:xx:xx:xx:xx:xx", text)
    return UUID.sub("(id)", text)


def run(*args, timeout=20, sudo=False):
    """Output of a command, '' when it is missing, fails or hangs. sudo: try again with sudo -n (no password
    question; works on the live system, elsewhere it just fails quietly)."""
    if not shutil.which(args[0]):
        return ""
    env = dict(os.environ, LC_ALL="C.UTF-8")
    tries = [list(args)] + ([["sudo", "-n", *args]] if sudo and shutil.which("sudo") else [])
    for cmd in tries:
        try:
            p = subprocess.run(cmd, capture_output=True, encoding="utf-8", errors="replace", timeout=timeout,
                               env=env, stdin=subprocess.DEVNULL)
        except (OSError, subprocess.TimeoutExpired):
            continue
        if p.returncode == 0 and p.stdout.strip():
            return clean(p.stdout)
    return ""


def read(path):
    try:
        return Path(path).read_text(errors="replace").strip()
    except OSError:
        return ""


def lspci_blocks():
    """lspci -nnk as (device line, kernel driver in use)."""
    blocks, cur = [], None
    for line in run("lspci", "-nnk").splitlines():
        if line and not line[0].isspace():
            cur = [line.strip(), ""]
            blocks.append(cur)
        elif cur and "Kernel driver in use:" in line:
            cur[1] = line.split(":", 1)[1].strip()
    return blocks


def pci_name(line):
    """'03:00.0 VGA compatible controller [0300]: AMD ... [1002:7590] (rev c0)' -> 'AMD ... [1002:7590]'."""
    name = line.split(": ", 1)[-1]
    return re.sub(r"\s*\(rev [0-9a-f]+\)$", "", name)


def secure_boot():
    out = run("mokutil", "--sb-state")
    if "enabled" in out.lower():
        return "on"
    if "disabled" in out.lower():
        return "off"
    try:
        return "on" if SB_VAR.read_bytes()[-1:] == b"\x01" else "off"
    except FileNotFoundError:
        return "off" if SB_VAR.parent.is_dir() else "unknown"   # the firmware has no Secure Boot setting at all
    except OSError:
        return "unknown"


def displays():
    """[(name, text)] from kscreen-doctor: current mode, highest refresh rate at that size, VRR and HDR."""
    raw = run("kscreen-doctor", "-o", timeout=90)
    found = []
    for block in re.split(r"(?=Output: )", raw):
        if not block.startswith("Output: "):
            continue
        flat = " ".join(block.split())
        parts = flat.split()
        name = parts[2] if len(parts) > 2 else "?"
        if " connected" not in " " + flat or "disconnected" in flat:
            continue
        modes = re.findall(r"\d+:(\d+x\d+)@([\d.]+)(\*?)", flat)
        cur = next(((size, hz) for size, hz, star in modes if star), None)
        bits = []
        if cur:
            best = max(float(hz) for size, hz, _ in modes if size == cur[0])
            bits.append("%s at %s Hz now (up to %s Hz)" % (cur[0], round(float(cur[1])), round(best)))
        for key in ("Vrr", "HDR"):
            m = re.search(key + r": (\w+)", flat)
            if m:
                bits.append("%s: %s" % ("VRR" if key == "Vrr" else key, m.group(1)))
        if "disabled" in parts[:6]:
            bits.append("switched off")
        found.append((name, ", ".join(bits) or "connected"))
    return found


def kernel_errors():
    out = run("journalctl", "-k", "-b", "-p", "err", "--no-pager", "-q", "-o", "cat", sudo=True)
    return [line for line in out.splitlines() if line.strip()]


def main():
    print_only = "--print" in sys.argv[1:]
    if not print_only and (os.environ.get("WAYLAND_DISPLAY") or os.environ.get("DISPLAY")) and shutil.which("notify-send"):
        subprocess.Popen(["notify-send", "--app-name=FloppaOS PC check", "--icon=floppaos", "--expire-time=6000",
                          "FloppaOS PC check", "Checking this PC (about 20 seconds)..."],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)

    summary, details = [], []

    def section(title, body):
        details.append("\n== " + title)
        details.append(body.rstrip() if body.strip() else "(nothing found)")

    osr = dict(re.findall(r'^(\w+)="?([^"\n]*)"?$', read("/etc/os-release"), re.M))
    live = Path("/run/archiso").exists()
    kernel = os.uname().release
    mesa = run("pacman", "-Q", "mesa").strip() or "?"
    summary.append((INFO, "%s%s, kernel %s, %s" % (osr.get("PRETTY_NAME", "Linux"), " (live from USB)" if live else "",
                                                   kernel, mesa)))
    uefi = Path("/sys/firmware/efi").exists()
    summary.append((INFO, "Started with UEFI, Secure Boot %s" % secure_boot() if uefi else "Started without UEFI (legacy BIOS)"))
    board = " ".join(x for x in (read("/sys/class/dmi/id/board_vendor"), read("/sys/class/dmi/id/board_name")) if x)
    bios = " ".join(x for x in (read("/sys/class/dmi/id/bios_version"), read("/sys/class/dmi/id/bios_date")) if x)
    cpu = next((l.split(":", 1)[1].strip() for l in read("/proc/cpuinfo").splitlines() if l.startswith("model name")), "?")
    mem = next((int(l.split()[1]) for l in read("/proc/meminfo").splitlines() if l.startswith("MemTotal:")), 0)
    summary.append((INFO, "%s, %d threads, %.0f GB memory; mainboard %s, firmware %s" % (
        cpu, os.cpu_count() or 0, mem / 1024 / 1024, board or "?", bios or "?")))

    # Graphics: the kernel driver and Vulkan (what games use).
    pci = lspci_blocks()
    gpus = [b for b in pci if re.search(r"\[03(00|02|80)\]", b[0])]
    for line, drv in gpus:
        summary.append((OK if drv else NO, "Graphics %s: %s" % (pci_name(line), ("driver " + drv) if drv else "no driver in use")))
    if not gpus:
        summary.append((NO, "No graphics card found"))
    vk = run("vulkaninfo", "--summary", timeout=30)
    vk_names = re.findall(r"deviceName\s*=\s*(.+)", vk)
    real = [n.strip() for n in vk_names if "llvmpipe" not in n]
    summary.append((OK if real else NO, "Vulkan (games): " + (", ".join(real) if real else "no graphics card driver, only software")))

    shown = displays()
    for name, text in shown:
        summary.append((INFO, "Screen %s: %s" % (name, text)))
    if not shown:
        summary.append((INFO, "Screens: could not read (start this from the desktop)"))

    sinks = [l.split("\t")[1] for l in run("pactl", "list", "short", "sinks").splitlines() if "\t" in l]
    real_sinks = [s for s in sinks if "auto_null" not in s and "dummy" not in s.lower()]
    summary.append((OK if real_sinks else NO, "Sound outputs: %d (%s)" % (len(real_sinks), ", ".join(real_sinks)[:200]) if real_sinks
                    else "No sound output found"))

    nets = [l.split(":") for l in run("nmcli", "-t", "-f", "DEVICE,TYPE,STATE", "device").splitlines()]
    wifi_pci = [(pci_name(l), d) for l, d in pci if "[0280]" in l]
    wifi_dev = [n for n in nets if len(n) >= 3 and n[1] == "wifi"]
    if wifi_dev:
        chip = ("; chip " + ", ".join("%s (driver %s)" % (n, d or "none") for n, d in wifi_pci)) if wifi_pci else ""
        summary.append((OK, "Wi-Fi: %s%s" % (", ".join("%s %s" % (n[0], n[2]) for n in wifi_dev), chip)))
    else:
        summary.append((NO if wifi_pci else INFO, "Wi-Fi: " + ("chip found but no Wi-Fi device: " + ", ".join(
            "%s (driver %s)" % (n, d or "none") for n, d in wifi_pci) if wifi_pci else "none found")))
    eth = [n for n in nets if len(n) >= 3 and n[1] == "ethernet"]
    if eth:
        summary.append((INFO, "Cable network: " + ", ".join("%s %s" % (n[0], n[2]) for n in eth)))

    hci = sorted(p.name for p in Path("/sys/class/bluetooth").glob("hci*")) if Path("/sys/class/bluetooth").exists() else []
    bt_drv = [os.path.basename(os.path.realpath("/sys/class/bluetooth/%s/device/driver" % h)) for h in hci]
    summary.append((OK if hci else INFO, "Bluetooth: " + (", ".join("%s (driver %s)" % (h, d) for h, d in zip(hci, bt_drv)) if hci
                                                          else "none found")))

    pads = [read(p) for p in sorted(Path("/sys/class/input").glob("js*/device/name"))]
    summary.append((INFO, "Game controllers: " + (", ".join(pads) if pads else "none plugged in")))

    errs = kernel_errors()
    gpu_errs = [e for e in errs if "amdgpu" in e or "drm" in e.lower()]
    summary.append((NO if gpu_errs else INFO, "Kernel errors since start: %d%s" % (
        len(errs), (", %d about graphics" % len(gpu_errs)) if gpu_errs else "")))

    section("Graphics (lspci)", "\n".join("%s\n    driver: %s" % (l, d or "none") for l, d in gpus))
    section("Vulkan", "\n".join(l.strip() for l in vk.splitlines()
                                if re.search(r"deviceName|driverName|driverInfo|apiVersion|conformanceVersion", l)))
    section("Screens (kscreen-doctor)", "\n".join("%s: %s" % s for s in shown))
    section("Sound (wpctl status)", run("wpctl", "status"))
    section("Network devices (nmcli)", "\n".join(":".join(n) for n in nets))
    section("Network chips (lspci)", "\n".join("%s\n    driver: %s" % (l, d or "none") for l, d in pci if "[02" in l))
    section("Radio switches (rfkill)", run("rfkill", "list"))
    section("USB devices (lsusb)", run("lsusb"))
    section("Game controllers", "\n".join(pads))
    section("Sleep modes (/sys/power/mem_sleep)", read("/sys/power/mem_sleep"))
    section("Disks (lsblk)", run("lsblk", "-o", "NAME,SIZE,TYPE,FSTYPE,PARTTYPENAME,MOUNTPOINTS"))
    section("Kernel errors since start (last 40)", "\n".join(errs[-40:]))
    section("All PCI devices", "\n".join(l for l, _ in pci))

    head = ["FloppaOS PC check %s, %s" % (VERSION, time.strftime("%Y-%m-%d %H:%M")),
            "Read-only: nothing on this PC was changed. No serial numbers or network addresses are in this file.", ""]
    text = "\n".join(head + ["%s  %s" % s for s in summary] + details) + "\n"

    if print_only:
        sys.stdout.buffer.write(text.encode("utf-8"))
        return 0
    OUT.write_text(text, encoding="utf-8")
    print("Written: %s" % OUT)
    if (os.environ.get("WAYLAND_DISPLAY") or os.environ.get("DISPLAY")) and shutil.which("xdg-open"):
        subprocess.Popen(["xdg-open", str(OUT)], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
