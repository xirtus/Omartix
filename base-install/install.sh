#!/bin/bash
# Omartix — Phase 1: base Artix Linux (runit) install.
#
# Boot the Artix *runit* ISO, connect to the network, then run:
#   ./install.sh
#
# This partitions and formats the disk (LUKS2 + BTRFS), installs a minimal
# Artix runit base, configures the bootloader, and copies this repository to
# the new system so Phase 2 (bridge/install-omarchy.sh) can be run after reboot.
set -e

cd "$(dirname "$(realpath "$0")")"
REPO_ROOT="$(realpath "$(dirname "$PWD")")"

echo "=== Omartix installer — Artix Linux (runit) + BTRFS + LUKS + Limine ==="

# --- Disk selection ------------------------------------------------------
echo "Available disks:"
lsblk -d -n -o NAME,SIZE,MODEL | grep -v -E 'loop|sr0'
echo ""
read -rp "Enter target disk (e.g. nvme0n1 or sda): " DISK_NAME

DISK_NAME=$(echo "$DISK_NAME" | tr -d ' /dev/')
DISK="/dev/$DISK_NAME"

if [[ ! -b $DISK ]]; then
    echo "Error: device $DISK not found." >&2
    exit 1
fi

echo ">> TARGET: $DISK"
echo "WARNING: ALL DATA ON $DISK WILL BE ERASED."
read -rp "Type 'yes' to confirm: " CONFIRM
[[ $CONFIRM == "yes" ]] || { echo "Aborted."; exit 1; }

# --- Feature selection ---------------------------------------------------
echo ""
echo ">> Feature selection"
read -rp "NVIDIA GPU — install proprietary drivers? [y/N]: " NVIDIA_ASK
[[ $NVIDIA_ASK =~ ^[Yy]$ ]] && touch /tmp/.nvidia_install

read -rp "Enable ZRAM (compressed swap)? Recommended. [Y/n]: " ZRAM_ASK
ZRAM_ASK=${ZRAM_ASK:-Y}
[[ $ZRAM_ASK =~ ^[Yy]$ ]] && touch /tmp/.zram_install

# --- Pacman prep ---------------------------------------------------------
echo ">> Enabling ParallelDownloads..."
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

echo ">> Updating keyrings (prevents GPG signature errors)..."
pacman -Sy --noconfirm artix-keyring archlinux-keyring 2>/dev/null || \
    echo "Warning: keyring update failed, continuing..."

# --- Partitioning --------------------------------------------------------
echo ">> Partitioning $DISK..."
wipefs -a "$DISK"
# NVMe/eMMC (nvme0n1, mmcblk0) use p1/p2; SATA/virtio (sda, vda) use 1/2.
if [[ $DISK_NAME =~ [0-9]$ ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

# GPT: 512 MiB EFI system partition + the rest as LUKS root.
sgdisk -Z "$DISK"
sgdisk -n 1:0:+512M -t 1:ef00 "$DISK"
sgdisk -n 2:0:0   -t 2:8309 "$DISK"    # 8309 = Linux LUKS
partprobe "$DISK" 2>/dev/null || true
sleep 1

echo ">> Partitions: EFI=$EFI_PART, ROOT=$ROOT_PART"

# --- Formatting ----------------------------------------------------------
echo ">> Formatting EFI..."
mkfs.fat -F32 "$EFI_PART"

echo ">> Encryption setup (type 'YES' in UPPERCASE if prompted)..."
./luks.sh "$ROOT_PART"

echo ">> BTRFS layout..."
./btrfs-layout.sh /dev/mapper/cryptroot

echo ">> Mounting boot..."
mkdir -p /mnt/boot
mount "$EFI_PART" /mnt/boot

# --- Base install --------------------------------------------------------
echo ">> Installing base system..."
basestrap /mnt base base-devel runit elogind-runit dbus-runit \
    linux linux-firmware intel-ucode amd-ucode \
    nano git networkmanager networkmanager-runit \
    btrfs-progs cryptsetup limine efibootmgr snapper fcron fcron-runit

echo ">> Generating fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab

# --- Chroot configuration ------------------------------------------------
echo ">> Preparing chroot..."
cp chroot-setup.sh /mnt/root/
chmod +x /mnt/root/chroot-setup.sh

[[ -f /tmp/.nvidia_install ]] && touch /mnt/.nvidia_install
[[ -f /tmp/.zram_install ]] && touch /mnt/.zram_install

echo ">> Entering chroot..."
artix-chroot /mnt /root/chroot-setup.sh

# --- Bootloader ----------------------------------------------------------
echo ">> Writing Limine config..."
ROOT_UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot)
LUKS_UUID=$(blkid -s UUID -o value "$ROOT_PART")

mkdir -p /mnt/boot/limine

{
  echo "TIMEOUT=5"
  echo "DEFAULT_ENTRY=Artix Linux"
  echo ""
  echo ":Artix Linux"
  echo "    PROTOCOL=linux"
  echo "    KERNEL_PATH=boot:///vmlinuz-linux"
  [[ -f /mnt/boot/intel-ucode.img ]] && echo "    MODULE_PATH=boot:///intel-ucode.img"
  [[ -f /mnt/boot/amd-ucode.img ]]  && echo "    MODULE_PATH=boot:///amd-ucode.img"
  echo "    MODULE_PATH=boot:///initramfs-linux.img"
  echo ""
  echo "    CMDLINE=cryptdevice=UUID=$LUKS_UUID:cryptroot root=UUID=$ROOT_UUID rootflags=subvol=@ rw quiet"
} > /mnt/boot/limine/limine.cfg

# --- Persist the installer for Phase 2 -----------------------------------
echo ">> Copying installer to the new system..."
TARGET_HOME="/mnt/home/artix-installer"
if [[ -d /mnt/home ]]; then
    REAL_USER=$(ls /mnt/home | grep -v -E 'lost\+found|artix-installer' | head -n1)
    [[ -n $REAL_USER ]] && TARGET_HOME="/mnt/home/$REAL_USER/artix-installer"
fi

mkdir -p "$TARGET_HOME"
cp -a "$REPO_ROOT"/. "$TARGET_HOME"/
chown -R 1000:1000 "$TARGET_HOME"

echo ""
echo "=== BASE INSTALL COMPLETE ==="
echo "1. Reboot (type 'reboot'), remove the USB drive."
echo "2. Log in as your user."
echo "3. Connect to the network:"
echo "     Ethernet: should connect automatically."
echo "     WiFi:     run 'nmtui' (NetworkManager is already installed)."
echo "4. Install Omarchy (Phase 2):"
echo ""
echo "     cd ~/artix-installer/bridge && ./install-omarchy.sh"
echo ""
sync
