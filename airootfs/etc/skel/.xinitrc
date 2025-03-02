feh -F /usr/share/pixmaps/nyarch.png --zoom 10 --class splash &
echo $! > ~/.feh.pid
xset r rate 200 45
xrdb -merge ~/.Xresources
exec awesome>~/.awesome.log 2>&1
