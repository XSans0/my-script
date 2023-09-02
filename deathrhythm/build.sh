#!/usr/bin/env bash

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;31m$*\e[0m"
}

# Environment checker
if [ -z "$BRANCH" ]; then
    err "* Missing environment!"
    exit
fi

# Home directory
HOME_DIR="$(pwd)"

# Clean toolchain source
if [ "$1" = "clean" ]; then
    msg "* Clean toolchain source"
    msg ""
    rm -rf "$HOME_DIR"/clang
fi

# Kernel source
msg "* Clone kernel source"
rm -rf kernel
git clone --depth=1 -b "$BRANCH" https://github.com/elizabethangelalorenza/kernel_xiaomi_vayu kernel
cd kernel || exit

# Anykernel3
msg "* Clone AnyKernel3 source"
rm -rf AK3
git clone --depth=1 -b vayu https://github.com/elizabethangelalorenza/AnyKernel3 AK3

# Toolchain
if [ -d "$HOME_DIR/clang" ]; then
    msg "* Toolchain already exist!"
    msg ""
else
    msg "* Clone Toolchain source"
    wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r498229.tar.gz -O "aosp-clang.tar.gz"
    mkdir "$HOME_DIR"/clang && tar -xf aosp-clang.tar.gz -C "$HOME_DIR"/clang && rm -rf aosp-clang.tar.gz
    git clone --depth=1 https://github.com/XSans0/aarch64-linux-android-4.9 "$HOME_DIR"/arm64
    git clone --depth=1 https://github.com/XSans0/arm-linux-androideabi-4.9 "$HOME_DIR"/arm32
fi

# Setup
KERNEL_DIR="$PWD"
KERNEL_IMG="$KERNEL_DIR/out/arch/arm64/boot/Image"
KERNEL_DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
KERNEL_DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm8150-v2.dtb"
KERNEL_LOG="$KERNEL_DIR/out/log-$(date +'%H%M').txt"
AK3_DIR="$KERNEL_DIR/AK3"
CLANG_DIR="$HOME_DIR/clang"
GCC64_DIR="$HOME_DIR/arm64"
GCC32_DIR="$HOME_DIR/arm32"
KBUILD_COMPILER_STRING="$("${CLANG_DIR}"/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
ARM64="aarch64-linux-android-"
ARM32="arm-linux-androideabi-"
TRIPLE="aarch64-linux-gnu-"
DEVICE="vayu"
CORES="$(nproc --all)"
CPU="$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')"

# Export
export ARCH="arm64"
export SUBARCH="arm64"
export TZ="Asia/Tokyo"
export KBUILD_BUILD_USER="vayu"
export KBUILD_BUILD_HOST="evolution"
export PATH="$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"
export KBUILD_COMPILER_STRING

# Setup and apply patch KernelSU in root dir
if ! [ -d "$KERNEL_DIR"/KernelSU ]; then
    curl -LSs "https://raw.githubusercontent.com/tiann/KernelSU/main/kernel/setup.sh" | bash -s main
    git apply KernelSU-hook.patch
fi

# Start compile
START=$(date +"%s")
msg "* Start Compile kernel for $DEVICE using $CPU $CORES thread"

make O=out "$DEVICE"_defconfig
make -j"$CORES" O=out \
    LLVM=1 \
    LLVM_IAS=1 \
    CLANG_TRIPLE="$TRIPLE" \
    CROSS_COMPILE="$ARM64" \
    CROSS_COMPILE_COMPAT="$ARM32" 2>&1 | tee "$KERNEL_LOG"

if [[ -f "$KERNEL_IMG" ]]; then
    # End compile
    END=$(date +"%s")
    TOTAL_TIME=$(("END" - "START"))
    export START END TOTAL_TIME
    msg "* Compile Kernel for $DEVICE successfully."
    msg "* Total time elapsed: $(("TOTAL_TIME" / 60)) Minutes, $(("TOTAL_TIME" % 60)) Second."
    msg ""
else
    err "* Compile Kernel for $DEVICE failed, See buildlog to fix errors"
    exit
fi

# Copy Image/dtbo/dtb to AnyKernel3
for files in {"$KERNEL_IMG","$KERNEL_DTBO","$KERNEL_DTB"}; do
    if [ -f "$files" ]; then
        msg "* Copy [$files] to AnyKernel3 directory"
        if [ "$files" = "$KERNEL_DTB" ]; then
            cp -r "$files" "$AK3_DIR"/dtb.img
        else
            cp -r "$files" "$AK3_DIR"
        fi
    else
        err "* Image/dtb/dtbo is missing!"
        err ""
        exit
    fi
done

# Compress to ZIP
msg ""
msg "* Create ZIP"
cd "$AK3_DIR" || exit
ZIP_NAME=DeathRhythm_"$DEVICE"_"$(date +'%Y%m%d')"_"$(date +'%H%M')".zip
zip -r9 "$ZIP_NAME" ./*
