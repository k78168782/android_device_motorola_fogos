#!/usr/bin/env bash
# clone.sh - clone device/vendor/kernel/hardware trees for Motorola fogos
# + cherry-pick sepolicy / DeviceAsWebcam fixes
# Run from the root of your ROM source tree (the dir containing .repo/ or build/).
# Usage: ./clone.sh            (normal)
#        DEPTH=1 ./clone.sh    (shallow clones, faster/smaller)

set -u

DEPTH="${DEPTH:-}"          # empty = full history
RETRIES=3
FAILED=()

# ---------- sanity checks ----------
if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git not found. Install: sudo apt install git" >&2
    exit 1
fi

if ! git lfs version >/dev/null 2>&1; then
    echo "ERROR: git-lfs not found. Install: sudo apt install git-lfs" >&2
    exit 1
fi

if [ ! -d .repo ] && [ ! -d build ]; then
    echo "WARNING: this doesn't look like a ROM source root (no .repo/ or build/)."
    echo "         Current dir: $(pwd)"
    read -r -p "Continue anyway? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || exit 1
fi

git lfs install --skip-repo >/dev/null 2>&1

# ---------- helpers ----------
# clone_if_missing <url> <branch|""> <target_dir> [lfs]
clone_if_missing() {
    local url=$1 branch=$2 dir=$3 lfs=${4:-}
    local args=()

    [ -n "$branch" ] && args+=(-b "$branch")
    [ -n "$DEPTH" ]  && args+=(--depth "$DEPTH")

    if [ -d "$dir/.git" ]; then
        echo "[skip] $dir already exists"
    else
        # remove empty/partial leftovers from a failed earlier run
        [ -d "$dir" ] && rm -rf "$dir"

        local i ok=0
        for ((i = 1; i <= RETRIES; i++)); do
            echo "[clone] $dir  (attempt $i/$RETRIES)"
            if git clone "${args[@]}" "$url" "$dir"; then
                ok=1
                break
            fi
            rm -rf "$dir"
            sleep 3
        done

        if [ "$ok" -ne 1 ]; then
            echo "[FAIL] $dir"
            FAILED+=("$dir")
            return 1
        fi
    fi

    if [ "$lfs" = "lfs" ]; then
        echo "[lfs]  pulling LFS objects in $dir"
        git -C "$dir" lfs pull || { echo "[FAIL] lfs pull in $dir"; FAILED+=("$dir (lfs)"); return 1; }
    fi
    return 0
}

# cherry_pick_from <target_dir> <remote_url> <remote_name> <commit1> [commit2...]
cherry_pick_from() {
    local dir=$1 remote_url=$2 remote_name=$3
    shift 3
    local commits=("$@")

    if [ ! -d "$dir/.git" ]; then
        echo "[skip] cherry-pick: $dir not found, did repo sync finish?"
        FAILED+=("$dir (not found for cherry-pick)")
        return 1
    fi

    echo "[pick] $dir <- $remote_url"

    # add remote if missing
    if ! git -C "$dir" remote get-url "$remote_name" >/dev/null 2>&1; then
        git -C "$dir" remote add "$remote_name" "$remote_url" || return 1
    fi

    # fetch only the needed commits
    if ! git -C "$dir" fetch "$remote_name" "${commits[@]}"; then
        echo "[FAIL] fetch failed for $dir"
        FAILED+=("$dir (fetch)")
        return 1
    fi

    local c
    for c in "${commits[@]}"; do
        # already in history? skip
        if git -C "$dir" merge-base --is-ancestor "$c" HEAD 2>/dev/null; then
            echo "[skip] $c already applied in $dir"
            continue
        fi

        echo "[pick] $c in $dir"
        if ! git -C "$dir" cherry-pick "$c"; then
            echo "[FAIL] cherry-pick conflict: $c in $dir"
            echo "       Fix it manually, then: git cherry-pick --continue"
            echo "       Or abort with: git -C $dir cherry-pick --abort"
            FAILED+=("$dir ($c)")
            return 1
        fi
    done
    return 0
}

# ---------- device / vendor / kernel ----------
clone_if_missing "https://github.com/k78168782/android_device_motorola_fogos.git"                "pixelos"      "device/motorola/fogos"
clone_if_missing "https://github.com/tiraq-official/android_device_motorola_sm6375-common.git"    "17.0"         "device/motorola/sm6375-common"
clone_if_missing "https://github.com/tiraq-official/proprietary_vendor_motorola_fogos.git"       "17.0"         "vendor/motorola/fogos"
clone_if_missing "https://github.com/tiraq-official/proprietary_vendor_motorola_sm6375-common.git" "17.0"       "vendor/motorola/sm6375-common"
clone_if_missing "https://github.com/tiraq-official/android_kernel_motorola_sm6375.git"          "lineage-23.2" "kernel/motorola/sm6375"

# ---------- hardware / apps ----------
clone_if_missing "https://github.com/tiraq-official/android_hardware_motorola"                   "lineage-23.2" "hardware/motorola"
clone_if_missing "https://github.com/tiraq-official/hardware_dolby_motorola.git"                 "main"         "hardware/dolby"
clone_if_missing "https://github.com/tiraq-official/android_hardware_samsung_slsi_nfc.git"       ""             "hardware/samsung_slsi/nfc"
clone_if_missing "https://github.com/tiraq-official/android_packages_apps_FogosParts.git"        "main"         "packages/apps/FogosParts"

# ---------- camera ----------
clone_if_missing "https://github.com/tiraq-official/vendor_motorola_motocam.git"                 "fogos"        "vendor/motorola/motocamera"

# ---------- cherry-picks ----------
# (1) system/sepolicy
cherry_pick_from "system/sepolicy" \
    "https://github.com/fogos-5-4/system_sepolicy.git" "fogos-pick" \
    "e62b2dd8a6f7068d8eccb04d26f19eff55f0f944"

# (2-5) packages/services/DeviceAsWebcam - ORDER MATTERS, don't reorder
cherry_pick_from "packages/services/DeviceAsWebcam" \
    "https://github.com/fogos-5-4/packages_services_DeviceAsWebcam.git" "fogos-pick" \
    "08fb6ea21b071e4aa9ac5341e34ab128c4c6c9c6" \
    "498ac4b643275247161903a1ff711f2435fcf4ba" \
    "d5f3b26641588a16af5dcefd87edd31286fb175d" \
    "9b97d83ae9f274fc4800df6c7042cf1cab6f8c8e"

# ---------- summary ----------
echo
if [ "${#FAILED[@]}" -eq 0 ]; then
    echo "All done. Everything cloned + cherry-picked successfully."
else
    echo "Finished with ${#FAILED[@]} failure(s):"
    printf '  - %s\n' "${FAILED[@]}"
    exit 1
fi
