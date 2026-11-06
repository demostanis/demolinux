# External script actions (DemoLinux Flameshot 12.1.0-5)

## Installer contract

`flameshot --external-actions-version` exits with status 0 and writes exactly
one byte, `3`, to stdout (no newline), with no stderr. Version 3 loads absolute
icon file paths directly, independently of the icon theme. Version 2 introduced native
toolbar icons; version 1 was the superseded floating menu. This sole-argument probe
runs at the beginning of `main`, before any Qt application, display, desktop
detection, single-instance mechanism, or DBus initialization. It works headless,
including when `QT_QPA_PLATFORM` is invalid. An unpatched Flameshot does not
support this flag. Check both the exit status and stdout, not the package version.

The tv-show installer can use this probe to decide whether to build/install this
package. Its implementation belongs to tv-show and is intentionally not changed
here. After upgrading, restart an already-running unpatched Flameshot daemon;
probing a newly installed executable does not upgrade an existing process.

## Configuration

Create one JSON object per file in
`$XDG_CONFIG_HOME/flameshot/actions.d/*.json`. If `XDG_CONFIG_HOME` is unset,
empty, or relative, the directory is `~/.config/flameshot/actions.d`. Files are
loaded for each new capture, not only at daemon startup. Example `show-on-tv.json`:

```json
{
  "name": "Show on TV",
  "program": "/usr/bin/python3",
  "arguments": ["/absolute/path/send-to-tv.py"],
  "shortcut": "Ctrl+Shift+T",
  "icon": "video-display",
  "timeout": 60000
}
```

- `name`: required nonblank string, maximum 200 characters.
- `program`: required absolute executable path, maximum 4096 characters; no NUL.
- `arguments`: required array of strings (empty is allowed), maximum 128 entries,
  each at most 4096 characters with no NUL. Arguments are passed literally.
- `shortcut`: optional Qt PortableText key sequence, maximum 128 characters.
  Choose an unused shortcut; conflicting or invalid shortcuts may not activate.
- `icon`: optional icon-theme name, maximum 256 characters. Missing icons do not
  prevent actions from working.
- `timeout`: optional integer milliseconds, 1 through 300000, default 60000.

Unknown fields are ignored. Files must be valid JSON objects of at most 64 KiB.
At most the first 128 matching files in filename order are examined. Invalid or
unreadable files are skipped with a warning; other valid actions remain usable.
An absent/empty directory leaves Flameshot's original UI unchanged.

## Capture UI

Each valid action has its own circular icon in Flameshot's normal capture toolbar
around the selection, with its name and shortcut in the tooltip. Icons follow
JSON filename order and use the configured theme icon (a visible arrow fallback
is used if missing). There is no floating External actions menu.

The buttons are dynamic `CaptureToolButton` instances passed to the same
`ButtonHandler` vector as the built-in tools: selection-relative placement,
hiding/showing and inside-selection layout apply to both. They are appended after
the user's chosen native tools, including when that list is empty. No finite
action enum slots or serialized toolbar IDs are allocated. Retired DemoLinux TV
button ID 24 is ignored on read without rewriting the config or hiding actions.

Each configured shortcut also activates its action while the capture is active.
Select a nonempty capture area first: triggering an action without one shows an
explanation and does not launch anything. No action runs on capture creation,
configuration load, annotation changes, or ordinary save/copy operations.

The script receives a PNG of the selected capture **including annotations**, but
without selection handles, tool preview/selection outlines, menus, or status UI.
Pending annotation edits are committed before encoding. The PNG is written to
the process's stdin, followed by EOF; there is no screenshot filename argument
or temporary screenshot file. PNG input is limited to 64 MiB per invocation.

Only one external action runs per capture at a time. Other action invocations
are ignored while busy, except that repeating the running action cancels it.
Other action icons are disabled. A mouse-transparent plain-text status at the
upper-left reports progress
and failure. The status is mouse-transparent and disappears after five seconds,
so it cannot block selection or editing after a failure. Exit 0 closes/completes the capture using Flameshot's existing
capture-completion path. Nonzero exit, a crash, failure to start, input write
failure, timeout, or cancellation leaves the capture open for retry or editing.

