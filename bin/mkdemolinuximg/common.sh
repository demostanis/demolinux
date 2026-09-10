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
