if [ "$(tty)" = /dev/tty1 ]; then
	exec startx >/dev/null 2>&1
fi
