# SPDX-License-Identifier: GPL-3.0-or-later

_move_boot_to_temp_location() {
    local ucode_image
    mkdir -p "$work_dir"/boot
    mv -- "${pacstrap_dir}/boot/initramfs-"*".img" "$work_dir"/boot
    mv -- "${pacstrap_dir}/boot/vmlinuz-"* "$work_dir"/boot

    for ucode_image in "${ucodes[@]}"; do
        if [[ -e "${pacstrap_dir}/boot/${ucode_image}" ]]; then
            mv -- "${pacstrap_dir}/boot/${ucode_image}" "$work_dir"/boot
        fi
    done
}

copy_boot_files() {
    local ucode_image
    _msg_info "Preparing kernel and initramfs for the disk image..."

    boot_dir=/mnt/demolinux/root/system/airootfs/boot
    mkdir -p $boot_dir

    # Way too many MBs wasted...
    rm -f "${work_dir}/boot/"*"fallback"*".img"
    cp -- "${work_dir}/boot/initramfs-"*".img" $boot_dir
    cp -- "${work_dir}/boot/vmlinuz-"* $boot_dir

    if [ -e /usr/share/ipxe/ipxe.lkrn ]; then
        cp /usr/share/ipxe/ipxe.lkrn $boot_dir
    fi
    if [ -e /usr/share/ipxe/x86_64/ipxe.efi ]; then
        cp /usr/share/ipxe/x86_64/ipxe.efi $boot_dir
    fi
    if [ -e /boot/memtest86+/memtest.bin ]; then
        cp /boot/memtest86+/memtest.bin $boot_dir
    fi
    if [ -e /boot/memtest86+/memtest.efi ]; then
        cp /boot/memtest86+/memtest.efi $boot_dir
    fi

    for ucode_image in "${ucodes[@]}"; do
        if [[ -e "${work_dir}/boot/${ucode_image}" ]]; then
            cp -- "${work_dir}/boot/${ucode_image}" $boot_dir/
        fi
    done
    _msg_info "Done!"
}

_close_hybrid_disk() {
    if [[ "${disk_boot_mounted:-n}" == y ]]; then
        umount /mnt/demolinux/boot || return
        disk_boot_mounted=n
    fi
    if [[ "${disk_root_mounted:-n}" == y ]]; then
        umount --recursive /mnt/demolinux/root || return
        disk_root_mounted=n
    fi
    if [[ "${disk_loop_owned:-n}" == y ]]; then
        losetup -d /dev/loop0 || return
        disk_loop_owned=n
    fi
}

