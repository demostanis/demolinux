# SPDX-License-Identifier: GPL-3.0-or-later

_cleanup_pacstrap_dir() {
    _msg_info "Cleaning up in pacstrap location..."

    # Delete all files in /boot
    [[ -d "${pacstrap_dir}/boot" ]] && find "${pacstrap_dir}/boot" -mindepth 1 -delete
    # Delete pacman database sync cache files (*.tar.gz)
    [[ -d "${pacstrap_dir}/var/lib/pacman" ]] && find "${pacstrap_dir}/var/lib/pacman" -maxdepth 1 -type f -delete
    # Delete pacman database sync cache
    [[ -d "${pacstrap_dir}/var/lib/pacman/sync" ]] && find "${pacstrap_dir}/var/lib/pacman/sync" -delete
    # Delete pacman package cache
    [[ -d "${pacstrap_dir}/var/cache/pacman/pkg" ]] && find "${pacstrap_dir}/var/cache/pacman/pkg" -type f -delete
    # Delete all log files, keeps empty dirs.
    [[ -d "${pacstrap_dir}/var/log" ]] && find "${pacstrap_dir}/var/log" -type f -delete
    # Delete all temporary files and dirs
    [[ -d "${pacstrap_dir}/var/tmp" ]] && find "${pacstrap_dir}/var/tmp" -mindepth 1 -delete
    # Delete package pacman related files.
    find "${work_dir}" \( -name '*.pacnew' -o -name '*.pacsave' -o -name '*.pacorig' \) -delete
    # Create /etc/machine-id with special value 'uninitialized': the final id is
    # generated on first boot, systemd's first-boot mechanism applies (see machine-id(5))
    rm -f -- "${pacstrap_dir}/etc/machine-id"
    printf 'uninitialized\n' > "${pacstrap_dir}/etc/machine-id"

    _msg_info "Done!"
}

_make_custom_airootfs() {
    local filename permissions

    install -d -m 0755 -o 0 -g 0 -- "${pacstrap_dir}"

    if [[ -d "${profile}/airootfs" ]]; then
        _msg_info "Copying custom airootfs files..."
        cp -af --no-preserve=ownership,mode -- "${profile}/airootfs/." "${pacstrap_dir}"
        # Set ownership and mode for files and directories
        for filename in "${!file_permissions[@]}"; do
            IFS=':' read -ra permissions <<< "${file_permissions["${filename}"]}"
            # Prevent file path traversal outside of $pacstrap_dir
            if [[ "$(realpath -q -- "${pacstrap_dir}${filename}")" != "${pacstrap_dir}"* ]]; then
                _msg_error "Failed to set permissions on '${pacstrap_dir}${filename}'. Outside of valid path." 1
            # Warn if the file does not exist
            elif [[ ! -e "${pacstrap_dir}${filename}" ]]; then
                _msg_warning "Cannot change permissions of '${pacstrap_dir}${filename}'. The file or directory does not exist."
            else
                if [[ "${filename: -1}" == "/" ]]; then
                    chown -fhR -- "${permissions[0]}:${permissions[1]}" "${pacstrap_dir}${filename}"
                    chmod -fR -- "${permissions[2]}" "${pacstrap_dir}${filename}"
                else
                    chown -fh -- "${permissions[0]}:${permissions[1]}" "${pacstrap_dir}${filename}"
                    chmod -f -- "${permissions[2]}" "${pacstrap_dir}${filename}"
                fi
            fi
        done
        _msg_info "Done!"
    fi
}

_make_disk_root() {
    local cache="${DEMOLINUX_ROOTFS_CACHE:-}" inputs
    if [[ -n "$cache" ]]; then
        inputs=$(python3 "${builder_dir}/build-inputs" rootfs)
        if [[ -s "$cache/rootfs.tar.zst" && -f "$cache/rootfs.key" ]] && \
            [[ "$(<"$cache/rootfs.key")" == "$inputs" ]]; then
            _msg_info "Restoring installed root filesystem (exact input match)..."
            mkdir -p "$(dirname "$pacstrap_dir")" "${profile}/packages"
            tar --zstd --xattrs --xattrs-include='*' --acls --numeric-owner \
                -xpf "$cache/rootfs.tar.zst" \
                -C "$(dirname "$pacstrap_dir")" airootfs -C "${profile}/packages" db
            pkg_list+=("${aur_pkg_list[@]}" "${local_pkg_list[@]}")
            install_pkg_list=("${pkg_list[@]}")
            return
        fi
    fi

    _make_custom_airootfs
    _make_chroot
    install_pkg_list=("${pkg_list[@]}")
    _make_packages

    if [[ -n "$cache" ]]; then
        _msg_info "Caching installed root filesystem before customization and SSH keys..."
        mkdir -p "$cache"
        tar --xattrs --acls --numeric-owner -I 'zstd -T0 -1' -cpf "$cache/rootfs.tar.zst.tmp" \
            -C "$(dirname "$pacstrap_dir")" airootfs -C "${profile}/packages" db
        mv "$cache/rootfs.tar.zst.tmp" "$cache/rootfs.tar.zst"
        printf '%s\n' "$inputs" > "$cache/rootfs.key"
    fi
}

