#!/usr/bin/env python3

import os
import subprocess
import sys
import time


def check_transfer(selection, target, payload, owner_env, reader_env):
    command = ["xclip", "-selection", selection, "-target", target]
    owner = subprocess.Popen(
        command + ["-in", "-quiet"],
        env=owner_env,
        stdin=subprocess.PIPE,
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
    )
    try:
        owner.stdin.write(payload)
        owner.stdin.close()
        time.sleep(0.1)
        for _ in range(3):
            result = subprocess.run(
                command + ["-out"], env=reader_env, capture_output=True, timeout=10
            )
            if result.returncode or result.stdout != payload:
                raise RuntimeError(
                    f"received {len(result.stdout)} of {len(payload)} bytes; "
                    f"reader: {result.stderr.decode(errors='replace').strip()}"
                )
    finally:
        if owner.poll() is None:
            owner.terminate()
        try:
            owner.wait(timeout=3)
        except subprocess.TimeoutExpired:
            owner.kill()
            owner.wait()
        errors = owner.stderr.read().decode(errors="replace")
        if "X Error" in errors:
            raise RuntimeError(errors)


def main():
    if len(sys.argv) != 2 or not os.environ.get("DISPLAY"):
        sys.exit("Usage: DISPLAY=:N python3 tests/xorg-clipboard.py UNTRUSTED_AUTH")
    trusted = dict(os.environ)
    untrusted = dict(trusted, XAUTHORITY=sys.argv[1])
    # Two MiB exceeds xclip 0.13's INCR threshold; NULs prevent text fallback.
    cases = (
        ("UTF8_STRING", "Clipboard: caf\u00e9\n".encode()),
        ("UTF8_STRING", "caf\u00e9\n".encode() * 400000),
        ("application/octet-stream", bytes(range(256)) * 8192),
    )
    for selection in ("primary", "clipboard"):
        for owner_name, owner_env in (("trusted", trusted), ("untrusted", untrusted)):
            for reader_name, reader_env in (
                ("trusted", trusted),
                ("untrusted", untrusted),
            ):
                for target, payload in cases:
                    label = (
                        f"{selection} {owner_name} -> {reader_name}, "
                        f"{target}, {len(payload)} bytes"
                    )
                    try:
                        check_transfer(
                            selection, target, payload, owner_env, reader_env
                        )
                    except (
                        RuntimeError,
                        subprocess.TimeoutExpired,
                        BrokenPipeError,
                    ) as error:
                        sys.exit(f"FAIL: {label}: {error}")
                    print(f"PASS: {label} (3 consecutive reads)", flush=True)


if __name__ == "__main__":
    main()
