#!/usr/bin/env bash
# Copyright ©2022 XSans02

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;31m$*\e[0m"
}

# Cancel if something is missing
if [[ -z "${TELEGRAM_TOKEN}" ]] || [[ -z "${TELEGRAM_CHAT}" ]] || [[ -z "${TC}" ]] || [[ -z "${1}" ]]; then
    err "* There is something missing!"
    exit
fi

# Remove old source
rm -rf kernel

# Clone kernel source
KERNEL_BRANCH="$1"
git clone --depth=1 -b "$KERNEL_BRANCH" https://github.com/XSans0/kernel_xiaomi_vayu kernel
cd kernel || exit

# Clone AnyKernel3 source
msg "* Clone AnyKernel3 source"
git clone --depth=1 -b vayu https://github.com/XSans0/AnyKernel3 AK3

# Clone toolchain source
if [[ "${TC}" == "aosp15" ]]; then
    msg "* Clone AOSP Clang 15.x"
    NEED_GCC=y
    wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r468909b.tar.gz -O "aosp-clang.tar.gz"
    mkdir clang && tar -xf aosp-clang.tar.gz -C clang && rm -rf aosp-clang.tar.gz
    git clone --depth=1 https://github.com/XSans0/aarch64-linux-android-4.9 arm64
    git clone --depth=1 https://github.com/XSans0/arm-linux-androideabi-4.9 arm32
elif [[ "${TC}" == "weebx" ]]; then
    msg "* Clone WeebX Clang 16.x"
    wget "$(curl -s https://raw.githubusercontent.com/XSans0/WeebX-Clang/main/16.0.0/link.txt)" -O "weebx-clang.tar.gz"
    mkdir clang && tar -xf weebx-clang.tar.gz -C clang && rm -rf weebx-clang.tar.gz link.txt
elif [[ "${TC}" == "weebx15" ]]; then
    msg "* Clone WeebX Clang 15.x"
    wget "$(curl -s https://raw.githubusercontent.com/XSans0/WeebX-Clang/main/15.0.3/link.txt)" -O "weebx-clang.tar.gz"
    mkdir clang && tar -xf weebx-clang.tar.gz -C clang && rm -rf weebx-clang.tar.gz link.txt
elif [[ "${TC}" == "weebx14" ]]; then
    msg "* Clone WeebX Clang 14.x"
    git clone --depth=1 -b main https://gitlab.com/XSans0/weebx-clang.git clang
elif [[ "${TC}" == "proton" ]]; then
    msg "* Clone Proton Clang 13.x"
    git clone --depth=1 https://github.com/kdrag0n/proton-clang.git clang
elif [[ "${TC}" == "gcc13" ]]; then
    msg "* Clone GCC 13.x"
    GCC=y
    git clone --depth=1 -b gcc-master https://github.com/mvaisakh/gcc-arm64.git arm64
    git clone --depth=1 -b gcc-master https://github.com/mvaisakh/gcc-arm.git arm32
elif [[ "${TC}" == "gcc12" ]]; then
    msg "* Clone GCC 12.x"
    GCC=y
    git clone --depth=1 -b gcc-new https://github.com/mvaisakh/gcc-arm64.git arm64
    git clone --depth=1 -b gcc-new https://github.com/mvaisakh/gcc-arm.git arm32
fi

# Setup
KERNEL_DIR="$PWD"
KERNEL_IMG="$KERNEL_DIR/out/arch/arm64/boot/Image"
KERNEL_DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
KERNEL_DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm8150-v2-xiaomi.dtb"
KERNEL_LOG="$KERNEL_DIR/out/log-$(TZ=Asia/Jakarta date +'%H%M').txt"
AK3_DIR="$KERNEL_DIR/AK3"
DEVICE="vayu"
CORES="$(nproc --all)"
CPU="$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')"
BRANCH="$(git rev-parse --abbrev-ref HEAD)"
COMMIT="$(git log --pretty=format:'%s' -1)"

# Toolchain setup
if [[ "$NEED_GCC" == "y" ]]; then
    CLANG_DIR="$KERNEL_DIR/clang"
    GCC64_DIR="$KERNEL_DIR/arm64"
    GCC32_DIR="$KERNEL_DIR/arm32"
    PrefixDir="$CLANG_DIR/bin/"
    ARM64="aarch64-linux-android-"
    ARM32="arm-linux-androideabi-"
    TRIPLE="aarch64-linux-gnu-"
    COMPILE="clang"
    PATH="$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"
    KBUILD_COMPILER_STRING="$("${CLANG_DIR}"/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
elif [[ "$GCC" == "y" ]]; then
    GCC64_DIR="$KERNEL_DIR/arm64"
    GCC32_DIR="$KERNEL_DIR/arm32"
    ARM64="$GCC64_DIR/bin/aarch64-elf-"
    ARM32="$GCC32_DIR/bin/arm-eabi-"
    COMPILE="gcc"
    PATH="$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"
    KBUILD_COMPILER_STRING="$("${GCC64_DIR}"/bin/aarch64-elf-gcc --version | head -n 1)"
