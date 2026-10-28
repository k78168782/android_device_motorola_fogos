#!/bin/bash
clone_if_missing() {
    local repo_url=$1
    local branch=$2
    local target_dir=$3
    if [ ! -d "$target_dir" ]; then
        echo "Cloning $target_dir..."
        if [ -n "$branch" ]; then
            git clone "$repo_url" -b "$branch" "$target_dir"
        else
            git clone "$repo_url" "$target_dir"
        fi
        echo "Done."
    fi
}

# Git clones
clone_if_missing "https://github.com/tiraq-official/android_device_motorola_fogos.git" "17.0" "device/motorola/fogos"
clone_if_missing "https://github.com/tiraq-official/android_device_motorola_sm6375-common.git" "17.0" "device/motorola/sm6375-common"
clone_if_missing "https://github.com/tiraq-official/proprietary_vendor_motorola_fogos.git" "17.0" "vendor/motorola/fogos"
clone_if_missing "https://github.com/tiraq-official/proprietary_vendor_motorola_sm6375-common.git" "17.0" "vendor/motorola/sm6375-common"
clone_if_missing "https://github.com/tiraq-official/android_kernel_motorola_sm6375.git" "lineage-23.2" "kernel/motorola/sm6375"

# Additional repos (unchanged)
clone_if_missing "https://github.com/tiraq-official/android_hardware_motorola" "lineage-23.2" "hardware/motorola"
clone_if_missing "https://github.com/tiraq-official/hardware_dolby_zedisp.git" "lineage-23.2" "hardware/dolby"
clone_if_missing "https://github.com/tiraq-official/android_hardware_samsung_slsi_nfc.git" "" "hardware/samsung_slsi/nfc"
clone_if_missing "https://github.com/tiraq-official/vendor_motorola_motocam.git" "fogos" "vendor/motorola/motocamera"
clone_if_missing "https://github.com/tiraq-official/android_packages_apps_FogosParts.git" "main" "packages/apps/FogosParts"
