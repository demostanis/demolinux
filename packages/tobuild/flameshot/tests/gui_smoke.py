"""Run with: dbus-run-session -- python3 gui_smoke.py /path/to/flameshot.

Uses its own Xvfb; never sends input to the user's desktop.
Requires Xvfb, xdotool, xsetroot, Pillow, a C++ compiler and Qt5Core pkg-config.
"""

import json
import os
import shlex
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
assert (probe.returncode, probe.stdout, probe.stderr) == (0, b"3", b""), probe

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
        "[General]\nshowHelp=false\ncheckForUpdates=false\nbuttons="
        + os.environ.get("FLAMESHOT_TEST_BUTTONS", "")
        + "\ndrawColor=#ff0000\nuiColor=#c00090\n"
    )
    # Use the same custom Qt metatype serialization as Flameshot, not a string
    # pretending to be a toolbar list (which Qt silently reads as an empty list).
    flags = subprocess.check_output(
        ["pkg-config", "--cflags", "--libs", "Qt5Core"], text=True
    )
    config_writer = root / "toolbar-config"
    subprocess.run(
        [
            "c++",
            "-fPIC",
            str(Path(__file__).with_name("toolbar_config.cpp")),
            "-o",
            str(config_writer),
        ]
        + shlex.split(flags),
        check=True,
    )
    toolbar = os.environ.get("FLAMESHOT_TEST_BUTTONS", "")
    subprocess.run(
        [str(config_writer), str(actions.parent / "flameshot.ini")]
        + [item.strip() for item in toolbar.split(",") if item.strip()],
        check=True,
    )
    helper = Path(__file__).with_name("helper.py").resolve()
    icon_file = root / "custom icon.svg"
    icon_file.write_text(
        '<svg xmlns="http://www.w3.org/2000/svg" width="32" height="32"><rect x="8" y="8" width="16" height="16" fill="#00ffff"/></svg>'
    )
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
                    "icon": str(icon_file) if name == "b-send" else "video-display",
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

    def click(x, y):
        command("xdotool", "mousemove", str(x), str(y), "click", "1")
        time.sleep(0.2)

    def toolbar_centers(bottom):
        command("xdotool", "mousemove", "900", "700")
        time.sleep(0.3)
        path = root / f"toolbar-{bottom}.png"
        command("import", "-window", "root", str(path))
        image = Image.open(path).convert("RGB")
        # Native circular toolbar backgrounds are saturated purple by default.
        # Find disjoint horizontal spans on the solid portion near their top.
        y = bottom + 16
        spans = []
        start = None
        for x in range(50, image.width - 50):
            r, g, b = image.getpixel((x, y))
            match = r > 20 and b > 30 and g < 90
            if match and start is None:
                start = x
            if not match and start is not None:
                if x - start > 8:
                    spans.append(((start + x - 1) // 2, y + 10))
                start = None
        return spans

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
        command("import", "-window", "root", str(root / "before-selection.png"))
        before = Image.open(root / "before-selection.png").convert("RGB")
        assert len(before.crop((12, 12, 200, 42)).getcolors(10000)) == 1, (
            "Unexpected floating upper-left control before selection"
        )
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
        # Each action is an individual native toolbar circle, below this selection.
        # Empty/legacy-only toolbar: three actions; custom pencil: pencil + actions.
        extra = int(os.environ.get("FLAMESHOT_TEST_BUTTONS", "") == "0, 24")
        centers = toolbar_centers(355)
        assert len(centers) == 3 + extra, centers
        toolbar_image = Image.open(root / "toolbar-355.png").convert("RGB")
        icon_x, icon_y = centers[extra + 1]
        icon_crop = toolbar_image.crop(
            (icon_x - 12, icon_y - 5, icon_x + 12, icon_y + 25)
        )
        assert sum(pixel == (0, 255, 255) for pixel in icon_crop.getdata()) >= 30, (
            "Absolute SVG icon replaced by theme fallback"
        )
        command("xdotool", "mousemove", *map(str, centers[extra + 1]))
        time.sleep(1.2)
        command("import", "-window", "root", str(root / "action-tooltip.png"))
        # Fail via icon too, then retry successfully via the next separate icon.
        (root / "failed.txt").unlink()
        click(*centers[extra])
        wait_until(lambda: (root / "failed.txt").exists())
        assert process.poll() is None
        click(*centers[extra + 1])
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
        centers = toolbar_centers(500)
        click(*centers[extra + 2])

        def child_gone():
            try:
                os.kill(pid, 0)
                return False
            except ProcessLookupError:
                return True

        wait_until(child_gone)
        assert process.poll() is None, "Toolbar cancellation closed capture"
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
            "PASS: headless probe; no implicit execution; selected annotated PNG; failure stays open; individual toolbar icons and shortcut success close; customized toolbar; toolbar cancellation; capture close reaps child"
        )
        if os.environ.get("FLAMESHOT_TEST_ARTIFACTS"):
            destination = Path(os.environ["FLAMESHOT_TEST_ARTIFACTS"])
            shutil.copytree(root, destination, dirs_exist_ok=True)
            print("GUI artifacts:", destination)
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