_make_customize_airootfs() {
    local passwd=()
    local fprofile_dir

    # Generate locales
    eval -- env -u TMPDIR arch-chroot "${pacstrap_dir}" "/usr/bin/locale-gen"

    eval -- env -u TMPDIR HOME=/tmp arch-chroot "${pacstrap_dir}" 'bash -c '"'"'for doc in $(find /etc/skel/.local/share/nvim/site/pack -type d -name doc); do nvim -u NONE +"helptags $doc|q"; done'"'" >/dev/null

    # oomox is so messy that it was cleaner to separate
    # it to another file
    _msg_info "Generating oomox theme..."
    chmod +x "${pacstrap_dir}/usr/share/oomox/run_oomox.sh"
    eval -- env -u TMPDIR arch-chroot "${pacstrap_dir}" "/usr/share/oomox/run_oomox.sh"

    # Copy SSH public key
    local ssh_public_key="${DEMOLINUX_SSH_KEY:-$HOME/.ssh/id_ed25519}.pub"
    if [[ "$ssh_access" = y* ]] && [ -e "$ssh_public_key" ]; then
        _msg_info "Adding your id_ed25519.pub to ~/.ssh/authorized_keys..."
        mkdir -p "${pacstrap_dir}/etc/skel/.ssh/"
        cat "$ssh_public_key" >> "${pacstrap_dir}/etc/skel/.ssh/authorized_keys"
        _msg_info "Enabling sshd.service..."
        ln -sf /usr/lib/systemd/system/sshd.service "${pacstrap_dir}/etc/systemd/system/multi-user.target.wants/sshd.service"
        _msg_info "Done!"
    else
        # do not allow connections to port 22
        sed -i /22/d "${pacstrap_dir}"/etc/ufw/*.rules
    fi

    cp -- "${work_dir}/mirrorlist" "${pacstrap_dir}"/etc/pacman.d/mirrorlist

    _msg_info "Copying source to /usr/src/demolinux..."
    git clone "${profile}" "${pacstrap_dir}"/usr/src/demolinux >/dev/null

    # Install userchromejs-specific files to the Firefox profile
    if [[ " ${pkg_list[*]} " == *" firefox-userchromejs "* ]]; then
        _msg_info "Copying userchromejs configuration..."
        fprofile_dir="${pacstrap_dir}/etc/skel/.mozilla/firefox/default.profile"
        mkdir -p "${fprofile_dir}"
        cp -r "${pacstrap_dir}/usr/share/firefox-userchromejs/base/chrome/" "${fprofile_dir}"
        _msg_info "Done!"
    fi

    for dir in "${data_directories[@]}"; do
        ln -snf "/data/$dir" "${pacstrap_dir}/etc/skel/$dir"
    done

    if [[ -e "${profile}/airootfs/etc/passwd" ]]; then
        _msg_info "Copying /etc/skel/* to user homes..."
        while IFS=':' read -a passwd -r; do
            # Only operate on UIDs in range 1000–59999
            (( passwd[2] >= 1000 && passwd[2] < 60000 )) || continue
            # Skip invalid home directories
            [[ "${passwd[5]}" == '/' ]] && continue
            [[ "${passwd[5]}" == '/root' ]] && continue
            [[ -z "${passwd[5]}" ]] && continue
            # Prevent path traversal outside of $pacstrap_dir
            if [[ "$(realpath -q -- "${pacstrap_dir}${passwd[5]}")" == "${pacstrap_dir}"* ]]; then
                if [[ ! -d "${pacstrap_dir}${passwd[5]}" ]]; then
                    install -d -m 0750 -o "${passwd[2]}" -g "${passwd[3]}" -- "${pacstrap_dir}${passwd[5]}"
                fi
                cp -dnRT --preserve=mode,timestamps,links -- "${pacstrap_dir}/etc/skel/." "${pacstrap_dir}${passwd[5]}"
                chmod -f 0750 -- "${pacstrap_dir}${passwd[5]}"
                chown -hR -- "${passwd[2]}:${passwd[3]}" "${pacstrap_dir}${passwd[5]}"
            else
                _msg_error "Failed to set permissions on '${pacstrap_dir}${passwd[5]}'. Outside of valid path." 1
            fi
        done < "${profile}/airootfs/etc/passwd"
        _msg_info "Done!"
    fi
}

_make_version() {
    local _os_release

    _msg_info "Creating version files..."
    # Write version file to system installation dir
    rm -f -- "${pacstrap_dir}/version"
    printf '%s\n' "${image_version}" > "${pacstrap_dir}/version"

    # Append IMAGE_ID & IMAGE_VERSION to os-release
    _os_release="$(realpath -- "${pacstrap_dir}/etc/os-release")"
    if [[ ! -e "${pacstrap_dir}/etc/os-release" && -e "${pacstrap_dir}/usr/lib/os-release" ]]; then
        _os_release="$(realpath -- "${pacstrap_dir}/usr/lib/os-release")"
    fi
    if [[ "${_os_release}" != "${pacstrap_dir}"* ]]; then
        _msg_warning "os-release file '${_os_release}' is outside of valid path."
    else
        [[ ! -e "${_os_release}" ]] || sed -i '/^IMAGE_ID=/d;/^IMAGE_VERSION=/d' "${_os_release}"
        printf 'IMAGE_ID=%s\nIMAGE_VERSION=%s\n' "${image_id}" "${image_version}" >> "${_os_release}"
    fi

    # Touch /usr/lib/clock-epoch to give another hint on date and time
    # for systems with screwed or broken RTC.
    touch -m -d"@${SOURCE_DATE_EPOCH}" -- "${pacstrap_dir}/usr/lib/clock-epoch"

    _msg_info "Done!"
}
