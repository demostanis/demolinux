#!/bin/sh

packages=${*:-gimmeasearx lokinet firefox-userchromejs firefox-keyconfig firefox-vimfx firefox-ytarb firefox-dark-reader firefox-sponsorblock lsb-release wlroots wf-config wayfire wlogout waybar wdisplays clapper neo}
pgpkeys=(
# Haden Collins <collinshaden@gmail.com> (wlogout)
F4FDB18A9937358364B276E9E25D679AF73C6D2F
)

useradd -s/bin/sh -mG wheel builder 2>/dev/null
sed -i 's/# \(%wheel ALL=(ALL:ALL) NOPASSWD: ALL\)/\1/' /etc/sudoers
pacman-key --init 2>/dev/null
pacman-key --populate archlinux 2>/dev/null
su builder -c "$(cat <<EOF
for key in ${pgpkeys[*]}; do
	echo Importing key \$key...
	gpg --recv-keys \$key
done
for pkg in ${packages[*]}; do
	echo Building package \$pkg...
	pushd "/root/\$pkg" >/dev/null
	yes "" | makepkg -scfi || exit 1
	mv *pkg.tar* /home/builder
	popd >/dev/null
done
EOF
)"

