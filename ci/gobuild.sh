#!/usr/bin/env bash
# Copyright ©2022 XSans02

# Function to show an informational message
msg() {
    echo -e "\e[1;32m$*\e[0m"
}

err() {
    echo -e "\e[1;31m$*\e[0m"
}

# Clone kernel source
rm -rf kernel
git clone --depth=1 -b tiramisu https://github.com/elizabethangelalorenza/kernel_xiaomi_vayu kernel
cd kernel || exit

# Clone AnyKernel3 source
msg "* Clone AnyKernel3 source"
git clone --depth=1 -b vayu https://github.com/XSans0/AnyKernel3 AK3

# Clone toolchain source
msg "* Clone AOSP Clang"
wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-r450784e.tar.gz -O "aosp-clang.tar.gz"
mkdir clang && tar -xf aosp-clang.tar.gz -C clang && rm -rf aosp-clang.tar.gz
git clone --depth=1 https://github.com/XSans0/aarch64-linux-android-4.9 arm64
git clone --depth=1 https://github.com/XSans0/arm-linux-androideabi-4.9 arm32

# Setup
KERNEL_DIR="$PWD"
KERNEL_IMG="$KERNEL_DIR/out/arch/arm64/boot/Image"
KERNEL_DTBO="$KERNEL_DIR/out/arch/arm64/boot/dtbo.img"
KERNEL_DTB="$KERNEL_DIR/out/arch/arm64/boot/dts/qcom/sm8150-v2.dtb"
KERNEL_LOG="$KERNEL_DIR/out/log-$(TZ=Asia/Jakarta date +'%H%M').txt"
AK3_DIR="$KERNEL_DIR/AK3"
DEVICE="vayu"
CORES="$(nproc --all)"
CPU="$(lscpu | sed -nr '/Model name/ s/.*:\s*(.*) */\1/p')"

# Toolchain setup
CLANG_DIR="$KERNEL_DIR/clang"
GCC64_DIR="$KERNEL_DIR/arm64"
GCC32_DIR="$KERNEL_DIR/arm32"
PrefixDir="$CLANG_DIR/bin/"
ARM64="aarch64-linux-android-"
ARM32="arm-linux-androideabi-"
TRIPLE="aarch64-linux-gnu-"
PATH="$CLANG_DIR/bin:$GCC64_DIR/bin:$GCC32_DIR/bin:$PATH"
KBUILD_COMPILER_STRING="$("${CLANG_DIR}"/bin/clang --version | head -n 1 | sed -e 's/  */ /g' -e 's/[[:space:]]*$//')"

# Export
export TZ="Asia/Jakarta"
export ARCH="arm64"
export SUBARCH="arm64"
export KBUILD_BUILD_USER="elizabethangelalorenza"
export PATH
export KBUILD_COMPILER_STRING

# Start compile
START=$(date +"%s")
msg "* Start Compile kernel for $DEVICE using $CPU $CORES thread"

make O=out "$DEVICE"_defconfig
make -j"$CORES" O=out \
CC="${PrefixDir}"clang \
LD="${PrefixDir}"ld.lld \
AR="${PrefixDir}"llvm-ar \
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
CROSS_COMPILE_COMPAT=${ARM32} \
LLVM=1 2>&1 | tee "${KERNEL_LOG}"

if [[ -f "$KERNEL_IMG" ]]; then
    msg "* Compile Kernel for $DEVICE successfully."
else
    err "* Compile Kernel for $DEVICE failed, See buildlog to fix errors"
    exit
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
ZIP_NAME=["$ZIP_DATE"]Kyrielight-KATO-"$ZIP_DATE2".zip
zip -r9 "$ZIP_NAME" ./*