#!/bin/bash

gitdir=${1:-$HOME/programming/demolinux}
if [ ! -d "$gitdir" ]; then
  echo please specify gitdir >&2
  exit 1
fi

sudo persistfs list | while read -r path; do
  if [[ "$path" = /home/demostanis/* ]]; then
    newpath=${path##/home/demostanis/}
    cp -vr "$path"/* "$gitdir/airootfs/etc/skel/$newpath"
  fi
done

( cd "$gitdir"; git diff )
