if [ `tty` = /dev/tty2 ]; then
	exec startx >/dev/null 2>&1
fi
