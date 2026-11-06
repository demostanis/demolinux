import json
import os
import pathlib
import sys
import time

mode = sys.argv[1]
if mode == "receive":
    pathlib.Path(sys.argv[2]).write_bytes(sys.stdin.buffer.read())
    pathlib.Path(sys.argv[3]).write_text(json.dumps(sys.argv[4:]))
elif mode == "flood":
    sys.stdin.buffer.read()
    for _ in range(128):
        os.write(1, b"x" * 65536)
        os.write(2, b"y" * 65536)
elif mode == "fail":
    sys.stdin.buffer.read()
    if len(sys.argv) > 2:
        pathlib.Path(sys.argv[2]).write_text("failed")
    sys.exit(7)
elif mode == "crash":
    os.abort()
elif mode == "sleep":
    pathlib.Path(sys.argv[2]).write_text(str(os.getpid()))
    time.sleep(30)
