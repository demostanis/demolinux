#!/bin/bash

gitdir=${1:-$HOME/programming/demolinux}
if [ ! -d "$gitdir" ]; then
  echo please specify gitdir >&2
  exit 1
fi

decode_path() {
  local input=$1
  local output=
  local i next

  for (( i=0; i<${#input}; i++ )); do
    if [ "${input:i:1}" = "\\" ] && [ $(( i + 1 )) -lt ${#input} ]; then
      next=${input:i+1:1}
      case $next in
        n)
          output+=$'\n'
          ((i++))
          continue
          ;;
        \\)
          output+="\\"
          ((i++))
          continue
          ;;
      esac
    fi

    output+="${input:i:1}"
  done

  printf '%s' "$output"
}

sudo persistfs list | while read -r path; do
  path=$(decode_path "$path")
  # bigger than 10M
  size=$(du -s "$path" 2>/dev/null | awk '{print $1}')
  if [ -z "$size" ]; then continue; fi
  if (( "$size" > 10000 )); then continue; fi
  if [ "$path" = /home/demostanis/.ssh ]; then continue; fi
  if [ "$path" = /home/demostanis/.config/pulse ]; then continue; fi
  if [ "$path" = /home/demostanis/.gitconfig ]; then continue; fi

  dest="$gitdir/airootfs"
  if [[ "$path" = /home/demostanis/* ]]; then
    dest+=/etc/skel/${path##/home/demostanis/}
  else
    dest+=$path
  fi

  if [ ! -h "$path" ]; then
    if [ -d "$path" ]; then
      mkdir -p "$dest"
      cp -vr "$path"/* "$dest"
    else
      cp -vr "$path" "$dest"
    fi
  fi
done

( cd "$gitdir"; git diff )
