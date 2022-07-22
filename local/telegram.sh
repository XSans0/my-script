#!/usr/bin/env bash
# Copyright ©2022 XSans02
# Telegram Setup
git clone --depth=1 https://github.com/XSans0/Telegram Telegram

TELEGRAM=Telegram/telegram
function send_msg() {
  "${TELEGRAM}" -c "${CHANNEL_ID}" -H -D \
      "$(
          for POST in "${@}"; do
              echo "${POST}"
          done
      )"
}

function send_file() {
  "${TELEGRAM}" -f "$(echo "$AK3_DIR"/*.zip)" \
  -c "${CHANNEL_ID}" -H \
      "$1"
}

function send_log() {
  "${TELEGRAM}" -f "$(echo "$KERNEL_LOG")" \
  -c "${CHANNEL_ID}" -H \
      "$1"
}
function start_msg() {
    send_msg "<b>New Kernel On The Way</b>" \
                 "<b>==================================</b>" \
                 "<b>Device : </b>" \
                 "<code>* $CODENAME</code>" \
                 "<b>Branch : </b>" \
                 "<code>* $BRANCH</code>" \
                 "<b>Build Using : </b>" \
                 "<code>* $CPU $CORES thread</code>" \
                 "<b>Last Commit : </b>" \
                 "<code>* $COMMIT</code>" \
                 "<b>==================================</b>"
}
function end_msg() {
    send_msg "<b>Build Successfully</b>" \
                 "<b>==================================</b>" \
                 "<b>Build Date : </b>" \
                 "<code>* $(date +"%A, %d %b %Y, %H:%M:%S")</code>" \
                 "<b>Build Took : </b>" \
                 "<code>* $(("$TOTAL_TIME" / 60)) Minutes, $(("$TOTAL_TIME" % 60)) Second.</code>" \
                 "<b>Compiler : </b>" \
                 "<code>* $KBUILD_COMPILER_STRING</code>" \
                 "<b>==================================</b>"
}