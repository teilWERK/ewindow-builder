
targetdir="$(pwd)"/rootfs
img=alpine-x64.img
apkovl=ewindow.apkovl.tar.gz

tar czf $apkovl etc

create_image_file() {
	dd if=/dev/zero of="$img" bs=1024 count=1000000
	cat << EOF | fdisk $img
		n
		p
		1

		+100M
		n
		p
		2


		a
		1
		p
		w
		q
EOF
}

prepare() {
	if [ ! -f "$img" ]; then create_image_file; fi
	mdev -s
	kpartx -av "$img"
	mdev -s
	mkfs.vfat /dev/mapper/loop0p1
	mkfs.ext4 -F /dev/mapper/loop0p2
	mount /dev/mapper/loop0p2 "$targetdir"
	mkdir -p "$targetdir"/boot
	mount /dev/mapper/loop0p1 "$targetdir"/boot
}

cleanup() {
	umount $targetdir/dev
	umount $targetdir/proc
	umount $targetdir/sys
	umount $targetdir/boot
	umount $targetdir
	dmsetup remove_all
	losetup -D
}

install() {
	pkgs="alpine-base linux-vanilla ewindowui"

        # apk reads config from target root so we need to copy the config
        mkdir -p "$targetdir"/etc/apk/keys/
        cp /etc/apk/keys/* "$targetdir"/etc/apk/keys/

        local repos=$(sed -e 's/\#.*//' /etc/apk/repositories)
        local repoflags=
        for i in $repos; do
                repoflags="$repoflags --repository $i"
        done
	
	apkflags="--initdb --progress --cache-dir /var/cache/apk"
	#--update-cache --clean-protected
	apk add --root "$targetdir" $apkflags --overlay-from-stdin \
            $repoflags $pkgs </tmp/ovlfiles
}

doit() {
	prepare || exit 1
	#install
	./setup-disk -k vanilla -o $apkovl -s 0 "$targetdir"
#	chroot "$targetdir" /sbin/update-extlinux
	syslinux -i /dev/mapper/loop0p1
	dd if=/usr/share/syslinux/mbr.bin of="$img" conv=notrunc
	cleanup
}

case $1 in
	cleanup) cleanup;;
	prepare) prepare;;
	*) doit
esac
