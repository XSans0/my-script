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
    err ""
    exit
fi

# Clean toolchain source
if [ "$1" = "clean" ]; then
    msg "* Clean toolchain source"
    msg ""
    rm -rf ../clang
fi

# Kernel source
msg "* Clone kernel source"
msg ""
rm -rf kernel
git clone -b "$BRANCH" https://github.com/XSans0/kernel_xiaomi_vayu kernel
cd kernel || exit

# Anykernel3
msg "* Clone AnyKernel3 source"
msg ""
rm -rf AK3
git clone -b vayu https://github.com/XSans0/AnyKernel3 AK3

# Toolchain
if [ -d "../clang" ]; then
    msg "* Toolchain already exist!"
    msg ""
else
    msg "* Clone Toolchain source"
    msg ""
    git clone https://github.com/kdrag0n/proton-clang ../clang
fi

# Setup
KERNEL_DIR="$PWD"
KERNEL_IMG="$KERNEL_DIR/out/arch/arm64/boot/Image"
KERNEL_DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
KERNEL_DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm8150-v2.dtb"
KERNEL_LOG="$KERNEL_DIR/out/log-$(TZ=Asia/Jakarta date +'%H%M').txt"
AK3_DIR="$KERNEL_DIR/AK3"
CLANG_DIR="$KERNEL_DIR/clang"
PrefixDir="$CLANG_DIR/bin/"
KBUILD_COMPILER_STRING="$("${CLANG_DIR}"/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
ARM64="aarch64-linux-gnu-"
ARM32="arm-linux-gnueabi-"
TRIPLE="aarch64-linux-gnu-"
DEVICE="vayu"
CORES="$(nproc --all)"
CPU="$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT="$(git log --pretty=format:'%s' -1)"

# Export
export ARCH="arm64"
export SUBARCH="arm64"
export TZ="Asia/Jakarta"
export KBUILD_BUILD_USER="XSans"
export PATH="$CLANG_DIR/bin:$PATH"
export KBUILD_COMPILER_STRING

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
                 "<code>* $COMMIT</code>" \
                 "<b>==================================</b>"
}

# Start compile
START=$(date +"%s")
msg "* Start Compile kernel for $DEVICE using $CPU $CORES thread"
msg ""
start_msg

make O=out "$DEVICE"_defconfig
    make -j"$CORES" O=out \
        HOSTCC="$PrefixDir"clang \
        HOSTCXX="$PrefixDir"clang++ \
        CC="$PrefixDir"clang \
        LD="$PrefixDir"ld.lld \
        AR="$PrefixDir"llvm-ar \
        NM="$PrefixDir"llvm-nm \
        OBJCOPY="$PrefixDir"llvm-objcopy \
        OBJDUMP="$PrefixDir"llvm-objdump \
        READELF="$PrefixDir"llvm-readelf \
        STRIP="$PrefixDir"llvm-strip \
        CLANG_TRIPLE="$TRIPLE" \
        CROSS_COMPILE="$ARM64" \
        CROSS_COMPILE_COMPAT="$ARM32" \
        LLVM=1 2>&1 | tee "$KERNEL_LOG"

if [[ -f "$KERNEL_IMG" ]]; then
    msg "* Compile Kernel for $DEVICE successfully."
    msg ""
else
    err "* Compile Kernel for $DEVICE failed, See buildlog to fix errors"
    err ""
    send_file "$KERNEL_LOG" "<b>Compile Kernel for $DEVICE failed, See buildlog to fix errors</b>"
    exit
fi

# End compile
END=$(date +"%s")
TOTAL_TIME=$(("END" - "START"))
export START END TOTAL_TIME
msg "* Total time elapsed: $(("TOTAL_TIME" / 60)) Minutes, $(("TOTAL_TIME" % 60)) Second."
msg ""

# Copy Image/dtbo/dtb to AnyKernel3
for files in {"$KERNEL_IMG","$KERNEL_DTBO","$KERNEL_DTB"}; do
    if [ -f "$files" ]; then
        msg "* Copy Image/dtb/dtbo to AnyKernel3"
        msg ""
        cp -r "$files" "$AK3_DIR"
    else
        err "* Image/dtb/dtbo is missing!"
        err ""
        exit
    fi
done

# Compress to ZIP
msg "* Create ZIP"
msg ""
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