The running action icon becomes **Cancel <action name>**. Click it again (or
repeat its shortcut) to kill the direct child and keep editing. Its original
icon/tooltip and all action buttons are restored after failure or cancellation. Closing the capture (normally Escape) also kills/reaps that child.
QObject connections are disconnected before capture state is destroyed, so late
process events cannot access a destroyed capture. The deadline starts when the
action is requested, including process startup. stdout and stderr are redirected
to the null device, not accumulated or rendered; failure status is intentionally
generic. Scripts needing diagnostics should maintain their own bounded logs.

Programs run directly with `QProcess`, never through a shell: no quote parsing,
environment-variable, tilde, wildcard, or placeholder expansion occurs. The
process inherits Flameshot's environment and working directory. Use absolute
paths for script/resource arguments. JSON files and programs are trusted local
user configuration, not a sandbox. Scripts must not daemonize or leave detached
descendants: cancellation controls the direct child, not arbitrary process trees.

## Build and tests

The package applies `0001-Remove-border.patch` followed by
`0002-External-script-actions.patch` to the pristine `flameshot-v12.1.0.tar.gz`.
The external-actions patch also applies independently to that archive. Build the
package normally with `makepkg`; the existing Wayland clipboard option remains
enabled in the package. For a standalone native build without KF5GuiAddons:

```sh
cmake -S /path/to/patched/flameshot-12.1.0 -B /tmp/flameshot-build \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
  -DUSE_WAYLAND_CLIPBOARD=OFF
cmake --build /tmp/flameshot-build -j4
```

Run the package-local native tests (Qt5 Core/Test, CMake, C++ compiler, Python 3):

```sh
cmake -S tests -B /tmp/flameshot-actions-tests \
  -DFLAMESHOT_SOURCE=/path/to/patched/flameshot-12.1.0
cmake --build /tmp/flameshot-actions-tests -j4
ctest --test-dir /tmp/flameshot-actions-tests --output-on-failure
```

Tests exercise configuration validation, literal argument boundaries, binary
stdin/EOF, concurrent-start rejection, successful/nonzero/crashed/missing
processes, reuse after failure, 16 MiB of discarded output, deadlines,
cancellation, destruction/reaping, and input bounds.

For actual capture integration, install Xvfb, xdotool, xsetroot, ImageMagick,
xorg-xwininfo, Python Pillow, a C++ compiler, pkg-config and Qt5Core headers, then run:

```sh
dbus-run-session -- python3 tests/gui_smoke.py /tmp/flameshot-build/src/flameshot
```

This uses its own Xvfb and session bus, never the user's desktop. It checks the
exact headless probe, no floating upper-left control, no implicit execution,
annotated selected PNG dimensions, failure/continued capture and retry, three
individual action icons, mouse and shortcut success, icon cancellation, and child
reaping when the capture is closed. The toolbar list is written by the small
`toolbar_config.cpp` helper using Flameshot's actual Qt custom metatype format,
not a plain string that Qt would silently interpret as an empty list.

Run the GUI matrix sequentially (upstream's single-instance shared memory is not
isolated by DBus alone):

```sh
FLAMESHOT_TEST_BUTTONS=24 dbus-run-session -- python3 tests/gui_smoke.py /tmp/flameshot-build/src/flameshot
FLAMESHOT_TEST_BUTTONS='0, 24' dbus-run-session -- python3 tests/gui_smoke.py /tmp/flameshot-build/src/flameshot
```

The default uses an empty native toolbar, `24` exercises a retired-ID-only config,
and `0, 24` exercises a customized native pencil beside the three dynamic icons.
Set `FLAMESHOT_TEST_ARTIFACTS=/tmp/flameshot-toolbar-evidence` to retain successful
screenshots and config files. Failure artifacts are always retained in the
reported `/tmp/flameshot-gui-test-*-failed` directory.
