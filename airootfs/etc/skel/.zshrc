preexec() {
	1="$(sed s/%/%%/g<<<"$1")"
	printf "\x1b]0;$1\a"
}

precmd() {
	printf "\x1b]0;Untitled\a"
}


eval "$(luarocks path)"