_prepare_hybrid_disk() {
    [[ "${disk_loop_owned:-n}" == y ]] && return
    if mountpoint -q /mnt/demolinux/root || mountpoint -q /mnt/demolinux/boot || \
        losetup /dev/loop0 &>/dev/null; then
        _msg_error "Disk build mount points or /dev/loop0 are already in use." 1
    fi
    local reuse=n
    if [[ "${disk_root_in_place:-n}" == y && -f "${work_dir}/direct-root.key" ]]; then
        reuse=y
        [[ -s "${work_dir}/disk.img" ]] || _msg_error "Missing in-place disk image; clean the work directory." 1
    fi
    disk_boot_mounted=n
    disk_root_mounted=n
    disk_loop_owned=n

    # we used to calculate manually the size of the system partition.
    # since we now use Btrfs with zstd compression, instead of calculating
    # an incorrect size (since the size will greatly shrink after being
    # copied to the Btrfs subvolume), we set a fixed size. this also
    # ensures the system won't take up an extravagant amount of
    # space in the future.
    system_size=$( numfmt --from=iec --to=none --to-unit=1000000 <<< 5.5G)M
    disk_size=$( echo $(( "$(numfmt --from=iec --field=1,3,5 <<< "$system_size + 1M + 200M")" )) | numfmt --to=none --to-unit=1000000 --format=%.0f )M
    imgpath="${work_dir}/disk.img"

    if [[ "$reuse" == n ]]; then
        _msg_info "Partitioning disk..."
        # Create the disk image partitions
        truncate -s $disk_size "$imgpath"
        sgdisk \
            -n 1:0:+1M -t 1:ef02 -c 1:legacyboot \
            -n 2:0:+20M -t 2:ef00 -c 2:boot \
            -n 3:0:+$system_size -t 3:8300 -c 3:system \
            -p "$imgpath"
    fi

    losetup -P /dev/loop0 "$imgpath"
    disk_loop_owned=y

    if [[ "$reuse" == n ]]; then
        _msg_info "Creating file systems..."
        # boot
        mkfs.vfat /dev/loop0p2
        # system, swap, persist, data
        mkfs.btrfs /dev/loop0p3
    fi

    mkdir -p /mnt/demolinux/root
    mount -o compress=zstd,noatime /dev/loop0p3 /mnt/demolinux/root
    disk_root_mounted=y
    if [[ "$reuse" == n ]]; then
        btrfs subvolume create /mnt/demolinux/root/system
        btrfs subvolume create /mnt/demolinux/root/system/airootfs
    elif [[ ! -f "${work_dir}/base._install_bootloader" ]]; then
        btrfs property set /mnt/demolinux/root/system/airootfs ro false
    fi

    mkdir -p /mnt/demolinux/boot
    mount /dev/loop0p2 /mnt/demolinux/boot
    disk_boot_mounted=y
}

_install_bootloader() {
    _prepare_hybrid_disk
    copy_boot_files

    # the copying files operation causes the CI to fail
    # with No space left on device, so we remove some stuff...
    # TODO: something better??
    if [ -n "${CI-}" ]; then
        rm -rf "${profile}/packages/chroot"
    fi

    if [[ "${disk_root_in_place:-n}" != y ]]; then
        _msg_info "Copying files to the disk image..."
        cp -a "${pacstrap_dir}"/* /mnt/demolinux/root/system/airootfs
    fi
    mkdir -p /mnt/demolinux/root/system/airootfs/packages
    cp -r "${profile}/packages/db/." /mnt/demolinux/root/system/airootfs/packages/
    btrfs property set /mnt/demolinux/root/system/airootfs ro true

    _msg_info "Installing grub..."
    # Install grub for both BIOS and UEFI boot
    grub-install --target=i386-pc /dev/loop0 \
        --boot-directory=/mnt/demolinux/boot \
        --removable
    grub-install --target=x86_64-efi --no-nvram \
        --boot-directory=/mnt/demolinux/boot \
        --efi-directory=/mnt/demolinux/boot \
        --bootloader-id demolinux --removable

    _msg_info "Configuring grub..."
    cp "$profile"/grub/splash.png /mnt/demolinux/boot/grub
    # Patch grub-mkconfig to look at the right devices
    # and configuration files
    grub_cfg=/mnt/demolinux/boot/grub/grub.cfg
    sed '
        1a set -- -o '$grub_cfg'
        s,GRUB_DEVICE=.*,GRUB_DEVICE=/dev/loop0p3,
        s,GRUB_DEVICE_BOOT=.*,GRUB_DEVICE_BOOT=/dev/loop0p2,
        s,grub_mkconfig_dir=.*,grub_mkconfig_dir='"$profile"'/grub/grub.d,
        /\/default\/grub ; then/{N;N;N;N;N;N;N;a . '"$profile"'/grub/config
    d}' `which grub-mkconfig` | bash -

    mkdir -p /mnt/demolinux/boot/boot/grub
    cat > /mnt/demolinux/boot/boot/grub/grub.cfg <<-EOF
    # fix an issue where ubuntu's grub tries to load \$prefix/boot/grub.cfg instead of \$prefix/grub.cfg on some firmware
    set prefix="(\$root)"/grub
    configfile "\$prefix"/grub.cfg
EOF

    _close_hybrid_disk

    _msg_info "Done!"
}
