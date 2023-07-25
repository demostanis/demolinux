set -o vi
bindkey ^R history-incremental-pattern-backward-search
bindkey '^[[Z' reverse-menu-complete # Shift-Tab

autoload run-help
unalias run-help

source ~/.zaliases
source ~/.zfunctions
source ~/.zpath

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

if [[ $(tty) == /dev/pts/* ]]; then
	source ~/.zplugins/*/*.plugin.zsh

	# https://github.com/marlonrichert/zsh-autocomplete#make-tab-go-straight-to-the-menu-and-cycle-there
	bindkey '\t' menu-select "$terminfo[kcbt]" menu-select
	bindkey -M menuselect '\t' menu-complete "$terminfo[kcbt]" reverse-menu-complete
	# disable zsh-autocomplete history
	bindkey -a k up-line-or-history
	bindkey -a j down-line-or-history
	bindkey "^[[A" up-line-or-history
	bindkey "^[[B" down-line-or-history
fi
