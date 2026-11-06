#!/usr/bin/env bash
set -euo pipefail

DEST=${DEST:-/etc/skel/.themes}
OOMOX_PATH=/usr/share/oomox
TEMPLATES="$OOMOX_PATH/plugins/base16/templates"
# libadwaita 1.10 is installed, but 1.9.2 is the newest packaged template.
GTK4_TEMPLATE=${GTK4_TEMPLATE:-$TEMPLATES/gtk4-oodwaita/templates/gtk4-libadwaita1.9.2.mustache}
APPLY_KDE_CONFIG=${APPLY_KDE_CONFIG:-0}
APPLY_GTK_CONFIG=${APPLY_GTK_CONFIG:-0}

mkdir -p -- "$DEST"
DEST=$(realpath -- "$DEST")
CONFIG_HOME=$(realpath -m -- "$DEST/../.config")
stage=$(mktemp -d "$DEST/.oomox-stage.XXXXXX")
theme=oomox-mellow-purple
config_tmp=
cleanup() {
	local status=$?
	if (( status != 0 )); then
		printf 'Theme generation failed; recovery files retained at %s\n' "$stage" >&2
		return "$status"
	fi
	if [[ -e "$stage/previous" || -L "$stage/previous" ]]; then
		if [[ ! -e "$DEST/$theme" && ! -L "$DEST/$theme" ]]; then
			mv -T -- "$stage/previous" "$DEST/$theme" || return "$status"
		fi
	fi
	[[ -z "$config_tmp" ]] || rm -f -- "$config_tmp"
	rm -rf -- "$stage"
	return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

# change_color.sh uses its own directory for src/ and scripts/; -p alone
# cannot redirect every source. Never patch the package-owned resources.
cp -R -- "$OOMOX_PATH/plugins/theme_oomox" "$stage/theme_oomox"
sed -i "s/ preprocess='to-pixdata'//g" \
	"$stage"/theme_oomox/src/gtk-3.{0,20}/gtk.gresource.xml

PYTHONDONTWRITEBYTECODE=1 python3 - "$OOMOX_PATH" "$stage" <<'PY'
import contextlib
from pathlib import Path
import shlex
import sys

oomox_path, stage = map(Path, sys.argv[1:])
sys.path.insert(0, str(oomox_path))
# Plugin diagnostics belong on stderr, not in the sourced color preset.
with contextlib.redirect_stdout(sys.stderr):
    import gi
    gi.require_version('Gtk', '3.0')
    from plugins.base16.oomox_plugin import Plugin, convert_oomox_to_base16
    from oomox_gui.theme_file_parser import read_colorscheme_from_path

    result = []
    read_colorscheme_from_path(
        str(oomox_path / 'plugins/base16/schemes/mellow/mellow-purple.yaml'),
        callback=result.append,
    )
    if len(result) != 1:
        raise RuntimeError('Expected one mellow-purple palette')
    colors = result[0]
    base16 = convert_oomox_to_base16(colorscheme=colors)
    for key, base_key in Plugin.translation_dark.items():
        colors[key] = base16[base_key]
    # The initial import has already resolved MENU_* from the light BG/FG.
    colors['MENU_BG'], colors['MENU_FG'] = colors['BG'], colors['FG']
    base16 = convert_oomox_to_base16(colorscheme=colors)

additions = (oomox_path / 'additions').read_text()
for filename, quote in (('palette.sh', shlex.quote), ('palette.colors', str)):
    with (stage / filename).open('w') as output:
        for key, value in base16.items():
            if key.startswith('themix_') and key != 'themix_ICONS_STYLE':
                print(f'{key.removeprefix("themix_")}={quote(value)}', file=output)
        # The CLI reads unquoted Oomox values; change_color.sh sources shell.
        output.write(additions + '\n')
PY

PYTHONDONTWRITEBYTECODE=1 "$stage/theme_oomox/change_color.sh" \
	-o "$theme" -t "$stage/output" "$stage/palette.sh"
generated="$stage/output/$theme"
mkdir -p -- "$generated/gtk-4.0" "$generated/qt6ct"

render() {
	PYTHONDONTWRITEBYTECODE=1 python3 - "$OOMOX_PATH" "$stage/palette.colors" "$1" "$2" <<'PY'
import contextlib
from pathlib import Path
import sys

oomox_path, palette, template, output = sys.argv[1:]
sys.path.insert(0, oomox_path)
with contextlib.redirect_stdout(sys.stderr):
    import gi
    gi.require_version('Gtk', '3.0')
    from oomox_gui.theme_file_parser import read_colorscheme_from_path
    from oomox_gui.terminal import generate_terminal_colors_for_oomox
    from plugins.base16.oomox_plugin import convert_oomox_to_base16, render_base16_template
    result = []
    read_colorscheme_from_path(palette, callback=result.append)
    colors = result.pop()
    generate_terminal_colors_for_oomox(colorscheme=colors, result_callback=result.append)
    colors = result.pop()
    rendered = render_base16_template(template, convert_oomox_to_base16(colorscheme=colors))
Path(output).write_text(rendered)
PY
	test -s "$2"
}
render "$GTK4_TEMPLATE" "$generated/gtk-4.0/gtk.css"
if [[ -f "$OOMOX_PATH/gtk4-overrides.css" ]]; then
	cat "$OOMOX_PATH/gtk4-overrides.css" >> "$generated/gtk-4.0/gtk.css"
fi
cp -- "$generated/gtk-4.0/gtk.css" "$generated/gtk-4.0/gtk-dark.css"
render "$TEMPLATES/qt6ct/templates/breeze.mustache" "$generated/qt6ct/colors.conf"
render "$TEMPLATES/kde/templates/default.mustache" "$generated/kdeglobals"

# Publish only after every generator succeeds; retain the old theme until then.
if [[ -e "$DEST/$theme" || -L "$DEST/$theme" ]]; then
	mv -T -- "$DEST/$theme" "$stage/previous"
fi
mv -T -- "$generated" "$DEST/$theme"

install_config() {
	local source=$1 target=$2
	mkdir -p -- "$(dirname -- "$target")"
	if [[ -e "$target" || -L "$target" ]]; then
		cp -a --parents -- "$target" "$stage/"
	fi
	config_tmp=$(mktemp "${target}.XXXXXX")
	cp -- "$source" "$config_tmp"
	chmod 644 "$config_tmp"
	mv -T -- "$config_tmp" "$target"
	config_tmp=
}
if [[ "$DEST" == /etc/skel/.themes || "$APPLY_GTK_CONFIG" == 1 ]]; then
	install_config "$DEST/$theme/gtk-4.0/gtk.css" "$CONFIG_HOME/gtk-4.0/gtk.css"
fi
# Custom DEST must not silently replace the running user's KDE settings.
if [[ "$DEST" == /etc/skel/.themes || "$APPLY_KDE_CONFIG" == 1 ]]; then
	install_config "$DEST/$theme/kdeglobals" "$CONFIG_HOME/kdeglobals"
fi
