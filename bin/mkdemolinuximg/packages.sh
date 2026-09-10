# SPDX-License-Identifier: GPL-3.0-or-later

_make_pacman_conf() {
    local _cache_dirs _system_cache_dirs _profile_cache_dirs
    _system_cache_dirs="${DEMOLINUX_PACMAN_CACHE:-$(pacman-conf CacheDir| tr '\n' ' ')}"
    if [[ -n "${DEMOLINUX_PACMAN_CACHE:-}" ]]; then
        mkdir -p "$DEMOLINUX_PACMAN_CACHE"
    fi
    _profile_cache_dirs="$(pacman-conf --config "${pacman_conf}" CacheDir| tr '\n' ' ')"

    # Only use the profile's CacheDir, if it is not the default and not the same as the system cache dir.
    if [[ -n "${DEMOLINUX_PACMAN_CACHE:-}" ]]; then
        _cache_dirs="$DEMOLINUX_PACMAN_CACHE"
    elif [[ "${_profile_cache_dirs% }" != "/var/cache/pacman/pkg" ]] && \
        [[ "${_system_cache_dirs}" != "${_profile_cache_dirs}" ]]; then
        _cache_dirs="${_profile_cache_dirs}"
    else
        _cache_dirs="${_system_cache_dirs}"
    fi

    # Arch Linux archive so we don't have to -y all the time
    mirror=https://archive.archlinux.org/repos/$(<"${profile}/archive_date")/'$repo'/os/'$arch'
    echo Server = $mirror >> "${work_dir}/mirrorlist"
    echo '[options]' >> "${work_dir}/chroot.pacman.conf"
    echo 'Architecture = auto' >> "${work_dir}/chroot.pacman.conf"
    echo 'SigLevel = Required DatabaseOptional' >> "${work_dir}/chroot.pacman.conf"
    echo 'LocalFileSigLevel = Optional' >> "${work_dir}/chroot.pacman.conf"
    echo '[core]' >> "${work_dir}/chroot.pacman.conf"
    echo Server = $mirror >> "${work_dir}/chroot.pacman.conf"
    echo '[extra]' >> "${work_dir}/chroot.pacman.conf"
    echo Server = $mirror >> "${work_dir}/chroot.pacman.conf"

    _msg_info "Copying custom pacman.conf to work directory..."
    _msg_info "Using pacman CacheDir: ${_cache_dirs}"
    # take the profile pacman.conf and strip all settings that would break in chroot when using pacman -r
    # append CacheDir and HookDir to [options] section
    # HookDir is *always* set to the airootfs' override directory
    # see `man 8 pacman` for further info
    packagesdb="$(realpath -- ${profile}/packages/db)"
    pacman-conf --config "${pacman_conf}" | \
        sed "/CacheDir/d;/DBPath/d;/HookDir/d;/LogFile/d;/RootDir/d;/\[options\]/a CacheDir = ${_cache_dirs}
        s,<packagesdb>,${packagesdb},
        s,<mirrorlist>,$mirror,
        /\[options\]/a HookDir = ${pacstrap_dir}/etc/pacman.d/hooks/" > "${work_dir}/image.pacman.conf"
}

