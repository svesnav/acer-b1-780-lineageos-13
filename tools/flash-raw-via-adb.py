#!/usr/bin/env python3
"""Stream a raw partition image through adb exec-in without a temporary copy."""

from __future__ import annotations

import argparse
import hashlib
import subprocess
import sys
import time
from pathlib import Path


PARTITIONS = {
    "boot": "/dev/block/platform/mtk-msdc.0/11230000.MSDC0/by-name/boot",
    "system": "/dev/block/platform/mtk-msdc.0/11230000.MSDC0/by-name/system",
}


def adb(adb_path: Path, serial: str, *args: str, check: bool = True) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [str(adb_path), "-s", serial, *args],
        check=check,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("image", type=Path)
    parser.add_argument("partition", choices=sorted(PARTITIONS))
    parser.add_argument("--serial", default="0123456789ABCDEF")
    parser.add_argument(
        "--adb",
        type=Path,
        default=Path(__file__).resolve().parent / "platform-tools" / "adb.exe",
    )
    args = parser.parse_args()

    image = args.image.resolve()
    if not image.is_file():
        parser.error(f"image does not exist: {image}")
    adb_path = args.adb.resolve()
    if not adb_path.is_file():
        parser.error(f"adb does not exist: {adb_path}")

    state = adb(adb_path, args.serial, "get-state").stdout.strip()
    if state not in {"device", "recovery"}:
        raise SystemExit(f"ADB device {args.serial} is not ready: {state!r}")

    # The recovery test prevents an accidental write while normal Android is
    # running and has /system mounted.
    recovery = adb(
        adb_path,
        args.serial,
        "shell",
        "test -x /sbin/recovery || test -x /sbin/twrp; echo $?",
    ).stdout.strip().splitlines()[-1]
    if recovery != "0":
        raise SystemExit("refusing to flash: the device is not in recovery")

    block = PARTITIONS[args.partition]
    size_text = adb(
        adb_path,
        args.serial,
        "shell",
        f"blockdev --getsize64 {block} 2>/dev/null || busybox blockdev --getsize64 {block}",
    ).stdout.strip().splitlines()[-1]
    partition_size = int(size_text)
    image_size = image.stat().st_size
    if image_size > partition_size:
        raise SystemExit(
            f"image is too large: {image_size:,} bytes > {partition_size:,} bytes"
        )
    if args.partition == "system" and image_size != partition_size:
        raise SystemExit(
            f"raw system image must fill the partition: {image_size:,} != {partition_size:,}"
        )

    command = [
        str(adb_path),
        "-s",
        args.serial,
        "exec-in",
        "dd",
        f"of={block}",
        "bs=4M",
        "conv=fsync",
    ]
    process = subprocess.Popen(
        command,
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
    )
    assert process.stdin is not None
    digest = hashlib.sha256()
    sent = 0
    started = time.monotonic()
    with image.open("rb") as source:
        while chunk := source.read(4 * 1024 * 1024):
            process.stdin.write(chunk)
            digest.update(chunk)
            sent += len(chunk)
            elapsed = max(time.monotonic() - started, 0.001)
            print(
                f"\r{sent / image_size:6.1%}  {sent / 2**20:,.0f}/{image_size / 2**20:,.0f} MiB"
                f"  {sent / 2**20 / elapsed:,.1f} MiB/s",
                end="",
                flush=True,
            )
    process.stdin.close()
    stdout = process.stdout.read() if process.stdout else b""
    stderr = process.stderr.read() if process.stderr else b""
    result = process.wait()
    print()
    if stdout:
        print(stdout.decode(errors="replace").strip())
    if stderr:
        print(stderr.decode(errors="replace").strip(), file=sys.stderr)
    if result:
        raise SystemExit(f"adb/dd failed with exit code {result}")
    print(f"source SHA-256: {digest.hexdigest()}")
    print(f"flashed {args.partition}: {image_size:,} bytes")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
