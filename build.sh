#!/bin/bash

# Set trap for catching errors
set -eE
trap 'catch $? $LINENO' ERR

catch() {
    echo -e "❌ Build failed at line $2 with exit code $1"
    echo "Saving log and exiting gracefully..."
    exit $1
}

# Start logging
exec > >(tee build_raw.log | sed -u \
  -e "s/.*error.*/\&\/" \
  -e "s/.*warning.*/\&\/" \
  > build.log) 2>&1

export KBUILD_BUILD_USER=MondayNitro
export KBUILD_BUILD_HOST=1GMET0FC

export PATH=${PWD}/toolchain/bin:${PATH}
export AnyKernel3=AnyKernel3
export LLVM_DIR=${PWD}/toolchain/bin
export LLVM=1
export modpath=${AnyKernel3}/modules/vendor/lib/modules

export ARCH=arm64
export DEVICE=veux

if [[ -z "$1" || "$1" = "-c" ]]; then
    echo "Clean Build"
    rm -rf out
elif [ "$1" = "-d" ]; then
    echo "Dirty Build"
else
    echo "Error: Set $1 to -c or -d"
    exit 1
fi

ARGS="
ARCH=arm64
CC=clang
LLVM=1
LLVM_IAS=1
LD=${LLVM_DIR}/ld.lld
AR=${LLVM_DIR}/llvm-ar
NM=${LLVM_DIR}/llvm-nm
OBJCOPY=${LLVM_DIR}/llvm-objcopy
OBJDUMP=${LLVM_DIR}/llvm-objdump
READELF=${LLVM_DIR}/llvm-readelf
OBJSIZE=${LLVM_DIR}/llvm-size
STRIP=${LLVM_DIR}/llvm-strip
"

make ${ARGS} O=out veux_defconfig
make ${ARGS} O=out -j$(nproc --all)

# Clean Up
rm -rf ${modpath}/*
rm -rf ${AnyKernel3}/*

# Setup
mkdir -p ${AnyKernel3}
git clone --depth=1 https://github.com/MondayNitro/AnyKernel3 ${AnyKernel3}
rm -rf ${AnyKernel3}/.github
mkdir -p ${modpath}
kver=$(make kernelversion)
kmod=$(echo ${kver} | awk -F'.' '{print $3}')

# Copy stuff
cp out/.config ${AnyKernel3}/config
cp out/arch/arm64/boot/Image ${AnyKernel3}/Image
cp out/arch/arm64/boot/dtb.img ${AnyKernel3}/dtb
cp out/arch/arm64/boot/dtbo.img ${AnyKernel3}/dtbo.img

# Zip
cd ${AnyKernel3}
zip -r9 build.zip * -x .git README.md *placeholder
echo -e "✅ Build completed successfully!"
