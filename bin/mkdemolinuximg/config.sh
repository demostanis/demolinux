# SPDX-License-Identifier: GPL-3.0-or-later

_usage() {
    cat <<EOF
usage: ${app_name} [options] <profile_dir>
Build a demolinux GPT disk image bootable with BIOS and UEFI.

  -C <file>       Override the profile's pacman configuration
  -o <out_dir>    Output directory (default: ./out)
  -p "pkg ..."   Additional packages to install
  -w <work_dir>   Working directory (default: ./work)
  -h             Show this help
EOF
    exit "$1"
}

_show_config() {
    local build_date
    printf -v build_date '%(%FT%R%z)T' "${SOURCE_DATE_EPOCH}"
    _msg_info "${app_name} configuration settings"
    _msg_info "             Architecture:   ${arch}"
    _msg_info "        Working directory:   ${work_dir}"
    _msg_info "               Build date:   ${build_date}"
    _msg_info "         Output directory:   ${out_dir}"
    _msg_info "                  Profile:   ${profile}"
    _msg_info "Pacman configuration file:   ${pacman_conf}"
    _msg_info "          Image file name:   ${image_name:-None}"
    _msg_info "            Packages File:   ${packages}"
    _msg_info "                 Packages:   ${install_pkg_list[*]}"
    _msg_info "             AUR Packages:   ${aur_pkg_list[*]}"
    _msg_info "            Nvim Packages:   ${nvim_pkg_list[*]}"
    _msg_info "             Zsh Packages:   ${zsh_pkg_list[*]}"
    _msg_info "     Dependency Lock File:   ${deps_lock}"
    _msg_info "           Local Packages:   ${local_pkg_list[*]}"
    _msg_info "               SSH access:   ${ssh_access}"
}

