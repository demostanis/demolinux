---
name: opencode-sidewindow
description: Use the OpenCode sidewindow to display images or host any custom X11 window while working.
---

# OpenCode Sidewindow

Use the sidewindow for any visual artifact useful while working, including screenshots, design references, generated images, image-editing stages, charts, diagrams, document previews, and visual diffs.

Firefox MCP windows are already shown in the sidewindow. Use `launch` to start a new application directly in a tab, without showing it outside first. Closing a launched tab closes the application. For an already running application, use `window` with its X11 window ID (for example from `xdotool search --name 'Window title'`); closing that tab restores the window instead.

```bash
opencode-sidewindow-api status
opencode-sidewindow-api list
opencode-sidewindow-api name "Name"
opencode-sidewindow-api image "/absolute/path/to/image.png"
opencode-sidewindow-api launch --name "Terminal" -- urxvt
opencode-sidewindow-api window 0x123456 "My app"
opencode-sidewindow-api remove                  # close the selected tab
opencode-sidewindow-api remove "Name"           # close a tab by name or index
```
