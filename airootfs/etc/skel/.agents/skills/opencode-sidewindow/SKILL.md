---
name: opencode-sidewindow
description: Use this skill whenever the user asks to display, preview, show, put, pin, replace, or remove an image, terminal, or hardened Firefox window in the OpenCode sidewindow, side window, or side panel attached to an OpenCode terminal. Also use it when the user asks to control that sidewindow with the opencode-sidewindow CLI. Do not trigger for unrelated image, browser, or terminal work unless the result should appear in the OpenCode sidewindow.
compatibility: Requires AwesomeWM on DISPLAY=:0 and the opencode-sidewindow CLI in PATH.
---

# OpenCode Sidewindow

Use the `opencode-sidewindow` command instead of sending ad hoc Lua directly through `awesome-client`. The CLI targets the OpenCode window that owns the calling agent process, then falls back to the focused or visible OpenCode window. A fresh OpenCode window has no sidewindows and no sidewindow chevron in its titlebar. The chevron appears when the first sidewindow is created and disappears when the final one is removed. Commands operate on the selected sidewindow unless documented otherwise.

## Named sidewindows

Every sidewindow has a custom titlebar matching the normal AwesomeWM titlebar height and active/inactive colors, with the owning application's icon on the left and `SideWindow | <name>` centered. It has no standard window actions. Its only controls are compact previous and next arrows around a `current / total` count. The arrows wrap through the owner's sidewindows like tabs; with exactly one sidewindow they remain visible but do nothing. Each sidewindow retains its own image or hosted application while it is inactive. `Super+Tab` visits the active visible hosted terminal or Firefox immediately after its owner, while movement, swapping, resizing, and maximizing continue to treat both as one logical window. The initial width is 560 pixels where the screen workarea allows, and remains manually resizable.

Create, rename, inspect, and switch sidewindows with:

```bash
opencode-sidewindow new "Preview"
opencode-sidewindow name "Reference"
opencode-sidewindow list
opencode-sidewindow select "Preview"
opencode-sidewindow select 2
opencode-sidewindow next
opencode-sidewindow previous
opencode-sidewindow remove "Reference"
```

`new` selects the created sidewindow and generates `Tab N`, beginning with `Tab 1`, when no name is supplied. Names are unique per OpenCode window and cannot contain only digits. `select` accepts an exact name or a one-based index. `remove` defaults to the selected sidewindow and closes only its hosted application. Removing the final sidewindow collapses the viewport and removes the owner titlebar chevron. Switching does not expand a collapsed sidewindow.

On a fresh owner, `opencode-sidewindow list` returns `none` and `opencode-sidewindow status` reports `empty` with `tab=0/0`. Commands that need a selected sidewindow report `error: no sidewindow exists`; they never create a placeholder `Main` sidewindow.

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

Successful status includes `expanded`, `tab=N/T`, `name="..."`, and `image=/absolute/path/to/image.png`. If none exists, `image` creates the first sidewindow as `Image`. Report the image path concisely. Do not claim success when the CLI exits nonzero or reports `error:`.

Supported image formats depend on AwesomeWM's image loader and normally include PNG, JPEG, WebP, GIF, and SVG.

## Open a terminal

Launch a URxvt mapped into the sidewindow area:

```bash
opencode-sidewindow terminal
```

Verify that status includes `expanded` and `app=URxvt:0x...`. If none exists, `terminal` creates the first sidewindow as `Terminal`. The terminal is an AwesomeWM-managed X11 client pinned to the sidewindow geometry, so it accepts normal mouse and keyboard input without Xephyr. Close it with:

```bash
opencode-sidewindow close-terminal
```

Opening an image closes any app in the selected sidewindow. Opening a terminal replaces the selected sidewindow's image or Firefox window. Other named sidewindows are unchanged.

## Open hardened Firefox

Open a Firefox window using the user's configured default profile:

```bash
opencode-sidewindow firefox
opencode-sidewindow firefox "https://example.com"
```

