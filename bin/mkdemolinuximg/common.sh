# SPDX-License-Identifier: GPL-3.0-or-later

_msg_info() {
    local _msg="${1}"
    [[ "${quiet}" == "y" ]] || printf '[%s] INFO: %s\n' "${app_name}" "${_msg}"
}

_msg_warning() {
    local _msg="${1}"
    printf '[%s] WARNING: %s\n' "${app_name}" "${_msg}" >&2
}

_msg_error() {
    local _msg="${1}"
    local _error=${2}
    printf '[%s] ERROR: %s\n' "${app_name}" "${_msg}" >&2
    if (( _error > 0 )); then
        exit "${_error}"
    fi
}

_run_once() {
    if [[ ! -e "${work_dir}/${run_once_mode}.${1}" ]]; then
        local started=$SECONDS
        "$1"
        _msg_info "Timing: ${1} took $((SECONDS - started))s."
        touch "${work_dir}/${run_once_mode}.${1}"
    fi
}

_parse_file() {
    sed '/^[[:blank:]]*#.*/d;s/[[:blank:]]\?#.*//;/^[[:blank:]]*$/d' "$1"
}

_resolve_source_commit() {
    local kind=$1 source=$2 url response commit
    if [[ $kind == aur ]]; then
        url="https://aur.archlinux.org/${source}.git"
    elif [[ $source == https://* ]]; then
        url=$source
    else
        url="https://github.com/${source}"
    fi
    if ! response=$(git ls-remote "$url" HEAD); then
        if [[ $kind != aur ]] || ! response=$(git ls-remote https://github.com/archlinux/aur.git "refs/heads/$source"); then
            printf 'Failed to query %s source %s.\n' "$kind" "$source" >&2
            return 1
        fi
    fi
    read -r commit _ <<< "$response"
    if [[ ! $commit =~ ^[0-9a-f]{40}$ ]]; then
        printf 'No commit found for %s source %s.\n' "$kind" "$source" >&2
        return 1
    fi
    printf '%s\n' "$commit"
}
