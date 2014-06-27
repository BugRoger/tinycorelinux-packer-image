#!/bin/bash

set -e

# Remastering TinyCore for Packer Usage
#
# This script will create a TinyCore ISO that is ready to be used in Packer. It is 
# an automated version of the guide at:
#
#   http://wiki.tinycorelinux.net/wiki:remastering
# 
# You need to run this on a system that has following commands available:
#   * unsquashfs (squashfs-tools)
#   * advdef (advancecomp) 
#   * mkisofs (mkisofs)
#
# Additional customizations can be added to the customize function.
#
# Feel free to include additional extension by adding them to the following array:

readonly EXTENSIONS=(bash openssh scsi-3.8.13-tinycore)

# Global variables
readonly MIRROR_URL=http://distro.ibiblio.org/tinycorelinux/5.x/x86
readonly DIST=./dist
readonly BUILD=./build
readonly DOWNLOADS=./downloads

main() {
  prepare
  explode_iso 
  download_extensions
  unpack_extensions
  customize_packer
  customize_scsi
  repack_core
  remaster_iso
  calculate_checksum
}

prepare() {
  rm -rf $DIST
  rm -rf $BUILD
  mkdir -p $DIST
  mkdir -p $BUILD

  [[ ! -d "$DOWNLOADS" ]] && mkdir -p $DOWNLOADS

  return 0
}

download() {
  local url=$1
  local file=$DOWNLOADS/${url##*/}

  if [[ ! -f "$file" ]]; then
    wget -q -P $DOWNLOADS $url 
  fi
}

download_tcz() {
  local tcz=$1
  local baseurl="$TINY_CORE_MIRROR_URL/tcz"
  local extension="$baseurl/$tcz"

  download "$extension"
  download "$extension.dep" || true

  if [[ -f "$tcz.dep" ]]; then
    for dep in $(cat $tcz.dep)
    do
      download_tcz $dep
    done
  fi
}

explode_iso() {
  local url=$MIRROR_URL/release/Core-current.iso
  local iso=$DOWNLOADS/${url##*/}
  local source=/mnt/tmp

  download $url

  [[ ! -d "$source" ]] && mkdir -p $source
  
  mount $iso $source -o loop,ro
  cp -a $source/boot $DIST
  zcat $DIST/boot/core.gz | (cd $BUILD && cpio -i -H newc -d)
  umount $source
}

download_extensions() {
  for extension in "${EXTENSIONS[@]}"
  do
    download_tcz "$extension.tcz"
  done
}

unpack_extensions() {
  for extension in $DOWNLOADS/*.tcz
  do
    unsquashfs -f -d $BUILD $extension
  done
}

repack_core() {
  ldconfig -r $BUILD
  (cd $BUILD && find | cpio -o -H newc | gzip -2 > ../core.gz)
  advdef -z4 core.gz
}

remaster_iso() {
  mv core.gz $DIST/boot
  mkisofs -l -J -R -V TC-custom -no-emul-boot -boot-load-size 4 \
    -boot-info-table -b boot/isolinux/isolinux.bin \
    -c boot/isolinux/boot.cat -o tinycore-packer.iso $DIST
}

calculate_checksum() {
  local md5=($(md5sum tinycore-packer.iso)) 

  echo "Remastering done. The md5 checksum of the new iso is: ${md5}"
}

customize_packer() {
  ( cd $BUILD/usr/local/etc/ssh \
      && mv sshd_config.example sshd_config \
      && sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' sshd_config
  )
  
  echo "packer:x:1002:50::/home/packer:/bin/sh" >> $BUILD/etc/passwd
  echo 'packer:$6$zHqBItBy$ysrNi5D/JwJNEsVI/5eA305vsA0GsWyT4.0K3AAL.R28TxioZRZD9yplyV5FwrIs0FJc5kS0M0/HHo2N4FBUk1:16240:0:999999:7:::' >> $BUILD/etc/shadow
  mkdir -p $BUILD/home/packer
  chown 1002:50 $BUILD/home/packer
  echo "packer	ALL=NOPASSWD: ALL" >> $BUILD/etc/sudoers
  sed -i 's/tty1::respawn:\/sbin\/getty -nl \/sbin\/autologin 38400 tty1/tty1::respawn:\/sbin\/getty 38400 tty1/' $BUILD/etc/inittab
  echo "/usr/local/etc/init.d/openssh start" >> $BUILD/opt/bootlocal.sh 
}

customize_scsi() {
  echo "depmod -a" >> $BUILD/opt/bootlocal.sh 
  echo "modprobe mptspi" >> $BUILD/opt/bootlocal.sh 
}

main
