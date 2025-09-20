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
# disable -O3 from arch/x86
sed -i 's/-O3/-O2/g' arch/x86/Makefile
sed -i 's/-Copt-level=3/-Copt-level=2/g' arch/x86/Makefile

if [ "$1" = "-d" ]; then
	echo "dirty"
else
	echo "cleaning" && make clean
fi

export KERNEL_VER_M=$(make kernelversion)
rm -rf vmlinux-gdb.py
ARGS='
LLVM=1
LLVM_IAS=1
LLVM_SUFFIX=${LLVM_S}
'
SECONDS=0
make ${ARGS} omen16_defconfig omen16.config
make ${ARGS} INSTALL_MOD_STRIP=1 dir-pkg -j$(nproc)
echo -e "\nCompleted in $((SECONDS / 60))m $((SECONDS % 60))s"
rm -rf tar-install/boot/vmlinux-*
tar c ./tar-install/ | xz -T0 > xanmod-${KERNEL_VER_M}${LLVM_VER}-omen16.tar.xz