else
    CLANG_DIR="$KERNEL_DIR/clang"
    PrefixDir="$CLANG_DIR/bin/"
    ARM64="aarch64-linux-gnu-"
    ARM32="arm-linux-gnueabi-"
    TRIPLE="aarch64-linux-gnu-"
    COMPILE="clang"
    PATH="$CLANG_DIR/bin:$PATH"
    KBUILD_COMPILER_STRING="$("${CLANG_DIR}"/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"
fi

# Generated KBUILD_BUILD_HOST when running on Github Actions / Cirrus CI
# Generated custom KBUILD_BUILD_HOST when not running on Github Actions / Cirrus CI
if [ "${GITHUB_ACTIONS}" ]; then
    export KBUILD_BUILD_HOST="Github-Actions"
elif [ "${CIRRUS_CI}" ]; then
    export KBUILD_BUILD_HOST="Cirrus-CI"
else
    export KBUILD_BUILD_HOST="WeebX"
fi

# Export
export TZ="Asia/Jakarta"
export ARCH="arm64"
export SUBARCH="arm64"
export KBUILD_BUILD_USER="XSansツ"
export PATH
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
start_msg

if [[ "${COMPILE}" == "clang" ]]; then
    make O=out "$DEVICE"_defconfig
    make -j"$CORES" O=out \
        CC="${PrefixDir}"clang \
        LD="${PrefixDir}"ld.lld \
        AR="${PrefixDir}"llvm-ar \
        AS="${PrefixDir}"llvm-as \
        NM="${PrefixDir}"llvm-nm \
        HOSTCC="${PrefixDir}"clang \
        HOSTCXX="${PrefixDir}"clang++ \
        STRIP="${PrefixDir}"llvm-strip \
        OBJCOPY="${PrefixDir}"llvm-objcopy \
        OBJDUMP="${PrefixDir}"llvm-objdump \
        READELF="${PrefixDir}"llvm-readelf \
        OBJSIZE="${PrefixDir}"llvm-size \
        STRIP="${PrefixDir}"llvm-strip \
        CLANG_TRIPLE=${TRIPLE} \
        CROSS_COMPILE=${ARM64} \
        CROSS_COMPILE_ARM32=${ARM32} 2>&1 | tee "${KERNEL_LOG}"

    if [[ -f "$KERNEL_IMG" ]]; then
        msg "* Compile Kernel for $DEVICE successfully."
    else
        err "* Compile Kernel for $DEVICE failed, See buildlog to fix errors"
        send_file "$KERNEL_LOG" "<b>Compile Kernel for $DEVICE failed, See buildlog to fix errors</b>"
        exit
    fi
elif [[ "${COMPILE}" == "gcc" ]]; then
    make O=out "$DEVICE"_defconfig
    make -j"$CORES" O=out \
        LD=ld.lld \
        AR=llvm-ar \
        NM=llvm-nm \
        STRIP=llvm-strip \
        OBJCOPY=llvm-objcopy \
        OBJDUMP=llvm-objdump \
        READELF=llvm-readelf \
        CROSS_COMPILE=${ARM64} \
        CROSS_COMPILE_COMPAT=${ARM32} \
        CROSS_COMPILE_ARM32=${ARM32} 2>&1 | tee "${KERNEL_LOG}"

    if [[ -f "$KERNEL_IMG" ]]; then
        msg "* Compile Kernel for $DEVICE successfully."
    else
        err "* Compile Kernel for $DEVICE failed, See buildlog to fix errors"
        send_file "$KERNEL_LOG" "<b>Compile Kernel for $DEVICE failed, See buildlog to fix errors</b>"
        exit
    fi
fi

# End compile
END=$(date +"%s")
TOTAL_TIME=$(("END" - "START"))
export START END TOTAL_TIME
msg "* Total time elapsed: $(("TOTAL_TIME" / 60)) Minutes, $(("TOTAL_TIME" % 60)) Second."

# Copy Image, dtbo, dtb
if [[ -f "$KERNEL_IMG" ]] || [[ -f "$KERNEL_DTBO" ]] || [[ -f "$KERNEL_DTB" ]]; then
    cp "$KERNEL_IMG" "$AK3_DIR"
    cp "$KERNEL_DTBO" "$AK3_DIR"
	cp "$KERNEL_DTB" "$AK3_DIR/dtb.img"
    msg "* Copy Image, dtbo, dtb successfully"
else
    err "* Copy Image, dtbo, dtb failed!"
    exit
fi

# Zip
cd "$AK3_DIR" || exit
ZIP_DATE="$(TZ=Asia/Jakarta date +'%Y%m%d')"
ZIP_DATE2="$(TZ=Asia/Jakarta date +'%H%M')"
ZIP_NAME=["$ZIP_DATE"]WeebX-Personal-"$ZIP_DATE2".zip
zip -r9 "$ZIP_NAME" ./*

# Upload build
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
