# Maintainer: ghazzor <kartikhis8o@gmail.com>
pkgname=linux-xanmod-omen16-bin

download() {
  OWNER="stuffs"
  REPO="Xanmod-Kernel-Builder"
  RELEASE_JSON=$(curl -s "https://api.github.com/repos/${OWNER}/${REPO}/releases/latest")

  ASSET_URL=$(echo "${RELEASE_JSON}" | jq -r '.assets[].browser_download_url' | grep omen16.tar.xz)
  echo "$ASSET_URL"
  echo $PWD
  wget -nc ${ASSET_URL}
  tar xvf *.tar.xz
  export kver=$(basename tar-install/lib/modules/*xanmod1)
}

download

pkgver=$(echo $kver | cut -f1 -d'-')
pkgrel=1
pkgdesc='Pre-compiled Xanmod kernel with custom optimizations'
arch=('x86_64')
url="https://xanmod.org"
license=('GPL2')
depends=('coreutils' 'kmod' 'mkinitcpio')
optdepends=('linux-firmware: firmware for drivers'
            'grub: bootloader integration')
touch xanmod.install
install=xanmod.install

package() {
  cd ..
  echo $kver
  mkdir -p "${pkgdir}/usr/"
  cp -r "tar-install/lib/" "${pkgdir}/usr/"
  cp -r "tar-install/boot" "${pkgdir}/"
  cat << EOF > xanmod.install
post_install() {
  echo ">>> Generating initramfs for kernel: $kver"
  mkinitcpio -k $kver -g "/boot/initramfs-$kver.img"
  rm -f /boot/initramfs
  rm -f /boot/vmlinuz
  sudo ln -s /boot/initramfs-$kver-xanmod1.img /boot/initramfs
  sudo ln -sf /boot/vmlinuz-$kver /boot/vmlinuz
  sudo ln -sf /boot/initramfs-$kver.img /boot/initramfs

  echo ">>> Updating GRUB configuration"
  grub-mkconfig -o /boot/grub/grub.cfg
}

  post_upgrade() {
  post_install
}

post_remove() {
  echo ">>> Removing initramfs and updating GRUB..."
  rm -f /boot/initramfs-$kver.img
  rm -f /boot/initramfs
  grub-mkconfig -o /boot/grub/grub.cfg
}
EOF
  rm -rf tar-install
  rm -rf "${pkgdir}/usr/lib/modules/$kver/build"
  rm -rf "${pkgdir}/boot/vmlinux-$kver"
  rm -rf *.tar.gz
}
