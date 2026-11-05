xrdb -merge ~/.Xresources
. ~/.local/bin/demolinux-dpi

feh -F /usr/share/pixmaps/nyarch.png --zoom 10 --class splash &
splash_pid=$!
echo "$splash_pid" > ~/.feh.pid
# Keep the Plymouth replica visible while the compositor initializes.
timeout 5s xdotool search --sync --onlyvisible --pid "$splash_pid" --class '^splash$' >/dev/null

# Daemonization returns only after initialization, before Awesome maps its panels.
picom-wrapper --daemon

xset r rate 200 45
exec awesome>~/.awesome.log 2>&1
