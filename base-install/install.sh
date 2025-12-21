#!/bin/bash
set -e

# Ensure we are running from the script's directory
cd "$(dirname "$(realpath "$0")")"

echo "=== Artix Linux Installer (BTRFS + LUKS + Limine) ==="

# --- Disk Selection ---
echo "Available Disks:"
lsblk -d -n -o NAME,SIZE,MODEL | grep -v "loop" | grep -v "sr0"
echo ""
read -p "Enter target disk (e.g., nvme0n1 or sda): " DISK_NAME

# Sanitize input
DISK_NAME=$(echo "$DISK_NAME" | tr -d ' /dev/')
DISK="/$DISK_NAME"

if [ ! -b "$DISK" ]; then
    echo "Error: Device $DISK not found."
    exit 1
fi

echo ">> TARGET: $DISK"
echo "WARNING: ALL DATA ON $DISK WILL BE ERASED."
read -p "Type 'yes' to confirm: " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# --- Feature Selection ---
echo "------------------------------------------------"
echo ">> Feature Selection"
echo "------------------------------------------------"

# 1. NVIDIA
read -p "Do you have an NVIDIA GPU and want proprietary drivers? [y/N]: " NVIDIA_ASK
if [[ "$NVIDIA_ASK" =~ ^[Yy]$ ]]; then
    echo ">> NVIDIA drivers will be installed."
    touch /tmp/.nvidia_install
else
    echo ">> Skipping NVIDIA drivers (using open source)."
fi

# 2. ZRAM (Swap)
read -p "Enable ZRAM (Compressed RAM Swap)? Recommended for most PCs. [Y/n]: " ZRAM_ASK
ZRAM_ASK=${ZRAM_ASK:-Y} # Default Yes
if [[ "$ZRAM_ASK" =~ ^[Yy]$ ]]; then
    echo ">> ZRAM will be configured."
    touch /tmp/.zram_install
else
    echo ">> Skipping ZRAM."
fi

# --- Optimization & Fixes ---
echo ">> Enabling Parallel Downloads..."
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

echo ">> Updating Keyrings (Prevents GPG errors)..."
pacman -Sy --noconfirm artix-keyring archlinux-keyring || echo "Warning: Keyring update failed, hoping for the best..."

# --- Partitioning ---
echo ">> Partitioning $DISK..."
# Zap disk
wipefs -a "$DISK"
# Define Partitions (Robust Logic)
# If disk name ends in a digit (nvme0n1, mmcblk0), partitions are p1, p2
# If disk name ends in a letter (sda, vda), partitions are 1, 2
if [[ "$DISK_NAME" =~ [0-9]$ ]]; then
    EFI_PART="${DISK}p1"
    ROOT_PART="${DISK}p2"
else
    EFI_PART="${DISK}1"
    ROOT_PART="${DISK}2"
fi

echo ">> Partitions: EFI=$EFI_PART, ROOT=$ROOT_PART"

# --- Formatting & Mounting ---
echo ">> Formatting EFI..."
mkfs.fat -F32 "$EFI_PART"

echo ">> Encryption Setup..."
echo "NOTE: If prompted 'Are you sure?', you must type 'YES' in UPPERCASE."
./luks.sh "$ROOT_PART"

echo ">> BTRFS Setup..."
./btrfs-layout.sh /dev/mapper/cryptroot

echo ">> Mounting Boot..."
mount "$EFI_PART" /mnt/boot

# --- Installation ---
echo ">> Installing Base System..."
# Include microcode and useful tools immediately
basestrap /mnt base base-devel runit elogind-runit linux linux-firmware \
    intel-ucode amd-ucode nano git

echo ">> Generating Fstab..."
fstabgen -U /mnt >> /mnt/etc/fstab

# --- Configuration Phase ---
echo ">> Preparing Chroot..."
cp chroot-setup.sh /mnt/root/
chmod +x /mnt/root/chroot-setup.sh

# Pass feature flags to chroot
if [ -f /tmp/.nvidia_install ]; then touch /mnt/.nvidia_install; fi
if [ -f /tmp/.zram_install ]; then touch /mnt/.zram_install; fi

echo "------------------------------------------------"
echo "Entering Chroot. Follow the prompts inside."
echo "------------------------------------------------"
artix-chroot /mnt /root/chroot-setup.sh

# --- Bootloader Install (UEFI ONLY) ---
echo ">> Bootloader Setup..."
# No need to run limine-install for UEFI. The EFI binary is copied in chroot-setup.sh.

# --- Limine Config ---
echo ">> Generating Limine Config..."
ROOT_UUID=$(blkid -s UUID -o value /dev/mapper/cryptroot)
LUKS_UUID=$(blkid -s UUID -o value "$ROOT_PART")

# Limine searches for limine.cfg in /limine/ relative to the boot partition
mkdir -p /mnt/boot/limine

cat <<EOF > /mnt/boot/limine/limine.cfg
TIMEOUT=5
DEFAULT_ENTRY=Artix Linux

:Artix Linux
    PROTOCOL=linux
    KERNEL_PATH=boot:///vmlinuz-linux
    # Microcode loading
    MODULE_PATH=boot:///intel-ucode.img
    MODULE_PATH=boot:///amd-ucode.img
    MODULE_PATH=boot:///initramfs-linux.img
    
    CMDLINE=cryptdevice=UUID=$LUKS_UUID:cryptroot root=UUID=$ROOT_UUID rootflags=subvol=@ rw quiet
EOF

# --- Persistence (Copy Installer to Target) ---
echo ">> Copying installer to target system..."
REPO_ROOT="$(dirname "$(pwd)")"

# Detect the user home (it will be the only folder in /mnt/home besides lost+found)
REAL_USER=$(ls /mnt/home | grep -v "lost+found" | grep -v "artix-installer" | head -n 1)

if [ -n "$REAL_USER" ]; then
    TARGET_HOME="/mnt/home/$REAL_USER/artix-installer"
    cp -r "$REPO_ROOT" "$TARGET_HOME"
    chown -R 1000:1000 "$TARGET_HOME"
    FINAL_MSG="cd ~/artix-installer/bridge && ./install-omarchy.sh"
else
    # Fallback if user detection failed
    cp -r "$REPO_ROOT" "/mnt/home/artix-installer"
    chown -R 1000:1000 "/mnt/home/artix-installer"
    FINAL_MSG="cd /home/artix-installer/bridge && ./install-omarchy.sh"
fi

echo "------------------------------------------------"
echo "=== INSTALLATION COMPLETE! ==="
echo "------------------------------------------------"
echo "1. Reboot your system."
echo "2. Login with your user."
echo "3. CONNECT TO THE INTERNET (WiFi/Ethernet) <- CRITICAL!"
echo "   - Ethernet: Should connect automatically."
echo "   - WiFi: Since we installed NetworkManager, run 'nmtui' to select"
echo "           your network visually. It's already included!"
echo "4. Run the following command to install Omarchy:"
echo ""
echo "   $FINAL_MSG"
echo ""
echo "UEFI System ready. Type 'reboot' to restart."
sync