#!/usr/bin/env python3
"""Create the existing release chunks and checksums in a single streaming pass."""

import hashlib
from pathlib import Path
import sys
import time


def prepare_release(image, destination, chunk_size=2_000_000_000):
    image, destination = Path(image), Path(destination)
    size = image.stat().st_size
    if size == 0 or chunk_size <= 0:
        raise ValueError("Image and chunk size must be nonempty")
    if (size + chunk_size - 1) // chunk_size > 26 * 26:
        raise ValueError("Image needs more than 676 release chunks")

    whole_hash = hashlib.sha256()
    checksums = []
    part = None
    part_hash = hashlib.sha256()
    part_bytes = 0
    index = 0
    name = ""
    try:
        with image.open("rb") as source:
            while block := source.read(min(8 * 1024 * 1024, chunk_size - part_bytes)):
                if part is None:
                    suffix = chr(ord("a") + index // 26) + chr(ord("a") + index % 26)
                    name = f"demolinux-{suffix}"
                    part = (destination / name).open("xb")
                    part_hash = hashlib.sha256()
                part.write(block)
                whole_hash.update(block)
                part_hash.update(block)
                part_bytes += len(block)
                if part_bytes == chunk_size:
                    part.close()
                    part = None
                    checksums.append(f"{part_hash.hexdigest()}  {name}\n")
                    part_bytes = 0
                    index += 1
            if part is not None:
                checksums.append(f"{part_hash.hexdigest()}  {name}\n")
    finally:
        if part is not None:
            part.close()

    checksums.append(f"{whole_hash.hexdigest()}  {image}\n")
    (destination / "sha256sums.txt").write_text("".join(checksums))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit("usage: prepare-release.py IMAGE")
    started = time.monotonic()
    prepare_release(sys.argv[1], ".")
    print(
        f"Release chunks and SHA-256 checksums prepared in {time.monotonic() - started:.1f}s"
    )
