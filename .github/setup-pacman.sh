#!/bin/bash

set -euo pipefail

sudo apt-get update
sudo apt-get install -y --no-install-recommends pacman-package-manager \
                      archlinux-keyring libarchive-tools \
                      systemd-container qemu-system-x86 qemu-utils zsh zstd

sudo mkdir -p /etc/pacman.d
cat <<-EOF | sudo tee -a /etc/pacman.conf >/dev/null
  [core]
  Include = /etc/pacman.d/mirrorlist

  [extra]
  Include = /etc/pacman.d/mirrorlist
EOF
# shellcheck disable=SC2016 # Pacman expands these placeholders.
echo Server = 'https://geo.mirror.pkgbuild.com/$repo/os/$arch' | sudo tee /etc/pacman.d/mirrorlist >/dev/null

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
sudo apt-get install -y --no-install-recommends arch-install-scripts \
  btrfs-progs dosfstools erofs-utils \
  git gdisk grub-pc-bin grub-efi-amd64-bin libxml2 pv squashfs-tools \
  unzip xfsprogs memtest86+

sudo mkdir -p /boot/memtest86+
sudo cp /boot/memtest86+x64.bin /boot/memtest86+/memtest.bin
sudo cp /boot/memtest86+x64.efi /boot/memtest86+/memtest.efi

sudo pacman -Sddw --noconfirm devtools grub ipxe

sudo bsdtar -C / -xf /var/cache/pacman/pkg/devtools-*.zst \
  usr/bin/makechrootpkg \
  usr/bin/mkarchroot \
  usr/bin/arch-nspawn \
  usr/share/devtools/lib

sudo bsdtar -C / -xf /var/cache/pacman/pkg/ipxe-*.zst \
  usr/share/ipxe

# our patches made to grub-mkconfig inside bin/mkarchiso
# don't apply to ubuntu's patched grub-mkconfig
sudo bsdtar -C /usr/sbin --strip-components 2 \
  -xf /var/cache/pacman/pkg/grub-*.zst \
  usr/bin/grub-mkconfig

# Arch's grub-mkconfig expects grub-probe to be in /usr/bin, not sbin...
sudo bsdtar -C / \
  -xf /var/cache/pacman/pkg/grub-*.zst \
  usr/bin/grub-probe

# enable KVM group perms
# https://github.blog/changelog/2023-02-23-hardware-accelerated-android-virtualization-on-actions-windows-and-linux-larger-hosted-runners/
echo 'KERNEL=="kvm", GROUP="kvm", MODE="0666", OPTIONS+="static_node=kvm"' | sudo tee /etc/udev/rules.d/99-kvm4all.rules
sudo udevadm control --reload-rules
sudo udevadm trigger --name-match=kvm
