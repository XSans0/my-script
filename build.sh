#!/usr/bin/env bash

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;31m$*\e[0m"
}

# Environment checker
if [ -z "$TELEGRAM_TOKEN" ] || [ -z "$TELEGRAM_CHAT" ] || [ -z "$BRANCH" ]; then
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
git clone --depth=1 -b "$BRANCH" https://github.com/XSans0/kernel_xiaomi_vayu kernel
cd kernel || exit

# Anykernel3
msg "* Clone AnyKernel3 source"
rm -rf AK3
git clone --depth=1 -b vayu https://github.com/XSans0/AnyKernel3 AK3

# Toolchain
if [ -d "$HOME_DIR/clang" ]; then
    msg "* Toolchain already exist!"
    msg ""
else
    msg "* Clone Toolchain source"
    git clone --depth=1 https://github.com/kdrag0n/proton-clang "$HOME_DIR"/clang
fi

# Setup
KERNEL_DIR="$PWD"
KERNEL_IMG="$KERNEL_DIR/out/arch/arm64/boot/Image"
KERNEL_DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
KERNEL_DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm8150-v2.dtb"
KERNEL_LOG="$KERNEL_DIR/out/log-$(TZ=Asia/Jakarta date +'%H%M').txt"
AK3_DIR="$KERNEL_DIR/AK3"
CLANG_DIR="$HOME_DIR/clang"
KBUILD_COMPILER_STRING="$("${CLANG_DIR}"/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
ARM64="aarch64-linux-gnu-"
ARM32="arm-linux-gnueabi-"
TRIPLE="aarch64-linux-gnu-"
DEVICE="vayu"
CORES="$(nproc --all)"
CPU="$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT="$(git log --pretty=format:'%s' -1)"
COMMIT_HASH="$(git rev-parse HEAD)"
SHORT_COMMIT_HASH="$(cut -c-8 <<< "$COMMIT_HASH")"
COMMIT_URL="https://github.com/XSans0/kernel_xiaomi_vayu/commit/$SHORT_COMMIT_HASH"

# Export
export ARCH="arm64"
export SUBARCH="arm64"
export TZ="Asia/Jakarta"
export KBUILD_BUILD_USER="XSans"
export PATH="$CLANG_DIR/bin:$PATH"
export KBUILD_COMPILER_STRING

# Setup KBUILD_BUILD_HOST from default environment
if [ "$CIRRUS_CI" ]; then
    msg "* Set [Cirrus] as KBUILD_BUILD_HOST"
    export KBUILD_BUILD_HOST="Cirrus"
elif [ "$USER" = "gitpod" ]; then
    msg "* Set [Gitpod] as KBUILD_BUILD_HOST"
    export KBUILD_BUILD_HOST="Gitpod"
elif [ "$GITHUB_ACTIONS" ]; then
    msg "* Set [Github Actions] as KBUILD_BUILD_HOST"
    export KBUILD_BUILD_HOST="Github-Actions"
fi

# Telegram Setup
git clone --depth=1 https://github.com/XSans0/Telegram Telegram

TELEGRAM="$KERNEL_DIR/Telegram/telegram"
send_msg() {
  "${TELEGRAM}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

send_file() {
    "${TELEGRAM}" -H \
    -f "$1" \
    "$2"
}

start_msg() {
    send_msg "<b>New Kernel On The Way</b>" \
                 "<b>==================================</b>" \
                 "<b>Device : </b>" \
                 "<code>* $DEVICE</code>" \
                 "<b>Branch : </b>" \
                 "<code>* $BRANCH</code>" \
                 "<b>Build Using : </b>" \
                 "<code>* $CPU $CORES thread</code>" \
                 "<b>Last Commit : </b>" \
                 "<b>*</b> <a href='$COMMIT_URL'>$COMMIT</a>" \
                 "<b>==================================</b>"
}

# Start compile
START=$(date +"%s")
msg "* Start Compile kernel for $DEVICE using $CPU $CORES thread"
start_msg

make O=out "$DEVICE"_defconfig
    make -j"$CORES" O=out \
        LLVM=1 \
        CLANG_TRIPLE="$TRIPLE" \
        CROSS_COMPILE="$ARM64" \
        CROSS_COMPILE_COMPAT="$ARM32" 2>&1 | tee "$KERNEL_LOG"

# End compile
if [[ -f "$KERNEL_IMG" ]]; then
    END=$(date +"%s")
    TOTAL_TIME=$(("END" - "START"))
    export START END TOTAL_TIME
    msg "* Compile Kernel for $DEVICE successfully."
    msg "* Total time elapsed: $(("TOTAL_TIME" / 60)) Minutes, $(("TOTAL_TIME" % 60)) Second."
    msg ""
else
    err "* Compile Kernel for $DEVICE failed, See buildlog to fix errors"
    send_file "$KERNEL_LOG" "<b>Compile Kernel for $DEVICE failed, See buildlog to fix errors</b>"
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
ZIP_DATE="$(TZ=Asia/Jakarta date +'%Y%m%d')"
ZIP_DATE2="$(TZ=Asia/Jakarta date +'%H%M')"
ZIP_NAME=["$ZIP_DATE"]WeebX-Personal-"$ZIP_DATE2".zip
zip -r9 "$ZIP_NAME" ./*

# Upload build to telegram
send_file "$KERNEL_LOG" "<b>Compile Kernel for $DEVICE successfully.</b>"
send_file "$AK3_DIR/$ZIP_NAME" "
<b>Build Successfully</b>
<b>============================</b>
<b>Build Date : </b>
<code>* $(date +"%A, %d %b %Y")</code>
<b>Build Took : </b>
<code>* $(("TOTAL_TIME" / 60)) Minutes, $(("TOTAL_TIME" % 60)) Second.</code>
<b>Linux Version : </b>
<code>* v$(grep Linux "$KERNEL_DIR"/out/.config | cut -f 3 -d " ")</code>
<b>Md5 : </b>
<code>* $(md5sum "$AK3_DIR/$ZIP_NAME" | cut -d' ' -f1)</code>
<b>Compiler : </b>
<code>* $KBUILD_COMPILER_STRING</code>
<b>============================</b>"