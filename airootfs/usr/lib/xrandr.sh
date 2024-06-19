#!/bin/sh

OUTPUT_NAME=Virtual-1
RESOLUTION=1920x1080

xrandr | grep $OUTPUT_NAME || exit 1
xrandr | grep $OUTPUT_NAME | grep -q $RESOLUTION || \
	( xrandr --output $OUTPUT_NAME --mode $RESOLUTION && \
	awesome-client 'awesome.restart()' )
