#!/usr/bin/env python3
"""Overlay Acer Android 6 MT8163 blobs onto a CM/Lineage 13 system tree."""

from __future__ import annotations

import argparse
import os
import re
import shutil
import stat
import subprocess
from collections import deque
from pathlib import Path


SERVICE_RE = re.compile(r"/system/(?:bin|xbin)/([A-Za-z0-9_.+-]+)")
NEEDED_RE = re.compile(r"Shared library: \[([^]]+)\]")


def copy_file(src: Path, dst: Path, overwrite: bool = False) -> bool:
    # Path.exists() is false for a broken symlink.  Android system trees use
    # many relative symlinks, so use lexists to avoid copying through one.
    if os.path.lexists(dst) and not overwrite:
        return False
    if overwrite and os.path.lexists(dst):
        if dst.is_dir() and not dst.is_symlink():
            shutil.rmtree(dst)
        else:
            dst.unlink()
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, dst, follow_symlinks=False)
    return True


def copy_tree(src: Path, dst: Path, overwrite: bool = True) -> None:
    if not src.exists():
        return
    shutil.copytree(src, dst, dirs_exist_ok=True, symlinks=True)


def elf_class(path: Path) -> int | None:
    try:
        data = path.read_bytes()[:5]
    except OSError:
        return None
    if data[:4] != b"\x7fELF":
        return None
    return {1: 32, 2: 64}.get(data[4])


def needed(path: Path) -> list[str]:
    try:
        out = subprocess.check_output(
            ["readelf", "-d", str(path)], stderr=subprocess.DEVNULL, text=True
        )
    except (OSError, subprocess.CalledProcessError):
        return []
    return NEEDED_RE.findall(out)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("stock", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--stock-ramdisk", type=Path, required=True)
    args = parser.parse_args()

    stock = args.stock.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=True)

    # Keep the proprietary vendor libraries and data built for this exact
    # MT8163 board.  Acer's vendor/operator and vendor/overlay directories are
    # preinstalled applications and branding, not hardware support.
    for rel in ("vendor/lib", "vendor/lib64", "vendor/media", "vendor/pittpatt"):
        copy_tree(stock / rel, out / rel)

    for rel in (
        "etc/firmware",
        "etc/bluetooth",
        "etc/audio_param",
        "etc/wifi",
        "etc/.tp",
        "lib/egl",
        "lib/hw",
        "lib64/egl",
        "lib64/hw",
        "lib/modules",
        "usr/idc",
        "usr/keylayout",
    ):
        copy_tree(stock / rel, out / rel)

    for pattern in (
        "audio*.conf",
        "audio*.xml",
        "media_codecs*.xml",
        "media_profiles*.xml",
        "thermal*.conf",
        "mtk_omx_core.cfg",
        "agps_profiles_conf*.xml",
    ):
        for src in (stock / "etc").glob(pattern):
            copy_file(src, out / "etc" / src.name, overwrite=True)

    # Copy every binary referenced by Acer's board init scripts. Core Android
    # tools already produced by Lineage are retained unless listed below.
    names: set[str] = set()
    for rc in args.stock_ramdisk.glob("*.rc"):
        names.update(SERVICE_RE.findall(rc.read_text(errors="ignore")))
    force_bins = {
        "6620_launcher",
        "nvram_daemon",
        "thermal_manager",
        "wmt_loader",
        "wmt_launcher",
        "stp_dump3",
        "rpmb_svc",
        "ged_srv",
        "pq",
        "aal",
        "guiext-server",
    }
    copied_elfs: deque[Path] = deque()

    # Some MediaTek HAL components are loaded by name at runtime, so they are
    # invisible to DT_NEEDED discovery. Seed them explicitly and let the
    # dependency walker copy their private dependencies.
    for libdir, names_to_copy in (
        (
            "lib",
            (
                "libbt-vendor.so",
                "libbtcusttable.so",
                "libcam_platform.so",
            ),
        ),
        ("lib64", ("libbtcusttable.so", "libcam_platform.so")),
    ):
        for name in names_to_copy:
            src = stock / libdir / name
            if not src.is_file():
                continue
            dst = out / libdir / name
            copy_file(src, dst, overwrite=True)
            copied_elfs.append(dst)

    for subdir in ("bin", "xbin"):
        for name in sorted(names):
            src = stock / subdir / name
            if not src.is_file():
                continue
            dst = out / subdir / name
            if copy_file(src, dst, overwrite=name in force_bins):
                copied_elfs.append(dst)

    # Hardware modules must be the Acer versions even when AOSP produced a
    # generic file with the same destination name.
    for libdir in ("lib", "lib64"):
        # Acer's init.aee.rc globally exports this library through LD_PRELOAD.
        # It is therefore invisible to normal DT_NEEDED dependency discovery
        # but is mandatory for every dynamically linked process.
        preload = stock / libdir / "libdirect-coredump.so"
        if preload.is_file():
            copy_file(
                preload,
                out / libdir / preload.name,
                overwrite=True,
            )
            copied_elfs.append(out / libdir / preload.name)

        for src in (stock / libdir / "hw").glob("*.mt8163.so"):
            dst = out / libdir / "hw" / src.name
            copy_file(src, dst, overwrite=True)
            copied_elfs.append(dst)
        for src in (out / libdir / "egl").glob("*.so"):
            if elf_class(src):
                copied_elfs.append(src)
        for src in (out / libdir / "hw").glob("*.so"):
            if elf_class(src):
                copied_elfs.append(src)

    for src in (out / "vendor").rglob("*"):
        if src.is_file() and elf_class(src):
            copied_elfs.append(src)

    # Resolve proprietary DT_NEEDED dependencies recursively, while keeping
    # Lineage's bionic and framework libraries whenever they already exist.
    seen: set[Path] = set()
    unresolved: set[tuple[str, str]] = set()
    while copied_elfs:
        binary = copied_elfs.popleft()
        if binary in seen:
            continue
        seen.add(binary)
        bits = elf_class(binary)
        if bits is None:
            continue
        libdir = "lib64" if bits == 64 else "lib"
        for soname in needed(binary):
            destination = out / libdir / soname
            vendor_destination = out / "vendor" / libdir / soname
            if destination.exists() or vendor_destination.exists():
                continue
            candidates = (
                stock / libdir / soname,
                stock / "vendor" / libdir / soname,
            )
            source = next((p for p in candidates if p.is_file()), None)
            if source is None:
                unresolved.add((str(binary.relative_to(out)), soname))
                continue
            copy_file(source, destination)
            copied_elfs.append(destination)

    # Preserve executable bits after copying through drvfs.
    for directory in (out / "bin", out / "xbin", out / "vendor" / "bin"):
        if not directory.exists():
            continue
        for path in directory.iterdir():
            if path.is_file():
                path.chmod(path.stat().st_mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)

    marker = out / "etc" / "b1-780-lineage13-blobs.txt"
    marker.write_text("Acer B1-780 Android 6 proprietary blobs overlaid\n")
    print(f"Overlay complete: {len(seen)} ELF files inspected")
    if unresolved:
        print("Unresolved proprietary dependencies:")
        for binary, soname in sorted(unresolved):
            print(f"  {binary}: {soname}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

