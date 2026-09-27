---
name: opencode-sidewindow
description: Use the OpenCode sidewindow to display images or host any custom X11 window while working.
---

# OpenCode Sidewindow

Use the sidewindow for any visual artifact useful while working, including screenshots, design references, generated images, image-editing stages, charts, diagrams, document previews, and visual diffs.

Firefox MCP windows are already shown in the sidewindow. For another application, start it normally, get its X11 window ID (for example with `xdotool search --name 'Window title'`), then attach it with `window`. Closing its tab restores the window to its original position; it does not close the application.

```bash
opencode-sidewindow-api status
opencode-sidewindow-api list
opencode-sidewindow-api name "Name"
opencode-sidewindow-api image "/absolute/path/to/image.png"
opencode-sidewindow-api window 0x123456 "My app"
opencode-sidewindow-api remove                  # close the selected tab
opencode-sidewindow-api remove "Name"           # close a tab by name or index
```
