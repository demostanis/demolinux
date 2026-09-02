backend=glx
if grep QEMU /proc/cpuinfo >/dev/null 2>&1; then
	backend=xrender
fi

xrdb -merge ~/.Xresources
. ~/.local/bin/demolinux-dpi

picom --config ~/.config/picom/picom.splash.conf --backend $backend &

feh -F /usr/share/pixmaps/nyarch.png --zoom 10 --class splash &
echo $! > ~/.feh.pid

xset r rate 200 45
exec awesome>~/.awesome.log 2>&1
