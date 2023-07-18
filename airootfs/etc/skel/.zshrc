set -o vi
bindkey ^R history-incremental-pattern-backward-search
bindkey '^[[Z' reverse-menu-complete # Shift-Tab

autoload -Uz compinit
compinit

autoload run-help
unalias run-help

source .aliases

preexec() {
	# set window title
	1="$(sed s/%/%%/g<<<"$1")"
	printf "\x1b]0;$1\a"

	initial_seconds=$SECONDS
}

precmd() {
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

eval "$(luarocks path)"
