set -o vi
bindkey ^R history-incremental-pattern-search-backward
bindkey '^[[Z' reverse-menu-complete # Shift-Tab

autoload run-help
unalias run-help

source ~/.zaliases
source ~/.zfunctions
source ~/.zpath

export HISTFILE=~/.histfile
export HISTSIZE=10000
export SAVEHIST=10000

[ -n "$NEWPWD" ] && cd "$NEWPWD"

preexec() {
	# set window title
	1="$(sed s/%/%%/g<<<"$1")"
	printf "\x1b]0;$1\a"

	# reset cursor
	printf '\033[0 q'

	initial_seconds=$SECONDS
}

precmd() {
	[[ "$(fc -l -1)" = *pacman*-S* ]] && rehash

	printf "\x1b]0;Untitled\a"

	if [ -n "$initial_seconds" ]; then
		elapsed=$(($SECONDS - $initial_seconds))
		if (( $elapsed > 0 )); then
			format_elapsed=', command took %B'$elapsed's'
		else
			format_elapsed=
		fi
	fi

	# beautiful prompt
	export PROMPT='%B%(!.%F{9}.%F{6})%n%b%F{white} on %B%F{5}%m%b%f'$format_elapsed$'\n''%# %b'
	# show exit code
	export RPROMPT='%B%F{9}%(?..%?)'

	unset format_elapsed initial_seconds
}

printf '\033[5 q\r'
autoload -U add-zle-hook-widget
change_cursor() {
	case "$KEYMAP" in
		vicmd|visual)
			# block cursor
			printf '\033[1 q'
			;;
		*)
			# I-beam cursor
			printf '\033[5 q'
			;;
	esac
}
for hook in keymap-select line-finish line-init; do
	add-zle-hook-widget $hook change_cursor
done

# most of the completion stuff was stolen from grml
autoload -Uz compinit && compinit

zstyle ':completion:*:approximate:'    max-errors 'reply=( $((($#PREFIX+$#SUFFIX)/3 )) numeric )'

# start menu completion only if it could find no unambiguous initial string
zstyle ':completion:*:correct:*'       insert-unambiguous true
zstyle ':completion:*:correct:*'       original true

# activate color-completion
zstyle ':completion:*:default'         list-colors ${(s.:.)LS_COLORS} "ma=48;5;244;38;5;0"

# format on completion
zstyle ':completion:*:descriptions'    format $'%{\e[0m%}completing %B%d%b%{\e[0m%}'

# insert all expansions for expand completer
zstyle ':completion:*:expand:*'        tag-order all-expansions
zstyle ':completion:*:history-words'   list false

# match uppercase from lowercase
zstyle ':completion:*'                 matcher-list 'm:{a-z}={A-Z}'

# separate matches into groups
zstyle ':completion:*'                 group-name ''

# activate menu
zstyle ':completion:*'                 menu select

# describe options in full
zstyle ':completion:*:options'         description 'yes'

# on processes completion complete all user processes
zstyle ':completion:*:processes'       command 'ps -au$USER'

# offer indexes before parameters in subscripts
zstyle ':completion:*:*:-subscript-:*' tag-order indexes parameters

# provide verbose completion information
zstyle ':completion:*'                 verbose true

# set format for warnings
zstyle ':completion:*:warnings'        format $'%{\e[0;33m%}no matches for:%{\e[0m%} %d'

# ignore completion functions for commands you don't have:
zstyle ':completion::(^approximate*):*:functions' ignored-patterns '_*'

# provide more processes in completion of programs like killall:
zstyle ':completion:*:processes-names' command 'ps c -u ${USER} -o command | uniq'

# complete manual by their section
zstyle ':completion:*:manuals'    separate-sections true
zstyle ':completion:*:manuals.*'  insert-sections   true
zstyle ':completion:*:man:*'      menu yes select

COMP_CACHE_DIR=${COMP_CACHE_DIR:-${ZDOTDIR:-$HOME}/.cache}
if [[ ! -d ${COMP_CACHE_DIR} ]]; then
	command mkdir -p "${COMP_CACHE_DIR}"
	zstyle ':completion:*' use-cache  yes
	zstyle ':completion:*:complete:*' cache-path "${COMP_CACHE_DIR}"
fi

for plugin in ~/.zplugins/*/*.plugin.zsh; do source "$plugin"; done
fast-theme sv-orple >/dev/null 2>&1
# fast-syntax-highlighting shows
# weird errors while typing `man`, workaround:
FAST_HIGHLIGHT[chroma-man]=

if [[ $(tty) == /dev/pts/* ]]; then
	chpwd() {
		awesome-client "
			for _, master in pairs(tab_masters or {}) do
				for _, tab in ipairs(master.tabs) do
					if tab.client == client.focus then
						tab.pwd = [[$PWD]]
					end
				end
			end
		"
	}
fi
