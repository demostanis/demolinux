---
name: opencode-sidewindow
description: Use this skill whenever the user asks to display, preview, show, put, pin, replace, or remove an image, terminal, or hardened Firefox window in the OpenCode sidewindow, side window, or side panel attached to an OpenCode terminal. Also use it when the user asks to control that sidewindow with the opencode-sidewindow CLI. Do not trigger for unrelated image, browser, or terminal work unless the result should appear in the OpenCode sidewindow.
compatibility: Requires AwesomeWM on DISPLAY=:0 and the opencode-sidewindow CLI in PATH.
---

# OpenCode Sidewindow

Use the `opencode-sidewindow` command instead of sending ad hoc Lua directly through `awesome-client`. The CLI targets the OpenCode window that owns the calling agent process, then falls back to the focused or visible OpenCode window.

## Display an image

1. Resolve the requested image to an existing local file. Use an absolute path when possible.
2. If the user asks to create or edit an image first, use the appropriate image-generation workflow, then pass its resulting local file to this skill.
3. Display and open it:

```bash
opencode-sidewindow image "/absolute/path/to/image.png"
```

4. Verify the result:

```bash
opencode-sidewindow status
```

Successful status includes `expanded` and `image=/absolute/path/to/image.png`. Report the image path concisely. Do not claim success when the CLI exits nonzero or reports `error:`.

Supported image formats depend on AwesomeWM's image loader and normally include PNG, JPEG, WebP, GIF, and SVG.

## Open a terminal

Launch a URxvt mapped into the sidewindow area:

```bash
opencode-sidewindow terminal
```

Verify that status includes `expanded` and `app=URxvt:0x...`. The terminal is an AwesomeWM-managed X11 client pinned to the sidewindow geometry, so it accepts normal mouse and keyboard input without Xephyr. Close it with:

```bash
opencode-sidewindow close-terminal
```

Opening an image closes any docked app. Opening a terminal replaces the current image or Firefox window.

## Open hardened Firefox

Open a Firefox window using the user's configured default profile:

```bash
opencode-sidewindow firefox
opencode-sidewindow firefox "https://example.com"
```

The command always uses `firefox-hardened --new-window`; do not add a temporary profile or `--new-instance`. Wait for startup, then verify status includes `expanded` and `app=firefox:0x...`. If Firefox is already running, this creates and docks another window from the same profile and process. Close only the docked window with:

```bash
opencode-sidewindow close-firefox
```

Opening Firefox replaces the current image or terminal. Repeating `firefox` while one is already docked reveals the existing window; it does not navigate that window to a new URL.

## Other commands

```bash
opencode-sidewindow clear
opencode-sidewindow terminal
opencode-sidewindow close-terminal
opencode-sidewindow firefox "https://example.com"
opencode-sidewindow close-firefox
opencode-sidewindow show
opencode-sidewindow hide
opencode-sidewindow toggle
opencode-sidewindow resize 520
opencode-sidewindow status
```

- `clear` removes the image without closing the sidewindow.
- `terminal` launches or reveals the docked URxvt; `close-terminal` closes it.
- `firefox [url]` launches or reveals hardened Firefox with the default profile; `close-firefox` closes only its docked window.
- `show`, `hide`, and `toggle` control visibility.
- `resize` sets the width in pixels. The user can also resize manually with Super+right-drag anywhere in the sidewindow.
- Quote paths so spaces and shell metacharacters remain intact.

## Failure handling

- If no OpenCode window is found, focus or launch the intended OpenCode window and retry.
- If the image cannot load, verify it exists and is a valid image before retrying.
- If an app remains in `app=launching:...`, close it and retry after confirming `urxvt` or `firefox-hardened` is installed.
- Do not modify the AwesomeWM configuration for ordinary image-display requests; the CLI is the stable interface.

## Maintenance rule

Do not create or run evals for this skill. Whenever this skill, its CLI, or its AwesomeWM sidewindow integration is updated, use `openopencode` to launch a fresh agent that explicitly loads this skill and performs a real CLI smoke test before considering the update complete. A suitable invocation is:

```bash
openopencode "Load and use the opencode-sidewindow skill. Open hardened Firefox at about:blank with the documented CLI and the default profile, wait for status to report expanded with app=firefox, then close it. Open the docked URxvt, verify app=URxvt, close it, then display /usr/share/backgrounds/nyarch.jpg and verify its status. Write PASS and all three statuses to /tmp/opencode-sidewindow-openopencode-test.txt. Do not edit files or configuration and do not run evals" "New session"
```

Remove or ignore any stale marker before testing, wait for the fresh agent result, and inspect the reported status. Fix failures and repeat through `openopencode`. Do not substitute the skill-creator eval workflow for this user-required smoke test.
