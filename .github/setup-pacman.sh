#!/bin/bash

# this script used to be in the default.yml workflow.
# however, i needed to duplicate it to use it for
# the nightly builds workflow. so i thought about yaml
# anchors! turns out that's complete shit. even when
# i managed to get something ugly working, turns out
# GITHUB ACTIONS DOES NOT SUPPORT ANCHORS!!!!!!! fuck
# it.

sudo apt-get update
sudo apt-get install pacman-package-manager \
                      archlinux-keyring libarchive-tools \
                      systemd-container

sudo mkdir -p /etc/pacman.d
cat <<-EOF | sudo tee -a /etc/pacman.conf >/dev/null
  [core]
  Include = /etc/pacman.d/mirrorlist

  [extra]
  Include = /etc/pacman.d/mirrorlist
EOF
echo Server = 'https://geo.mirror.pkgbuild.com/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null

sudo cp /bin/bash /bin/sh
sudo cp /usr/share/keyrings /usr/share/pacman/keyrings -r

sudo pacman-key --init
sudo pacman-key --populate archlinux
sudo pacman -Sy --noconfirm

# Ubuntu's archlinux-keyring is outdated...
sudo pacman -Sddw --noconfirm archlinux-keyring
# why does Ubuntu's pacman looks for keys in
# /usr/share/keyrings instead of /usr/share/pacman/keyrings??
sudo bsdtar -C /usr/share/keyrings -xf /var/cache/pacman/pkg/archlinux-keyring-*.zst --strip-components 4 \
  usr/share/pacman/keyrings
sudo pacman-key --populate archlinux

# we don't let ./demolinux install these packages
# since it'd overwrite existing files
sudo apt-get install arch-install-scripts \
  btrfs-progs dosfstools erofs-utils \
  git gdisk grub-pc libxml2 pv squashfs-tools \
  unzip xfsprogs grub-ipxe memtest86+

sudo mkdir /usr/share/ipxe
sudo cp /boot/ipxe.lkrn /usr/share/ipxe

sudo mkdir /boot/memtest86+
sudo cp /boot/memtest86+x64.bin /boot/memtest86+/memtest.bin
sudo cp /boot/memtest86+x64.efi /boot/memtest86+/memtest.efi

sudo pacman -Sddw --noconfirm devtools grub
sudo bsdtar -C / -xf /var/cache/pacman/pkg/devtools-*.zst \
  usr/bin/makechrootpkg \
  usr/bin/mkarchroot \
  usr/bin/arch-nspawn \
  usr/share/devtools/lib

# our patches made to grub-mkconfig inside bin/mkarchiso
# don't apply to ubuntu's patched grub-mkconfig
sudo bsdtar -C /usr/sbin --strip-components 2 \
  -xf /var/cache/pacman/pkg/grub-*.zst \
  usr/bin/grub-mkconfig

# Arch's grub-mkconfig expects grub-probe to be in /usr/bin, not sbin...
sudo bsdtar -C / \
  -xf /var/cache/pacman/pkg/grub-*.zst \
  usr/bin/grub-probe
