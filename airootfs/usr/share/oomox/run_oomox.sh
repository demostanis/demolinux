#!/bin/sh

DEST=${DEST:-/etc/skel/.themes}
OOMOX_PATH=/usr/share/oomox
XDG_CONFIG_HOME="$DEST"/.config

# TODO: use CUSTOM_PATHLIST

python -c "
import sys, gi
sys.path.append('$OOMOX_PATH/')
gi.require_version('Gtk', '3.0')
from plugins.base16.oomox_plugin import Plugin, convert_oomox_to_base16
from oomox_gui.theme_file_parser import read_colorscheme_from_path
plugin_path = '$OOMOX_PATH/plugins/base16/schemes/mellow/mellow-purple.yaml'
result = []
themix_theme = None
read_colorscheme_from_path(plugin_path, callback=result.append)
for item in result:
	themix_theme = item
base16_theme = convert_oomox_to_base16(colorscheme=themix_theme)
for oomox_key, base16_key in Plugin.translation_dark.items():
	if base16_key in base16_theme:
	    themix_theme[oomox_key] = base16_theme[base16_key]
base16_theme = convert_oomox_to_base16(colorscheme=themix_theme)
for a, b in base16_theme.items():
	if a.startswith('themix_') and a != 'themix_ICONS_STYLE':
		a = a.replace('themix_', '')
		print(f'{a}={b}', file=sys.stderr)
print(open('$OOMOX_PATH/additions').read(), file=sys.stderr, end='')
" 2>&1 >/dev/null | grep -v Authorization | \
	"$OOMOX_PATH"/plugins/theme_oomox/change_color.sh \
		-o oomox-mellow-purple -t "$DEST" /dev/stdin

mkdir -p "$DEST"/oomox-mellow-purple/gtk-4.0
themix-base16-cli \
	"$OOMOX_PATH"/plugins/base16/templates/gtk4-oodwaita/templates/gtk.mustache \
	"$OOMOX_PATH"/plugins/base16/schemes/mellow/mellow-purple.yaml \ |
	grep -v ^ERROR: | grep -v '^Import Colors' \
	> "$DEST"/oomox-mellow-purple/gtk-4.0/gtk-dark.css

mkdir -p "$DEST"/oomox-mellow-purple/qt6ct
themix-base16-cli \
	"$OOMOX_PATH"/plugins/base16/templates/qt6ct/templates/breeze.mustache \
	"$OOMOX_PATH"/plugins/base16/schemes/mellow/mellow-purple.yaml \ |
	grep -v ^ERROR: | grep -v '^Import Colors' \
	> "$DEST"/oomox-mellow-purple/qt6ct/colors.conf
