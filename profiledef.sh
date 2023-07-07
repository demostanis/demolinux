#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="demolinux"
iso_label="DEMOLINUX_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="demolinux"
iso_application="demolinux ISO"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="booya"
buildmodes=('disk_image')
bootmodes=('hybrid.grub.gpt')
disk_size=32G
swap_size=8G
ssh_access=y
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
file_permissions=(
  ["/data"]="1000:1000:755"
  ["/etc/shadow"]="0:0:400"
  ["/etc/sudoers"]="0:0:400"
  ["/root"]="0:0:750"
)
for file in $(find airootfs/usr/local/bin -type f); do
  file_permissions+=( ["${file##airootfs}"]="0:0:755" )
done
