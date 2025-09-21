if [ "$(tty)" = /dev/tty1 ]; then
	sudo plymouth update --status='Starting X...'
	sudo plymouth deactivate
	exec startx >/dev/null 2>&1
fi
