#!/bin/bash

init_var() {
	local var="$1"
	if [ -z "${!var}" ]; then
		export "$var"=$(grep "$var" build.config | cut -f2 -d'=')
	fi
	echo "$1=${!1}"
}

export ID_LIKE=$(grep ^ID_LIKE /etc/os-release | cut -d= -f2 | tr -d '"')

export LLVM_VER=-$(ls /usr/bin/clang* | cut -f4 -d'/' | grep -E '^clang-[0-9]+$' | awk -F'-' '{ if ($2 > max) max = $2 } END { print max }')
init_var KERNEL_VER
init_var LLVM_VER
init_var NVIDIA_VER

[[ "$ID_LIKE" == "debian" ]] && export LLVM_S=${LLVM_VER}

echo "HOST=$ID_LIKE"
[ ! -d kernel/xanmod ] && git clone --depth=1 https://gitlab.com/xanmod/linux -b ${KERNEL_VER} kernel/xanmod

cp config kernel/xanmod/arch/x86/configs/omen16_defconfig
cp omen16.config kernel/xanmod/arch/x86/configs/omen16.config
cp Kconfig.custom kernel/xanmod/
cp Makefile.custom kernel/xanmod/
cd kernel/xanmod
sed -i 's/KBUILD_CFLAGS += -O2/include \$(srctree)\/Makefile.custom/g' Makefile
echo 'source "Kconfig.custom"' >> Kconfig

if [ "$1" = "-d" ]; then
	echo "dirty"
else
	echo "cleaning" && rm -rf out/
fi

export KERNEL_VER_M=$(make kernelversion)
rm -rf vmlinux-gdb.py
ARGS="
LLVM=1
LLVM_IAS=1
LLVM_SUFFIX=${LLVM_S}
O=out
"

SECONDS=0
make ${ARGS} omen16_defconfig omen16.config
make ${ARGS} INSTALL_MOD_STRIP=1 dir-pkg -j$(nproc)
echo -e "\nCompleted in $((SECONDS / 60))m $((SECONDS % 60))s"

make ${ARGS} modules_prepare

cd ..

[ ! -d nvidia-open ] && \
git clone --depth=1 \
    --branch ${NVIDIA_VER} \
    https://github.com/NVIDIA/open-gpu-kernel-modules.git \
    nvidia-open

cd nvidia-open

KERNEL_SRC=$(realpath ../xanmod)
KERNEL_OUT=$(realpath ../xanmod/out)

make modules \
    SYSSRC="$KERNEL_SRC" \
    SYSOUT="$KERNEL_OUT" \
    CC=clang${LLVM_S} \
    -j$(nproc) \
    LD=ld.lld \
    AR=llvm-ar \
    NM=llvm-nm \
    OBJCOPY=llvm-objcopy \
    STRIP=llvm-strip \
    LLVM=1 \
    LLVM_IAS=1 \
    -j$(nproc)

STAGE="$KERNEL_OUT/tar-install"

make modules_install \
    SYSSRC="$KERNEL_SRC" \
    SYSOUT="$KERNEL_OUT" \
    INSTALL_MOD_PATH="$STAGE" \
    INSTALL_MOD_STRIP=1 \
    DEPMOD=/bin/true

cd ..

rm -rf ./xanmod/out/tar-install/boot/vmlinux-*

depmod \
    -b ./xanmod/out/tar-install \
    "${KERNEL_VER_M}-x64v3-xanmod1"

tar -C xanmod/out/ -c ./tar-install/ | xz -T0 > xanmod-${KERNEL_VER_M}${LLVM_VER}-omen16.tar.xz
