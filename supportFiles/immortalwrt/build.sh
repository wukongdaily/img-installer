#!/bin/bash
# Based from https://willhaley.com/blog/custom-debian-live-environment/

set -e

echo "🔧 修复 buster 的源..."

cat > /etc/apt/sources.list <<EOF
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main
EOF

echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99no-check-valid-until

apt-get update

echo "🚀 开始执行 build.sh ..."

echo Install required tools
apt-get update
apt-get -y install debootstrap squashfs-tools xorriso isolinux syslinux-efi  grub-pc-bin grub-efi-amd64-bin mtools dosfstools parted

echo Create directory where we will make the image
mkdir -p $HOME/LIVE_BOOT

echo Install Debian
debootstrap --arch=amd64 --variant=minbase buster $HOME/LIVE_BOOT/chroot http://archive.debian.org/debian/

echo Copy supporting documents into the chroot
cp -v /supportFiles/installChroot.sh $HOME/LIVE_BOOT/chroot/installChroot.sh
cp -v /supportFiles/immortalwrt/ddd $HOME/LIVE_BOOT/chroot/usr/bin/ddd
chmod +x $HOME/LIVE_BOOT/chroot/usr/bin/ddd
cp -v /supportFiles/sources.list $HOME/LIVE_BOOT/chroot/etc/apt/sources.list

echo Mounting dev / proc / sys
mount -t proc none $HOME/LIVE_BOOT/chroot/proc
mount -o bind /dev $HOME/LIVE_BOOT/chroot/dev
mount -o bind /sys $HOME/LIVE_BOOT/chroot/sys

echo Run install script inside chroot
chroot $HOME/LIVE_BOOT/chroot /installChroot.sh

echo Cleanup chroot
rm -v $HOME/LIVE_BOOT/chroot/installChroot.sh
mv -v $HOME/LIVE_BOOT/chroot/packages.txt /output/packages.txt

echo Copy in systemd-networkd config
cp -v /supportFiles/99-dhcp-en.network $HOME/LIVE_BOOT/chroot/etc/systemd/network/99-dhcp-en.network
chown -v root:root $HOME/LIVE_BOOT/chroot/etc/systemd/network/99-dhcp-en.network
chmod -v 644 $HOME/LIVE_BOOT/chroot/etc/systemd/network/99-dhcp-en.network

echo Enable autologin
mkdir -p -v $HOME/LIVE_BOOT/chroot/etc/systemd/system/getty@tty1.service.d/
cp -v /supportFiles/override.conf $HOME/LIVE_BOOT/chroot/etc/systemd/system/getty@tty1.service.d/override.conf

echo Unmounting dev / proc / sys
umount $HOME/LIVE_BOOT/chroot/proc
umount $HOME/LIVE_BOOT/chroot/dev
umount $HOME/LIVE_BOOT/chroot/sys

echo Create directories that will contain files for our live environment files and scratch files.
mkdir -p $HOME/LIVE_BOOT/{staging/{EFI/boot,boot/grub/x86_64-efi,isolinux,live},tmp}

echo Compress the chroot environment into a Squash filesystem.
cp /mnt/immortalwrt.img ${HOME}/LIVE_BOOT/chroot/mnt/
ls ${HOME}/LIVE_BOOT/chroot/mnt/
mksquashfs $HOME/LIVE_BOOT/chroot $HOME/LIVE_BOOT/staging/live/filesystem.squashfs -e boot

echo Copy kernel and initrd
cp -v $HOME/LIVE_BOOT/chroot/boot/vmlinuz-* $HOME/LIVE_BOOT/staging/live/vmlinuz
cp -v $HOME/LIVE_BOOT/chroot/boot/initrd.img-* $HOME/LIVE_BOOT/staging/live/initrd

echo Copy boot config files
cp -v /supportFiles/immortalwrt/isolinux.cfg $HOME/LIVE_BOOT/staging/isolinux/isolinux.cfg
cp -v /supportFiles/immortalwrt/grub.cfg $HOME/LIVE_BOOT/staging/boot/grub/grub.cfg
cp -v /supportFiles/grub-standalone.cfg $HOME/LIVE_BOOT/tmp/grub-standalone.cfg
touch $HOME/LIVE_BOOT/staging/DEBIAN_CUSTOM

echo Copy boot images
cp -v /usr/lib/ISOLINUX/isolinux.bin "${HOME}/LIVE_BOOT/staging/isolinux/"
cp -v /usr/lib/syslinux/modules/bios/* "${HOME}/LIVE_BOOT/staging/isolinux/"
cp -v -r /usr/lib/grub/x86_64-efi/* "${HOME}/LIVE_BOOT/staging/boot/grub/x86_64-efi/"

echo Make UEFI grub files
grub-mkstandalone --format=x86_64-efi --output=$HOME/LIVE_BOOT/tmp/bootx64.efi --locales=""  --fonts="" "boot/grub/grub.cfg=$HOME/LIVE_BOOT/tmp/grub-standalone.cfg"

cd $HOME/LIVE_BOOT/staging/EFI/boot
SIZE=`expr $(stat --format=%s $HOME/LIVE_BOOT/tmp/bootx64.efi) + 65536`
dd if=/dev/zero of=efiboot.img bs=$SIZE count=1
/sbin/mkfs.vfat efiboot.img
mmd -i efiboot.img efi efi/boot
mcopy -vi efiboot.img $HOME/LIVE_BOOT/tmp/bootx64.efi ::efi/boot/

echo Build ISO
xorriso \
    -as mkisofs \
    -iso-level 3 \
    -o "${HOME}/LIVE_BOOT/debian-custom.iso" \
    -full-iso9660-filenames \
    -volid "DEBIAN_CUSTOM" \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-boot \
        isolinux/isolinux.bin \
        -no-emul-boot \
        -boot-load-size 4 \
        -boot-info-table \
        --eltorito-catalog isolinux/isolinux.cat \
    -eltorito-alt-boot \
        -e /EFI/boot/efiboot.img \
        -no-emul-boot \
        -isohybrid-gpt-basdat \
    -append_partition 2 0xef ${HOME}/LIVE_BOOT/staging/EFI/boot/efiboot.img \
    "${HOME}/LIVE_BOOT/staging"

echo Copy output
cp -v $HOME/LIVE_BOOT/debian-custom.iso /output/immortalwrt-installer-x86_64.iso
chmod -v 666 /output/immortalwrt-installer-x86_64.iso
ls -lah /output
