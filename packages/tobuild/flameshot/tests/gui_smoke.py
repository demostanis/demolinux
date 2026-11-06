"""Run with: dbus-run-session -- python3 gui_smoke.py /path/to/flameshot.

Uses its own Xvfb; never sends input to the user's desktop.
Requires Xvfb, xdotool, xsetroot, and Pillow.
"""

import json
import os
import shutil
from pathlib import Path
import subprocess
import sys
import tempfile
import time

from PIL import Image


def wait_until(predicate, seconds=5):
    deadline = time.monotonic() + seconds
    while time.monotonic() < deadline:
        if predicate():
            return
        time.sleep(0.05)
    raise AssertionError("Timed out waiting for GUI test condition")


binary = str(Path(sys.argv[1]).resolve())
headless = os.environ.copy()
for key in ("DISPLAY", "WAYLAND_DISPLAY"):
    headless.pop(key, None)
headless.update(
    DBUS_SESSION_BUS_ADDRESS="unix:path=/nonexistent", QT_QPA_PLATFORM="invalid"
)
probe = subprocess.run(
    [binary, "--external-actions-version"], env=headless, capture_output=True, timeout=3
)
assert (probe.returncode, probe.stdout, probe.stderr) == (0, b"1", b""), probe

with tempfile.TemporaryDirectory(prefix="flameshot-gui-test-") as scratch:
    root = Path(scratch)
    read_fd, write_fd = os.pipe()
    xvfb = subprocess.Popen(
        [
            "Xvfb",
            "-displayfd",
            str(write_fd),
            "-screen",
            "0",
            "1024x768x24",
            "-nolisten",
            "tcp",
        ],
        pass_fds=(write_fd,),
    )
    os.close(write_fd)
    with os.fdopen(read_fd) as display:
        number = display.readline().strip()
    env = os.environ.copy()
    env.update(
        DISPLAY=f":{number}",
        XDG_CONFIG_HOME=str(root / "config"),
        QT_QPA_PLATFORM="xcb",
    )
    env.pop("WAYLAND_DISPLAY", None)
    actions = root / "config/flameshot/actions.d"
    actions.mkdir(parents=True)
    (actions.parent / "flameshot.ini").write_text(
        "[General]\nshowHelp=false\ncheckForUpdates=false\nbuttons=\ndrawColor=#ff0000\n"
    )
    helper = Path(__file__).with_name("helper.py").resolve()
    for name, mode, shortcut, args in (
        ("a-fail", "fail", "Ctrl+Shift+F", [str(root / "failed.txt")]),
        (
            "b-send",
            "receive",
            "Ctrl+Shift+T",
            [str(root / "capture.png"), str(root / "args.json")],
        ),
        ("c-sleep", "sleep", "Ctrl+Shift+L", [str(root / "pid")]),
    ):
        (actions / f"{name}.json").write_text(
            json.dumps(
                {
                    "name": name,
                    "program": "/usr/bin/python3",
                    "arguments": [str(helper), mode] + args,
                    "shortcut": shortcut,
                    "icon": "video-display",
                    "timeout": 60000,
                }
            )
        )

    def command(*args):
        return (
            subprocess.run(args, env=env, check=True, capture_output=True)
            .stdout.decode()
            .strip()
        )

    def key(sequence):
        command("xdotool", "key", "--clearmodifiers", sequence)
        time.sleep(0.15)

    def drag(x1, y1, x2, y2):
        command("xdotool", "mousemove", str(x1), str(y1), "mousedown", "1")
        time.sleep(0.1)
        command("xdotool", "mousemove", str(x1 + 1), str(y1 + 1))
        time.sleep(0.1)
        command("xdotool", "mousemove", str(x2), str(y2))
        time.sleep(0.1)
        command("xdotool", "mouseup", "1")
        time.sleep(0.2)

    process = None
    daemon = None
    try:
        command("xsetroot", "-solid", "#224466")
        # The daemon hosts the capture; the CLI waits for its completion.
        daemon = subprocess.Popen(
            [binary], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL
        )
        time.sleep(0.5)
        log = (root / "gui.log").open("wb")
        process = subprocess.Popen([binary, "gui"], env=env, stdout=log, stderr=log)
        window = []

        def find_window():
            result = subprocess.run(
                ["xdotool", "search", "--onlyvisible", "--class", "flameshot"],
                env=env,
                capture_output=True,
            )
            window[:] = result.stdout.decode().splitlines()
            return bool(window)

        wait_until(find_window)
        command("xdotool", "windowfocus", window[-1])
        # No automatic execution, including with no area selected.
        time.sleep(0.2)
        assert not (root / "capture.png").exists()
        key("ctrl+shift+t")
        assert not (root / "capture.png").exists()
        # Start under the validation status: it must not swallow canvas input.
        drag(100, 55, 500, 355)
        subprocess.run(
            ["import", "-window", "root", str(root / "after-selection.png")], env=env
        )
        key("p")
        drag(300, 250, 500, 400)
        key("ctrl+shift+f")
        wait_until(lambda: (root / "failed.txt").exists())
        time.sleep(0.2)
        assert process.poll() is None, "Nonzero script exit closed the capture"
        assert find_window(), "Capture disappeared on script failure"
        # Test the visible menu with an entirely customized/empty normal toolbar.
        command("xdotool", "mousemove", "55", "25", "click", "1")
        time.sleep(0.2)
        subprocess.run(["import", "-window", "root", str(root / "menu.png")], env=env)
        command("xdotool", "mousemove", "90", "92", "click", "1")
        wait_until(lambda: (root / "capture.png").exists())
        assert process.wait(timeout=5) == 0, (root / "gui.log").read_text()
        image = Image.open(root / "capture.png").convert("RGB")
        assert image.size in ((400, 300), (401, 301)), image.size
        assert any(
            r > 200 and g < 100 and b < 100
            for _, (r, g, b) in image.getcolors(image.width * image.height)
        ), "Annotation missing from stdin PNG"
        assert json.loads((root / "args.json").read_text()) == []
        (root / "capture.png").unlink()
        process = subprocess.Popen([binary, "gui"], env=env, stdout=log, stderr=log)
        wait_until(find_window)
        command("xdotool", "windowfocus", window[-1])
        drag(250, 200, 650, 500)
        key("ctrl+shift+t")
        wait_until(lambda: (root / "capture.png").exists())
        assert process.wait(timeout=5) == 0
        process = subprocess.Popen([binary, "gui"], env=env, stdout=log, stderr=log)
        wait_until(find_window)
        command("xdotool", "windowfocus", window[-1])
        drag(250, 200, 650, 500)
        key("ctrl+shift+l")
        wait_until(lambda: (root / "pid").exists())
        pid = int((root / "pid").read_text())
        command("xdotool", "mousemove", "55", "25", "click", "1")
        time.sleep(0.2)
        command("xdotool", "mousemove", "100", "160", "click", "1")

        def child_gone():
            try:
                os.kill(pid, 0)
                return False
            except ProcessLookupError:
                return True

        wait_until(child_gone)
        assert process.poll() is None, "Menu cancellation closed capture"
        (root / "pid").unlink()
        key("ctrl+shift+l")
        wait_until(lambda: (root / "pid").exists())
        pid = int((root / "pid").read_text())
        key("Escape")
        # Upstream's DBus GUI client may return 0 even for an aborted capture.
        assert process.wait(timeout=5) in (0, 1)
        wait_until(child_gone)
        time.sleep(0.1)
        assert daemon.poll() is None, "Daemon died after capture cancellation"
        print(
            "PASS: headless probe; no implicit execution; selected annotated PNG; failure stays open; menu and shortcut success close; customized toolbar; menu cancellation; capture close reaps child"
        )
    except Exception:
        subprocess.run(
            ["import", "-window", "root", str(root / "failure.png")], env=env
        )
        print("GUI log:", (root / "gui.log").read_text())
        print("Window tree:", command("xwininfo", "-root", "-tree"))
        shutil.copytree(root, scratch + "-failed")
        print("Failure artifacts:", scratch + "-failed")
        raise
    finally:
        for child in (process, daemon, xvfb):
            if child is not None and child.poll() is None:
                child.terminate()
                try:
                    child.wait(timeout=3)
                except subprocess.TimeoutExpired:
                    child.kill()
                    child.wait()
