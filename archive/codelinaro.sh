#!/usr/bin/env bash

# Codelinaro Tags
TAG="Give your tag here"

# wlan
patch=('qcacld-3.0' 'fw-api' 'qca-wifi-host-cmn')
for patch in "${patch[@]}"; do
    git fetch https://git.codelinaro.org/clo/la/platform/vendor/qcom-opensource/wlan/"$patch" "$TAG"
    git merge -X subtree=drivers/staging/"$patch" FETCH_HEAD --signoff --log=999
done

# data-kernel
git fetch https://git.codelinaro.org/clo/la/platform/vendor/qcom-opensource/data-kernel "$TAG"
git merge -X subtree=techpack/data FETCH_HEAD --signoff --log=999

# data-audio
git fetch https://git.codelinaro.org/clo/la/platform/vendor/opensource/audio-kernel "$TAG"
git merge -X subtree=techpack/audio FETCH_HEAD --signoff --log=999

# msm-4.14
git fetch https://git.codelinaro.org/clo/la/kernel/msm-4.14 "$TAG"
git merge --signoff --log=999 FETCH_HEAD