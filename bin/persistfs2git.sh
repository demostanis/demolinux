#!/bin/bash

gitdir=${1:-$HOME/programming/demolinux}
if [ ! -d "$gitdir" ]; then
  echo please specify gitdir >&2
  exit 1
fi

sudo persistfs list | while read -r path; do
  # bigger than 10M
  size=$(du -s "$path" 2>/dev/null | awk '{print $1}')
  if [ -z "$size" ]; then continue; fi
  if (( "$size" > 10000 )); then continue; fi

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
