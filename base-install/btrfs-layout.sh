#!/bin/sh
set -e

DEVICE=$1
# Optimized for desktop performance
MOUNT_OPTS="noatime,compress=zstd:1,ssd,space_cache=v2"

if [ -z "$DEVICE" ]; then
    echo "Usage: $0 /dev/mapper/device"
    exit 1
fi

echo "Formatting $DEVICE as BTRFS..."
mkfs.btrfs -f "$DEVICE"

echo "Creating subvolumes..."
mount "$DEVICE" /mnt

# Standard subvolumes
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots

# Exclude from root snapshots
btrfs subvolume create /mnt/@pkg     # Pacman cache
btrfs subvolume create /mnt/@log     # System logs
btrfs subvolume create /mnt/@tmp     # Temp files
btrfs subvolume create /mnt/@docker  # Docker/Containers (No CoW)

# Disable CoW for Docker subvolume (Must be done on the dir while empty)
chattr +C /mnt/@docker

umount /mnt

echo "Mounting subvolumes..."
# 1. Mount Root
mount -o "$MOUNT_OPTS,subvol=@" "$DEVICE" /mnt

# 2. Create Mount Points
mkdir -p /mnt/{home,.snapshots,var/cache/pacman/pkg,var/log,var/tmp,var/lib/docker,boot}

# 3. Mount Others
mount -o "$MOUNT_OPTS,subvol=@home"      "$DEVICE" /mnt/home
mount -o "$MOUNT_OPTS,subvol=@snapshots" "$DEVICE" /mnt/.snapshots
mount -o "$MOUNT_OPTS,subvol=@pkg"       "$DEVICE" /mnt/var/cache/pacman/pkg
mount -o "$MOUNT_OPTS,subvol=@log"       "$DEVICE" /mnt/var/log
mount -o "$MOUNT_OPTS,subvol=@tmp"       "$DEVICE" /mnt/var/tmp
chmod 1777 /mnt/var/tmp
mount -o "$MOUNT_OPTS,subvol=@docker"    "$DEVICE" /mnt/var/lib/docker

echo "BTRFS layout applied successfully."