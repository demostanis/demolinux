set_plymouth_status() { sudo plymouth update --status="$*" & }
set_plymouth_status Starting X...
chvt 1 &
xset r rate 200 45
xrdb -merge ~/.Xresources
set_plymouth_status Starting Awesome...
exec awesome>~/.awesome.log 2>&1
