#!/bin/sh

fail() {                                                                                                                                                        [39/1970]
  echo "$1" >&2
  sh
  exit 1
}

apk fix || fail "failed to install remaining packages"

device="/dev/vda"

[ -n "$device" ] || fail "No device specified"

(
  echo o # create a new empty DOS partition table

  echo n # add a new partition
    echo p # primary partition
    echo 1 # partition number
    echo 1 # first cylinder
    echo +64M # size 64M

  echo t # change a partition's system id
    echo c # Win95 FAT32 (LBA)

  echo a # toggle a bootable flag
    echo 1 # ... of partition 1

  echo n # create second (root) partition
    echo p # primary partition
    echo 2 # partition number
    echo  # default start
    echo  # default end (full disk)

  echo w # write table to disk and exit

) | fdisk "$device"

bootdev="$device"1
rootdev="$device"2

mkfs.vfat "$bootdev" || fail "Unable to create FAT partition"
mkfs.ext4 -F "$rootdev" || fail "Unable to create ext4 partition"

mountpoint=$(mktemp -d)

mount -t ext4 "$rootdev" "$mountpoint" || fail "Unable to mount root partition"
mkdir -p "$mountpoint"/boot
mount -t vfat "$bootdev" "$mountpoint"/boot || fail "Unable to mount boot partition"

setup-disk -k rpi2 -s 0 -o /etc/installee.apkovl.tar.gz "$mountpoint"/ || fail "Alpine install failed"

cp -r "$mountpoint/usr/lib/linux-rpi*/*" "$mountpoint/boot"

umount "$mountpoint"/boot || fail "Unable to umount partition"
umount "$mountpoint" || fail "Unable to umount partition"
rm -rf "$mountpoint"

poweroff