_cache_locked_commit() {
    local kind="$1"
    local source="$2"
    local cache_path="$3"
    local source_url="$4"
    local fallback_url="${5:-}"
    local key="${kind}:${source}"
    local commit="${locked_commits[$key]}"

    if [[ -e "$cache_path" ]]; then
        if ! git -c safe.directory="$cache_path" -C "$cache_path" rev-parse --git-dir &> /dev/null; then
            _msg_error "Git cache '${cache_path}' is not a repository." 1
        fi
    elif ! git clone --quiet --no-checkout -- "$source_url" "$cache_path"; then
        rm -rf -- "$cache_path"
        if [[ -z "$fallback_url" ]] || \
            ! git clone --quiet --no-checkout --branch "$source" --single-branch -- "$fallback_url" "$cache_path"; then
            _msg_error "Failed to clone ${kind} source '${source}'." 1
        fi
    fi

    if ! git -c safe.directory="$cache_path" -C "$cache_path" cat-file -e "${commit}^{commit}" 2> /dev/null; then
        git -c safe.directory="$cache_path" -C "$cache_path" fetch --quiet origin || :
    fi
    if ! git -c safe.directory="$cache_path" -C "$cache_path" cat-file -e "${commit}^{commit}" 2> /dev/null; then
        git -c safe.directory="$cache_path" -C "$cache_path" fetch --quiet "$source_url" || :
    fi
    if [[ -n "$fallback_url" ]] && \
        ! git -c safe.directory="$cache_path" -C "$cache_path" cat-file -e "${commit}^{commit}" 2> /dev/null; then
        git -c safe.directory="$cache_path" -C "$cache_path" fetch --quiet "$fallback_url" "$source" || :
    fi
    if ! git -c safe.directory="$cache_path" -C "$cache_path" cat-file -e "${commit}^{commit}" 2> /dev/null; then
        _msg_error "Locked commit '${commit}' for ${kind} source '${source}' is unavailable." 1
    fi
}

_checkout_locked_commit() {
    local kind="$1"
    local source="$2"
    local cache_path="$3"
    local key="${kind}:${source}"
    local commit="${locked_commits[$key]}"

    if ! git -c safe.directory="$cache_path" -C "$cache_path" checkout --quiet --force --detach "$commit"; then
        _msg_error "Failed to check out locked commit '${commit}' for ${kind} source '${source}'." 1
    fi
}

_export_locked_commit() {
    local kind="$1"
    local source="$2"
    local cache_path="$3"
    local destination="$4"
    local key="${kind}:${source}"
    local commit="${locked_commits[$key]}"
    local index_file

    rm -rf -- "$destination"
    mkdir -p "$destination"
    if ! (
        index_file="$(mktemp)"
        trap 'rm -f "$index_file"' EXIT
        rm -f "$index_file"
        GIT_INDEX_FILE="$index_file" git -c safe.directory="$cache_path" -C "$cache_path" read-tree "$commit"
        GIT_INDEX_FILE="$index_file" git -c safe.directory="$cache_path" -C "$cache_path" --work-tree="$destination" checkout-index --all
    ); then
        _msg_error "Failed to export locked commit '${commit}' for ${kind} source '${source}'." 1
    fi
}

_wait_for_background_jobs() {
    local pid
    local failed=0

    for pid in "$@"; do
        if ! wait "$pid"; then
            failed=1
        fi
    done
    return "$failed"
}

