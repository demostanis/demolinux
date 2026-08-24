---
name: opencode-sidewindow
description: Use this skill whenever the user asks to display, preview, show, put, pin, replace, or remove an image in the OpenCode sidewindow, side window, or side panel attached to an OpenCode terminal. Also use it when the user asks to control that sidewindow with the opencode-sidewindow CLI. This skill handles local image display for now; do not trigger for unrelated image work unless the result should be shown in the OpenCode sidewindow.
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

## Other commands

```bash
opencode-sidewindow clear
opencode-sidewindow show
opencode-sidewindow hide
opencode-sidewindow toggle
opencode-sidewindow resize 520
opencode-sidewindow status
```

- `clear` removes the image without closing the sidewindow.
- `show`, `hide`, and `toggle` control visibility.
- `resize` sets the width in pixels. The user can also resize manually with Super+right-drag anywhere in the sidewindow.
- Quote paths so spaces and shell metacharacters remain intact.

## Failure handling

- If no OpenCode window is found, focus or launch the intended OpenCode window and retry.
- If the image cannot load, verify it exists and is a valid image before retrying.
- Do not modify the AwesomeWM configuration for ordinary image-display requests; the CLI is the stable interface.

## Maintenance rule

Do not create or run evals for this skill. Whenever this skill, its CLI, or its AwesomeWM sidewindow integration is updated, use `openopencode` to launch a fresh agent that explicitly loads this skill and performs a real CLI smoke test before considering the update complete. A suitable invocation is:

```bash
openopencode "Load and use the opencode-sidewindow skill. Display /usr/share/backgrounds/nyarch.jpg with the documented CLI, verify status reports the expanded sidewindow and image path, then write PASS and that status to /tmp/opencode-sidewindow-openopencode-test.txt. Do not edit the skill or AwesomeWM configuration" "New session"
```

Remove or ignore any stale marker before testing, wait for the fresh agent result, and inspect the reported status. Fix failures and repeat through `openopencode`. Do not substitute the skill-creator eval workflow for this user-required smoke test.
