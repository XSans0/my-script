#!/usr/bin/env bash
# Copyright ©2022 XSans02

# Function to show an informational message
function msg() {
    echo -e "\e[1;32m$*\e[0m"
}

function panel() {
    echo -e "\e[1;34m$*\e[0m"
}

function panel2() {
    echo -ne "\e[1;34m$*\e[0m"
}

function err() {
    echo -e "\e[1;31m$*\e[0m"
}

function clear_clang() {
	rm -rf clang arm64 arm32
}

# Menu
while true; do
    panel ""
    panel " Toolchain Menu                                                         "
    panel " ╔═════════════════════════════════════════════════════════════════╗"
    panel " ║ 1. Azure Clang 15.x                                             ║"
    panel " ║ 2. AOSP  Clang 15.x                                             ║"
    panel " ║ 3. WeebX Clang 15.x                                             ║"
    panel " ║ 4. WeebX Clang 14.x                                             ║"
    panel " ║ 5. Snapdragon Clang 14.x                                        ║"
    panel " ║ 6. Proton Clang 13.x                                            ║"
    panel " ║ s. Skip Menu                                                    ║"
    panel " ╚═════════════════════════════════════════════════════════════════╝"
    panel2 " Enter your choice 1-6, or press 's' for skip this Menu : "

    read -r tc

	# Your choise
	if [[ "${tc}" == "1" ]]; then
		msg "* Clone Azure Clang 15.x"
		clear_clang
		echo "clang" > toolchain.txt
		git clone --depth=1 https://gitlab.com/Panchajanya1999/azure-clang.git clang
	elif [[ "${tc}" == "2" ]]; then
		msg "* Clone AOSP Clang 15.x"
		clear_clang
		echo "aosp" > toolchain.txt
		AOSP_VER="r458507"
    	wget https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/master/clang-"${AOSP_VER}".tar.gz -O "aosp-clang.tar.gz"
    	mkdir clang && tar -xf aosp-clang.tar.gz -C clang && rm -rf aosp-clang.tar.gz
    	git clone --depth=1 https://github.com/XSans0/aarch64-linux-android-4.9 arm64
    	git clone --depth=1 https://github.com/XSans0/arm-linux-androideabi-4.9 arm32
	elif [[ "${tc}" == "3" ]]; then
		msg "* Clone WeebX Clang 15.x"
		clear_clang
		echo "clang" > toolchain.txt
		git clone -b release/15-gr --depth=1 https://gitlab.com/XSans0/weebx-clang.git clang
	elif [[ "${tc}" == "4" ]]; then
		msg "* Clone WeebX Clang 14.x"
		clear_clang
		echo "clang" > toolchain.txt
		git clone --depth=1 https://gitlab.com/XSans0/weebx-clang.git clang
	elif [[ "${tc}" == "5" ]]; then
		msg "* Clone Snapdragon Clang 14.x"
		clear_clang
		echo "sdclang" > toolchain.txt
		git clone --depth=1 -b 14 https://github.com/ThankYouMario/proprietary_vendor_qcom_sdclang.git clang
		git clone --depth=1 https://github.com/XSans0/aarch64-linux-android-4.9 arm64
    	git clone --depth=1 https://github.com/XSans0/arm-linux-androideabi-4.9 arm32
	elif [[ "${tc}" == "6" ]]; then
		msg "* Clone Proton Clang 13.x"
		echo "clang" > toolchain.txt
		clear_clang
		git clone --depth=1 https://github.com/kdrag0n/proton-clang.git clang
	elif [[ "${tc}" == "s" ]]; then
		# include files
		msg "* Skip this menu"
		sleep 10
		source build.sh
	fi
done