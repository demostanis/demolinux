#!/bin/bash
set -euo pipefail

image=${1:?Usage: run-tests.sh IMAGE}
export DEMOLINUX_TEST_IMAGE="$image"
export DEMOLINUX_NETWORK_BACKEND=user
export DEMOLINUX_BOOT_TIMEOUT=120
export DEMOLINUX_VM_MEMORY=2048
export DEMOLINUX_VM_CPUS=1
printf 'Host CPUs: %s\n' "$(nproc)"
free -h
pids=()
names=()

# shellcheck disable=SC2329 # Invoked by the EXIT trap.
cleanup() {
    local pid
    for pid in "${pids[@]}"; do
        kill "$pid" 2>/dev/null || true
    done
    for pid in "${pids[@]}"; do
        wait "$pid" 2>/dev/null || true
    done
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

shard() {
    local name=$1 index=${#pids[@]}
    shift
    local logs="$PWD/.ci/tests/$name"
    mkdir -p "$logs"
    DEMOLINUX_SSH_PORT=$((60022 + index)) \
    DEMOLINUX_QMP_PORT=$((4444 + index)) \
    DEMOLINUX_TEST_LOG_DIR="$logs" \
        timeout --kill-after=10s 240s ./tests/run "$@" > "$logs/tests.log" 2>&1 &
    pids+=("$!")
    names+=("$name")
}

# GUI tests share input/focus, so parallelism needs separate VMs, not shells.
shard windows awesome/layout awesome/overview
shard desktop awesome/emoji awesome/launcher awesome/panel dpi
shard applications firefox nvim opencode
shard media imv mpv music theme urxvt
shard system dataize persistfs resized systemd xorg sysupdate sysupdate_snapshot

failed=0
for index in "${!pids[@]}"; do
    if wait "${pids[$index]}"; then
        printf 'PASS: %s\n' "${names[$index]}"
    else
        printf 'FAIL: %s\n' "${names[$index]}"
        cat ".ci/tests/${names[$index]}/tests.log"
        failed=1
    fi
done
pids=()
exit "$failed"
