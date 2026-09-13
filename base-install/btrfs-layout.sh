#!/bin/bash
# btrfs-layout.sh <device> — format as BTRFS and create the Omartix subvolume
# layout, then mount everything under /mnt.
set -e

DEVICE="$1"
MOUNT_OPTS="noatime,compress=zstd:1,ssd,space_cache=v2"

if [[ -z $DEVICE ]]; then
    echo "Usage: $0 /dev/mapper/device" >&2
    exit 1
fi

echo "Formatting $DEVICE as BTRFS..."
mkfs.btrfs -f "$DEVICE"

echo "Creating subvolumes..."
mount "$DEVICE" /mnt

btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

# Excluded from root snapshots.
btrfs subvolume create /mnt/@pkg     # pacman cache
btrfs subvolume create /mnt/@log     # system logs
btrfs subvolume create /mnt/@tmp     # temp files
btrfs subvolume create /mnt/@docker  # docker (No-COW)

# Disable copy-on-write for Docker subvolume (must be done while empty).
chattr +C /mnt/@docker

umount /mnt

echo "Mounting subvolumes..."
mount -o "$MOUNT_OPTS,subvol=@" "$DEVICE" /mnt

mkdir -p /mnt/{home,.snapshots,var/cache/pacman/pkg,var/log,var/tmp,var/lib/docker,boot}

mount -o "$MOUNT_OPTS,subvol=@home"      "$DEVICE" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$DEVICE" /mnt/.snapshots
mount -o "$MOUNT_OPTS,subvol=@pkg"       "$DEVICE" /mnt/var/cache/pacman/pkg
mount -o "$MOUNT_OPTS,subvol=@log"       "$DEVICE" /mnt/var/log
mount -o "$MOUNT_OPTS,subvol=@tmp"       "$DEVICE" /mnt/var/tmp
chmod 1777 /mnt/var/tmp
mount -o "$MOUNT_OPTS,subvol=@docker"    "$DEVICE" /mnt/var/lib/docker

echo "BTRFS layout applied."
