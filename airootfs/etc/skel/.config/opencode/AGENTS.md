You may use sudo pacman -S --noconfirm to install required dependencies if they're not available.

When producing simple demo web apps:
 - ensure the web server isn't already running through ps/pgrep/etc.
 - launch the web server in a PTY
 - open it visually for me to see using `firefox-hardened <url> &` if i don't already have its window open.

Never start git merges. Always prefer rebases.

Whenever creating or updating `~/.agents/skills/opencode-sidewindow`, its API, control interface, or AwesomeWM integration, do not run evals. Normally use `openopencode` to launch a fresh agent that explicitly loads the skill and smoke-tests `opencode-sidewindow-api`, unless the user explicitly asks to defer tests.