_package_is_cached() {
    local pkg="$1" inputs="$2" stored file
    local manifest="${profile}/packages/db/.inputs/${pkg}"
    [[ -s "$manifest" && -s "${profile}/packages/db/packages.db.tar.gz" ]] || return 1
    {
        read -r stored
        [[ "$stored" == "$inputs" ]] || return 1
        local count=0
        while IFS= read -r file; do
            [[ "$file" != */* && -s "${profile}/packages/db/$file" ]] || return 1
            count=$((count + 1))
        done
        (( count > 0 ))
    } < "$manifest"
}

_run_build_with_download_retries() {
    local log="$1" attempt result=0
    shift
    for attempt in 1 2 3; do
        if (set -o pipefail; "$@" 2>&1 | tee "$log"); then
            return 0
        else
            result=$?
        fi
        if (( attempt == 3 )) || \
            grep -Eq '==> ERROR: A failure occurred in (prepare|build|check|package)' "$log" || \
            ! grep -Eq 'error: failed (retrieving file|to synchronize all databases)|fatal: unable to access .*Could not resolve host' "$log"; then
            return "$result"
        fi
        _msg_info "Retrying after a transient dependency download failure (${attempt}/3)..."
        sleep 5
    done
    return "$result"
}

_make_chroot() {
    local chroot_dir pkg cachepkgpath pkgname url path inputs recipe_inputs
    local -a clone_pids=()

    chroot_dir="${profile}/packages/chroot"
    inputs=$(python3 "${builder_dir}/build-inputs" base)

    buildpkg() {
        local pkgdir="$1"
        local inputs="$2"
        local pkg file stale_dir
        local -a additional_opts=()
        local -a archives=()

        cd "${pkgdir}"
        pkg="${pkgdir##*/}"
        if [[ ! -d "${chroot_dir}/root" ]]; then
            mkdir -p "${chroot_dir}"
            _msg_info "Creating build chroot..."
            mkarchroot -C "${work_dir}/chroot.pacman.conf" "${chroot_dir}/root" base-devel
            sed -i 's/ debug / !debug /g' "${chroot_dir}/root/etc/makepkg.conf"
            printf '\nMAKEFLAGS="-j%s"\n' "$(nproc)" >> "${chroot_dir}/root/etc/makepkg.conf"
        fi
        chown -R "$SUDO_USER:$SUDO_USER" "${pkgdir}"

        realpkgname() {
            tar -xOf "$1" .PKGINFO 2>/dev/null | \
                awk -F"[= ]" '/^pkgname =/{print$4}'
        }

        # Remove every previous output of a split package before collecting -I.
        if [[ -f "${profile}/packages/db/.inputs/${pkg}" ]]; then
            while IFS= read -r file; do
                [[ "$file" != */* && "$file" == *.pkg.tar.* ]] || continue
                rm -f -- "${profile}/packages/db/$file"
            done < "${profile}/packages/db/.inputs/${pkg}"
        fi
        if compgen -G "${profile}"/packages/db/*pkg.tar* >/dev/null; then
            for file in "${profile}"/packages/db/*pkg.tar*; do
                if [[ "$(realpkgname "$file")" == "$pkg" ]]; then
                    rm -- "$file"
                else
                    additional_opts+=( -I "$file" )
                fi
            done
        fi
        # Only publish archives produced by this build, not old local outputs.
        stale_dir=""
        for file in *.pkg.tar.*; do
            [[ -f "$file" ]] || continue
            if [[ -z "$stale_dir" ]]; then
                stale_dir=$(mktemp -d "${work_dir}/stale-${pkg}.XXXXXX")
            fi
            mv -- "$file" "$stale_dir/"
        done
        _run_build_with_download_retries "${work_dir}/build-${pkg}.log" \
            "$correct_makechrootpkg" -U "$SUDO_USER" -r "${chroot_dir}" "${additional_opts[@]}"
        for file in *.pkg.tar.*; do
            [[ -f "$file" && "$file" != *.sig ]] || continue
            archives+=("$file")
        done
        (( ${#archives[@]} > 0 )) || _msg_error "No package archives produced for ${pkg}." 1
        repo-add "${profile}"/packages/db/packages.db.tar.gz "${archives[@]}"
        mv "${archives[@]}" "${profile}"/packages/db/
        printf '%s\n' "$inputs" "${archives[@]}" > "${profile}/packages/db/.inputs/${pkg}"
        _msg_info "Done!"
    }

    mkdir -p "${profile}"/packages/{aurcache,db,nvimcache,zshcache}/
    mkdir -p "${profile}/packages/db/.inputs"
    for pkg in "${aur_pkg_list[@]}"; do
        inputs=$(printf '%s\n' "$inputs" "$pkg" "${locked_commits["aur:${pkg}"]}" | sha256sum | cut -d' ' -f1)
        pkg_list+=("$pkg")
        if _package_is_cached "$pkg" "$inputs"; then
            _msg_info "Using cached AUR package $pkg."
            continue
        fi
        _msg_info "Building AUR package $pkg..."
        cachepkgpath="${profile}/packages/aurcache/$pkg"
        _cache_locked_commit \
            aur "$pkg" "$cachepkgpath" \
            "https://aur.archlinux.org/$pkg.git" \
            "https://github.com/archlinux/aur.git"
        _checkout_locked_commit aur "$pkg" "$cachepkgpath"
        buildpkg "$cachepkgpath" "$inputs"
    done
    for pkg in "${local_pkg_list[@]}"; do
        recipe_inputs=$(python3 "${builder_dir}/build-inputs" paths "packages/tobuild/$pkg")
        # Rebuild subsequent packages too: they may link against this package.
        inputs=$(printf '%s\n' "$inputs" "$pkg" "$recipe_inputs" | sha256sum | cut -d' ' -f1)
        pkg_list+=("$pkg")
        if _package_is_cached "$pkg" "$inputs"; then
            _msg_info "Using cached package $pkg."
            continue
        fi
        _msg_info "Building package $pkg..."
        buildpkg "${profile}/packages/tobuild/$pkg" "$inputs"
    done

    for pkg in "${nvim_pkg_list[@]}"; do
        (
            _msg_info "Cloning nvim package $pkg..."
            pkgname="${pkg##*/}"
            cachepkgpath="${profile}/packages/nvimcache/${pkgname}"
            url="$pkg"
            if [[ "$pkg" != https://* ]]; then
                url="https://github.com/$pkg"
            fi
            # damn, thats a long path
            path="${pacstrap_dir}/etc/skel/.local/share/nvim/site/pack/${pkgname}/start/${pkgname}/"
            _cache_locked_commit nvim "$pkg" "$cachepkgpath" "$url"
            _export_locked_commit nvim "$pkg" "$cachepkgpath" "$path"
        ) &
        clone_pids+=("$!")
    done
    if ! _wait_for_background_jobs "${clone_pids[@]}"; then
        _msg_error "Failed to install one or more Nvim packages." 1
    fi

    clone_pids=()
    for pkg in "${zsh_pkg_list[@]}"; do
        (
            _msg_info "Cloning zsh package $pkg..."
            pkgname="${pkg##*/}"
            cachepkgpath="${profile}/packages/zshcache/${pkgname}"
            url="$pkg"
            if [[ "$pkg" != https://* ]]; then
                url="https://github.com/$pkg"
            fi
            path="${pacstrap_dir}/etc/skel/.zplugins/${pkgname}"
            _cache_locked_commit zsh "$pkg" "$cachepkgpath" "$url"
            _export_locked_commit zsh "$pkg" "$cachepkgpath" "$path"
        ) &
        clone_pids+=("$!")
    done
    if ! _wait_for_background_jobs "${clone_pids[@]}"; then
        _msg_error "Failed to install one or more Zsh packages." 1
    fi
}

_make_packages() {
    _msg_info "Installing packages to '${pacstrap_dir}/'..."

    # Unset TMPDIR to work around https://bugs.archlinux.org/task/70580
    local -a install_command=(env -u TMPDIR pacstrap -C "${work_dir}/image.pacman.conf" -c -G -M -- "${pacstrap_dir}" "${install_pkg_list[@]}")
    if [[ "${quiet}" = "y" ]]; then
        _run_build_with_download_retries "${work_dir}/install-packages.log" "${install_command[@]}" &> /dev/null
    else
        _run_build_with_download_retries "${work_dir}/install-packages.log" "${install_command[@]}"
    fi

    _msg_info "Done! Packages installed successfully."
}

_setup_makechrootpkg() {
    # https://bugs.archlinux.org/task/64265
    correct_makechrootpkg=$(mktemp)
    sed '
    s/yes y/yes ""/
    /lib\/util\/machine.sh/a\
machine_name() {\
    local name=$1 machine="makechrootpkg-${name}" max_hostname=64 max_pid_digits=7\
    machine="$(tr "[:upper:]" "[:lower:]" <<< "${machine}" | tr --squeeze-repeats --complement "a-z0-9." - | tr --squeeze-repeats . | head --bytes=$(( max_hostname - max_pid_digits - 1 )))"\
    machine=${machine%%.}\
    machine=${machine%%-}\
    printf "%s.%s" "${machine}" "$$"\
}
    ' "$(command -v makechrootpkg)" > "$correct_makechrootpkg"
    chmod +x "$correct_makechrootpkg"
}
