You may use sudo pacman -S --noconfirm to install required dependencies if they're not available.

When producing simple demo web apps:
 - ensure the web server isn't already running through ps/pgrep/etc.
 - launch the web server in a PTY
 - open it visually for me to see using `firefox-hardened <url> &` if i don't already have its window open.

Never start git merges. Always prefer rebases.

Avoid activating or moving X11 windows unless really necessary. Use `import` if you need to take screenshots of windows outside the viewport.