_validate_packages() {
    local pkg
    local pkg_list_from_file=()

    # Check if the package list file exists and read packages from it
    if [[ -e "${packages}" ]]; then
        mapfile -t pkg_list_from_file < <(_parse_file "${packages}")
        for pkg in "${pkg_list_from_file[@]}"; do
            if [[ "$pkg" = aur\ * ]]; then
                aur_pkg_list+=("${pkg##aur }")
            elif [[ "$pkg" = local\ * ]]; then
                local_pkg_list+=("${pkg##local }")
            else
                pkg_list+=("$pkg")
            fi
        done
        if (( ${#pkg_list_from_file[@]} < 1 )); then
            (( validation_error=validation_error+1 ))
            _msg_error "no package specified in '${packages}'." 0
        fi
    else
        (( validation_error=validation_error+1 ))
        _msg_error "packages file '${packages}' does not exist." 0
    fi

    if [[ -e "${nvim_packages}" ]]; then
        mapfile -t nvim_pkg_list < <(_parse_file "${nvim_packages}")
        if (( ${#nvim_pkg_list[@]} < 1 )); then
            (( validation_error=validation_error+1 ))
            _msg_error "no package specified in '${nvim_packages}'." 0
        fi
    fi
    if [[ -e "${zsh_packages}" ]]; then
        mapfile -t zsh_pkg_list < <(_parse_file "${zsh_packages}")
        if (( ${#zsh_pkg_list[@]} < 1 )); then
            (( validation_error=validation_error+1 ))
            _msg_error "no package specified in '${zsh_packages}'." 0
        fi
    fi

    _validate_deps_lock
}

_validate_deps_lock() {
    local line kind source commit extra key
    local -A expected_commits=()

    locked_commits=()
    for source in "${aur_pkg_list[@]}"; do
        expected_commits["aur:${source}"]=1
    done
    for source in "${nvim_pkg_list[@]}"; do
        expected_commits["nvim:${source}"]=1
    done
    for source in "${zsh_pkg_list[@]}"; do
        expected_commits["zsh:${source}"]=1
    done

    if [[ ! -e "$deps_lock" ]]; then
        (( validation_error=validation_error+1 ))
        _msg_error "dependency lock file '${deps_lock}' does not exist." 0
        return
    fi

    while IFS= read -r line; do
        kind=""
        source=""
        commit=""
        extra=""
        read -r kind source commit extra <<< "$line"
        if [[ "$kind" != "aur" && "$kind" != "nvim" && "$kind" != "zsh" ]] || \
            [[ -z "$source" || ! "$commit" =~ ^[0-9a-f]{40}$ || -n "$extra" ]]; then
            (( validation_error=validation_error+1 ))
            _msg_error "invalid dependency lock entry '${line}'." 0
            continue
        fi

        key="${kind}:${source}"
        if [[ -n "${locked_commits[$key]-}" ]]; then
            (( validation_error=validation_error+1 ))
            _msg_error "duplicate dependency lock entry for ${kind} source '${source}'." 0
            continue
        fi
        locked_commits["$key"]="$commit"

        if [[ -z "${expected_commits[$key]-}" ]]; then
            (( validation_error=validation_error+1 ))
            _msg_error "dependency lock contains unknown ${kind} source '${source}'." 0
        fi
    done < <(_parse_file "$deps_lock")

    for key in "${!expected_commits[@]}"; do
        if [[ -z "${locked_commits[$key]-}" ]]; then
            (( validation_error=validation_error+1 ))
            _msg_error "dependency lock has no entry for ${key%%:*} source '${key#*:}'." 0
        fi
    done
}

_read_profile() {
    if [[ -z "${profile}" ]]; then
        _msg_error "No profile specified!" 1
    fi
    if [[ ! -d "${profile}" ]]; then
        _msg_error "Profile '${profile}' does not exist!" 1
    elif [[ ! -e "${profile}/profiledef.sh" ]]; then
        _msg_error "Profile '${profile}' is missing 'profiledef.sh'!" 1
    else
        cd -- "${profile}"

        # Source profile's variables
        # shellcheck source=profiledef.sh
        . "${profile}/profiledef.sh"

        # Resolve paths of files that are expected to reside in the profile's directory
        [[ -n "$arch" ]] || arch="$(uname -m)"
        [[ -n "$packages" ]] || packages="${profile}/available_packages"
        [[ -n "$nvim_packages" ]] || nvim_packages="${profile}/nvim_packages"
        [[ -n "$zsh_packages" ]] || zsh_packages="${profile}/zsh_plugins"
        [[ -n "$deps_lock" ]] || deps_lock="${profile}/deps.lock"
        packages="$(realpath -- "${packages}")"
        nvim_packages="$(realpath -- "${nvim_packages}")"
        zsh_packages="$(realpath -- "${zsh_packages}")"
        deps_lock="$(realpath -- "${deps_lock}")"
        pacman_conf="$(realpath -- "${pacman_conf:-/etc/pacman.conf}")"

        cd -- "${OLDPWD}"
    fi
}

_validate_options() {
    local validation_error=0
    _msg_info "Validating options..."
    if [[ ! -f "$pacman_conf" ]]; then
        (( validation_error+=1 ))
        _msg_error "Pacman configuration '$pacman_conf' does not exist." 0
    fi
    _validate_packages
    if [[ ! " ${pkg_list[*]} " =~ ' grub ' ]]; then
        (( validation_error+=1 ))
        _msg_error "The 'grub' package is required for BIOS/UEFI boot." 0
    fi
    if ! command -v awk &> /dev/null; then
        (( validation_error+=1 ))
        _msg_error "awk is not available on this host." 0
    fi
    if (( validation_error )); then
        _msg_error "${validation_error} errors were encountered while validating the profile. Aborting." 1
    fi
    _msg_info "Done!"
}

_set_overrides() {
    if [[ -v override_work_dir ]]; then
        work_dir="$override_work_dir"
    elif [[ -z "$work_dir" ]]; then
        work_dir='./work'
    fi
    work_dir="$(realpath -- "$work_dir")"
    if [[ -v override_out_dir ]]; then
        out_dir="$override_out_dir"
    elif [[ -z "$out_dir" ]]; then
        out_dir='./out'
    fi
    out_dir="$(realpath -- "$out_dir")"
    if [[ -v override_pacman_conf ]]; then
        pacman_conf="$override_pacman_conf"
    elif [[ -z "$pacman_conf" ]]; then
        pacman_conf="/etc/pacman.conf"
    fi
    pacman_conf="$(realpath -- "$pacman_conf")"
    [[ ! -v override_pkg_list ]] || pkg_list+=("${override_pkg_list[@]}")
}
