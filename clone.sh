#!/usr/bin/env bash
# Parallel clone script for the fogos device tree.
# Usage: ./clone_repos.sh [-j JOBS] [-d] [-r RETRIES]
#   -j JOBS     max parallel clones (default: 4)
#   -d          shallow clone (--depth=1), much faster for big repos like the kernel
#   -r RETRIES  attempts per repo (default: 3)

set -u

JOBS=4
DEPTH=""
RETRIES=3

while getopts "j:dr:" opt; do
    case $opt in
        j) JOBS=$OPTARG ;;
        d) DEPTH="--depth=1" ;;
        r) RETRIES=$OPTARG ;;
        *) echo "Usage: $0 [-j JOBS] [-d] [-r RETRIES]"; exit 1 ;;
    esac
done

# Never hang waiting for a username/password prompt
export GIT_TERMINAL_PROMPT=0

LOG_DIR=$(mktemp -d /tmp/clone_logs.XXXXXX)

# Format: "repo_url|branch|target_dir"  (leave branch empty for the default branch)
REPOS=(
    "https://github.com/k78168782/android_device_motorola_fogos.git|pixelos|device/motorola/fogos"
    "https://github.com/k78168782/android_device_motorola_sm6375-common.git|17.0|device/motorola/sm6375-common"
    "https://github.com/k78168782/proprietary_vendor_motorola_fogos.git|17.0|vendor/motorola/fogos"
    "https://github.com/k78168782/proprietary_vendor_motorola_sm6375-common.git|17.0|vendor/motorola/sm6375-common"
    "https://github.com/k78168782/android_kernel_motorola_sm6375.git|lineage-23.2|kernel/motorola/sm6375"

    # Additional repos (unchanged)
    "https://github.com/tiraq-official/android_hardware_motorola|17.0|hardware/motorola"
    "https://github.com/tiraq-official/hardware_dolby_motorola|main|hardware/dolby"
    "https://github.com/tiraq-official/android_hardware_samsung_slsi_nfc.git||hardware/samsung_slsi/nfc"
    "https://github.com/tiraq-official/vendor_motorola_motocam.git|fogos|vendor/motorola/motocamera"
    "https://github.com/tiraq-official/android_packages_apps_FogosParts.git|main|packages/apps/FogosParts"
)

clone_repo() {
    local repo_url=$1 branch=$2 target_dir=$3
    local log="$LOG_DIR/${target_dir//\//_}.log"
    local args=(clone)
    [ -n "$DEPTH" ] && args+=("$DEPTH")
    [ -n "$branch" ] && args+=(-b "$branch")
    args+=("$repo_url" "$target_dir")

    if [ -d "$target_dir" ]; then
        echo "[skip]  $target_dir (already exists)"
        return 0
    fi

    mkdir -p "$(dirname "$target_dir")"

    local attempt
    for attempt in $(seq 1 "$RETRIES"); do
        echo "[start] $target_dir (attempt $attempt/$RETRIES)"
        if git "${args[@]}" >"$log" 2>&1; then
            echo "[done]  $target_dir"
            return 0
        fi
        rm -rf "$target_dir"   # remove partial clone before retrying
        sleep $((attempt * 2))
    done

    echo "[FAIL]  $target_dir  (log: $log)"
    return 1
}

failed=()
declare -A pid_to_target

wait_for_slot() {
    # Block until fewer than JOBS clones are running
    while [ "$(jobs -rp | wc -l)" -ge "$JOBS" ]; do
        wait -n 2>/dev/null || true
    done
}

for entry in "${REPOS[@]}"; do
    IFS='|' read -r url branch target <<<"$entry"
    wait_for_slot
    clone_repo "$url" "$branch" "$target" &
    pid_to_target[$!]=$target
done

# Collect exit status of every job
for pid in "${!pid_to_target[@]}"; do
    if ! wait "$pid"; then
        failed+=("${pid_to_target[$pid]}")
    fi
done

echo
if [ ${#failed[@]} -eq 0 ]; then
    echo "All repos ready."
    rm -rf "$LOG_DIR"
    exit 0
else
    echo "Failed (${#failed[@]}):"
    printf '  - %s\n' "${failed[@]}"
    echo "Logs kept in: $LOG_DIR"
    exit 1
fi