The command always uses `firefox-hardened --new-window`; do not add a temporary profile or `--new-instance`. If none exists, it creates the first sidewindow as `Firefox`. Wait for startup, then verify status includes `expanded` and `app=firefox:0x...`. If Firefox is already running, this creates and docks another window from the same profile and process. Close the docked browser and remove its sidewindow with:

```bash
opencode-sidewindow close-firefox
```

Opening Firefox replaces the selected sidewindow's image or terminal. Repeating `firefox` while one is already docked there reveals the existing window; it does not navigate that window to a new URL. Closing a hosted browser window, whether through Firefox or `close-firefox`, removes its named sidewindow and immediately updates the selected index and total count. Other named sidewindows are unchanged.

## Firefox MCP integration

The packaged `firefox-devtools-mcp` automatically runs the internal `capture-firefox` command immediately before Selenium launches Firefox. The new MCP-controlled window is attached to a dedicated sidewindow whose initial name is `Firefox MCP`, the owner titlebar chevron appears, and the viewport remains collapsed until the user opens it with the chevron or `opencode-sidewindow show`. The dedicated sidewindow keeps an internal role, so renaming it does not break later MCP recapture.

Do not run `capture-firefox` manually for ordinary use. Trigger any Firefox MCP tool instead. The MCP server uses the profile path from OpenCode configuration as a Selenium profile template, while the direct `firefox` command uses the live default profile. Closing the MCP-controlled window removes its dedicated sidewindow and updates the count. The next MCP tool request launches a replacement and lazily creates a new `Firefox MCP` sidewindow.

## Other commands

```bash
opencode-sidewindow clear
opencode-sidewindow new "Preview"
opencode-sidewindow name "Reference"
opencode-sidewindow list
opencode-sidewindow select "Preview"
opencode-sidewindow next
opencode-sidewindow previous
opencode-sidewindow remove "Reference"
opencode-sidewindow terminal
opencode-sidewindow close-terminal
opencode-sidewindow firefox "https://example.com"
opencode-sidewindow close-firefox
opencode-sidewindow show
opencode-sidewindow hide
opencode-sidewindow toggle
opencode-sidewindow resize 640
opencode-sidewindow status
```

- `new`, `name`, `select`, `next`, `previous`, `remove`, and `list` manage named sidewindows; removing the final one restores the empty no-chevron state.
- `clear` removes the selected sidewindow's image without closing the sidewindow.
- `terminal` launches or reveals the selected sidewindow's URxvt; `close-terminal` closes it.
- `firefox [url]` launches or reveals hardened Firefox in the selected sidewindow; `close-firefox` closes the browser and removes that sidewindow.
- `capture-firefox` is an internal owner-only hook used by `firefox-devtools-mcp` and selects its dedicated sidewindow.
- `show`, `hide`, and `toggle` control the selected owner's shared sidewindow viewport.
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
openopencode "Load and use the opencode-sidewindow skill. Through the documented CLI and visual inspection, verify a fresh owner starts with list=none, status empty tab=0/0, no sidewindow titlebar chevron, no placeholder Main tab, and stable owner geometry. Display an image as the first sidewindow; verify it is named Image, the chevron appears, and its initial expanded width is 560 pixels where workarea permits. Create and rename another sidewindow, put terminal content in it, and verify select, next, previous, list, count, persistence, and focus stability. Open direct Firefox in another named sidewindow, close the browser window itself, and verify that sidewindow is removed immediately and the current/total count updates. Remove every remaining sidewindow and verify the viewport collapses and the chevron disappears. Use a Firefox MCP tool and verify it lazily creates a dedicated Firefox MCP sidewindow while collapsed; close that browser and verify its sidewindow disappears and the count updates, then use another MCP tool and verify a replacement browser creates a new Firefox MCP sidewindow. Leave the final Firefox MCP sidewindow attached and collapsed. Write PASS and all statuses to /tmp/opencode-sidewindow-openopencode-test.txt. Do not edit files or configuration and do not run evals" "New session"
```

Remove or ignore any stale marker before testing, wait for the fresh agent result, and inspect the reported status. Fix failures and repeat through `openopencode`. Do not substitute the skill-creator eval workflow for this user-required smoke test.
