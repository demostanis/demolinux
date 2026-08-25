---
name: opencode-sidewindow
description: Use this skill whenever the user asks an agent to display, preview, show, put, pin, replace, name, list, or inspect an image sidewindow attached to an OpenCode terminal. Also use it when the user explicitly asks about the opencode-sidewindow agent API. Do not trigger for unrelated image or browser work unless an image should appear in the OpenCode sidewindow.
compatibility: Requires AwesomeWM on DISPLAY=:0 and opencode-sidewindow-api in PATH.
---

# OpenCode Sidewindow

Agents must use `opencode-sidewindow-api`. Do not send ad hoc Lua through `awesome-client` and do not invoke `opencode-sidewindow-ctl`, which is reserved for AwesomeWM and integration hooks. The API targets the OpenCode window that owns the calling agent process, then falls back to the focused or visible OpenCode window.

The agent API intentionally exposes only four commands:

```bash
opencode-sidewindow-api status
opencode-sidewindow-api list
opencode-sidewindow-api name "Reference"
opencode-sidewindow-api image "/absolute/path/to/image.png"
```

## Display an image

1. Resolve the requested image to an existing local file, preferably with an absolute path.
2. If the user asks to create or edit an image first, use the appropriate image-generation workflow.
3. Display it:

```bash
opencode-sidewindow-api image "/absolute/path/to/image.png"
```

4. Verify the reported result when verification is requested:

```bash
opencode-sidewindow-api status
```

`image` creates and selects a dedicated sidewindow named `Image` when needed. Later calls replace that image without replacing the dedicated Firefox MCP sidewindow. Supported formats depend on AwesomeWM's image loader and normally include PNG, JPEG, WebP, GIF, and SVG.

## Inspect and name

- `status` reports the empty state or the selected sidewindow's expansion, geometry, index, name, image, and hosted application.
- `list` lists all sidewindows and marks the selected one with `*`.
- `name` renames the selected sidewindow. Names are unique per owner and cannot contain only digits.
- A fresh owner reports `none` from `list` and `empty ... tab=0/0` from `status`.

Every sidewindow has a titlebar with the owner icon, `SideWindow | <name>`, previous and next arrows, and a `current / total` count. The arrows remain visible but inert with one sidewindow. Users switch sidewindows with those arrows and expand or collapse the viewport with the owner chevron. `Super+Tab` visits an active visible hosted Firefox after its owner, while layout operations treat both as one logical window.

## Firefox MCP

Firefox MCP uses the internal control interface to lazily create a dedicated collapsed sidewindow named `Firefox MCP`. Closing that browser removes its sidewindow; a later MCP request recreates it. Agents should use Firefox MCP tools normally and must not call the control hook directly.

## Failure handling

- Do not claim success when the API exits nonzero or reports `error:`.
- If no OpenCode window is found, focus or launch the intended OpenCode owner and retry.
- If an image cannot load, verify the path and file format before retrying.
- Quote paths so spaces and shell metacharacters remain intact.

## Maintenance

Do not create or run evals for this skill. Integration smoke tests are normally performed through a fresh `openopencode` agent, but defer them when the user explicitly asks not to test.
