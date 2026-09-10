# SPDX-License-Identifier: GPL-3.0-or-later

_build_disk_image_base() {
    local run_once_mode="base"
    # Set the package list to use
    local install_pkg_list=("${pkg_list[@]}")
    # Set up essential directory paths
    pacstrap_dir="${work_dir}/${arch}/airootfs"

    # Create working directory
    [[ -d "${work_dir}" ]] || install -d -- "${work_dir}"
    # Write build date to file or if the file exists, read it from there
    if [[ -e "${work_dir}/build_date" ]]; then
        SOURCE_DATE_EPOCH="$(<"${work_dir}/build_date")"
    else
        printf '%s\n' "$SOURCE_DATE_EPOCH" > "${work_dir}/build_date"
    fi

    [[ "${quiet}" == "y" ]] || _show_config
    _run_once _make_pacman_conf
    disk_root_in_place=n
    if [[ -n "${DEMOLINUX_ROOTFS_CACHE:-}" ]]; then
        local root_inputs cache_ready=n
        root_inputs=$(python3 "${builder_dir}/build-inputs" rootfs)
        if [[ -s "$DEMOLINUX_ROOTFS_CACHE/rootfs.tar.zst" && -f "$DEMOLINUX_ROOTFS_CACHE/rootfs.key" ]] && \
            [[ "$(<"$DEMOLINUX_ROOTFS_CACHE/rootfs.key")" == "$root_inputs" ]]; then
            cache_ready=y
        fi
        if [[ -f "${work_dir}/direct-root.key" ]] && \
            [[ "$(<"${work_dir}/direct-root.key")" != "$root_inputs" ]]; then
            _msg_error "In-place build inputs changed; clean the work directory." 1
        fi
        if [[ -f "${work_dir}/direct-root.key" || "$cache_ready" == y ]]; then
            if [[ ! -f "${work_dir}/base._make_disk_root" && "$cache_ready" != y ]]; then
                _msg_error "In-place root cache is unavailable; restore it or clean the work directory." 1
            fi
            disk_root_in_place=y
            _msg_info "Preparing an in-place cached root filesystem..."
            _prepare_hybrid_disk
            pacstrap_dir=/mnt/demolinux/root/system/airootfs
            printf '%s\n' "$root_inputs" > "${work_dir}/direct-root.key"
        fi
    fi
    _run_once _make_disk_root
    _run_once _make_version
    _run_once _make_customize_airootfs
    _run_once _move_boot_to_temp_location
    _run_once _install_bootloader
    # In-place roots are already finalized and read-only, not temporary trees.
    [[ "$disk_root_in_place" == y ]] || _run_once _cleanup_pacstrap_dir
}

_finalize_disk_image() {
    _close_hybrid_disk
    _msg_info "Moving disk image to ${out_dir}/$image_name..."
    mkdir -p "${out_dir}"
    mv "${work_dir}/disk.img" "${out_dir}/$image_name"
    local user=${SUDO_USER:-1000}
    chown $user:$user "${out_dir}/$image_name"
    _msg_info "Done!"
}

_build_image() {
    local image_name="${image_id}-${image_version}-${arch}.img"
    _build_disk_image_base
    _finalize_disk_image
}
