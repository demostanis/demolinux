#!/usr/bin/env python3
"""Capture a failed guest even when SSH is unavailable."""

import json
import os
from pathlib import Path
import socket
import sys


def capture(destination, port):
    with socket.create_connection(("127.0.0.1", port), timeout=2) as sock:
        stream = sock.makefile("rwb", buffering=0)
        json.loads(stream.readline())
        for request in (
            {"execute": "qmp_capabilities"},
            {
                "execute": "screendump",
                "arguments": {
                    "filename": str(Path(destination).resolve()),
                    "format": "png",
                },
            },
        ):
            stream.write(json.dumps(request).encode() + b"\n")
            while True:
                line = stream.readline()
                if not line:
                    raise RuntimeError("QMP connection closed")
                reply = json.loads(line)
                if "error" in reply:
                    raise RuntimeError(reply["error"])
                if "return" in reply:
                    break


if __name__ == "__main__":
    try:
        capture(sys.argv[1], int(os.environ.get("DEMOLINUX_QMP_PORT", "4444")))
    except (OSError, RuntimeError, ValueError) as error:
        sys.exit(f"Could not capture VM screen: {error}")
