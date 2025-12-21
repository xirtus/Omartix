#!/bin/sh
ROOT_DEV=$(findmnt -n -o SOURCE /)
ROOT_UUID=$(blkid -s UUID -o value "$ROOT_DEV")
OUT="/boot/limine/snapshots.cfg"

echo "# Snapshots BTRFS (autogenerado)" > "$OUT"

snapper -c root list | awk 'NR>2 {print $1}' | tail -n 5 | while read ID; do
cat <<EOF >> "$OUT"

:Snapshot $ID
    PROTOCOL=linux
    KERNEL_PATH=boot:///vmlinuz-linux
    INITRD_PATH=boot:///initramfs-linux.img
    CMDLINE=root=UUID=$ROOT_UUID rootflags=subvol=.snapshots/$ID/snapshot rw
EOF
done
