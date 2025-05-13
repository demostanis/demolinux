#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="demolinux"
iso_version="$(date +%Y.%m.%d)"
buildmodes=("disk_image")
bootmodes=("hybrid.grub.gpt")
ssh_access="y"
pacman_conf="pacman.conf"
data_directories=("downloads" "music" "programming" "templates" "movies" "shit")
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers"]="0:0:400"
  ["/etc/sudoers.d"]="0:0:400"

  ["/etc/openvpn/up"]="0:0:+x"
  ["/etc/openvpn/down"]="0:0:+x"

  ["/usr/lib/xrandr.sh"]="0:0:+x"
)
for file in $(find airootfs/usr/local/bin airootfs/etc/skel/.local/bin -type f); do
  file_permissions+=( ["${file##airootfs}"]="0:0:755" )
done
