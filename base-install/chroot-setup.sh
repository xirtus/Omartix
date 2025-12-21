#!/bin/sh
set -e

# Configurable variables (defaults can be overridden by env vars)
TIMEZONE="${TIMEZONE:-Europe/Madrid}"
LOCALE="${LOCALE:-es_ES.UTF-8}"
HOSTNAME="${HOSTNAME:-artixbox}"
USERNAME="${USERNAME:-artixuser}"

echo "=== Chroot Setup ==="
echo "User: $USERNAME | Host: $HOSTNAME | Loc: $LOCALE"

# --- 1. Repositories (Multilib & Lib32) ---
echo ">> Configuring Repositories..."
# Enable Parallel Downloads
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Enable [lib32] (Artix equivalent of multilib)
# Remove comment from [lib32] and the Include line following it
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf

# Refresh DBs
pacman -Sy

echo ">> Setting timezone..."
ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
hwclock --systohc

echo ">> Setting locale..."
# Uncomment en_US and target locale
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
if [ "$LOCALE" != "en_US.UTF-8" ]; then
    sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen || echo "$LOCALE UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo ">> Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

echo ">> Configuring Network..."
# Enable NetworkManager (ensure it's installed first)
pacman -S --noconfirm --needed networkmanager networkmanager-runit
ln -sf /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/

echo ">> Setting root password..."
echo "Enter password for ROOT:"
passwd

echo ">> Creating user $USERNAME..."
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists."
else
    # Modern Arch/Artix: elogind handles audio/video. We only need wheel.
    useradd -m -G wheel,input "$USERNAME"
    echo "Enter password for USER $USERNAME:"
    passwd "$USERNAME"
fi

echo ">> Configuring sudo..."
pacman -S --noconfirm --needed sudo
# Uncomment wheel group
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

echo ">> Installing Bootloader & Tools..."
# Install microcode here if not done in base, plus Limine
pacman -S --noconfirm --needed limine efibootmgr btrfs-progs snapper cronie cronie-runit intel-ucode amd-ucode

# --- Feature: NVIDIA ---
if [ -f /.nvidia_install ]; then
    echo ">> Installing NVIDIA Drivers (DKMS)..."
    # linux-headers are required for dkms
    pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings linux-headers
    
    # Add nvidia modules to mkinitcpio
    # We replace the MODULES=() line
    sed -i 's/^MODULES=(.*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    
    # Add kernel parameter for DRM
    echo "options nvidia_drm modeset=1 fbdev=1" > /etc/modprobe.d/nvidia.conf
    
    rm /.nvidia_install
fi

# --- Feature: ZRAM ---
if [ -f /.zram_install ]; then
    echo ">> Configuring ZRAM..."
    # We only need the kernel module and standard tools (util-linux)
    # zram-generator package is useful for the config, but we will do manual init for runit
    pacman -S --noconfirm --needed zram-generator

    # Create a native runit service for ZRAM
    mkdir -p /etc/runit/sv/zram
    cat <<EOF > /etc/runit/sv/zram/run
#!/bin/sh
# 1. Load module (ensure 1 device exists)
modprobe zram num_devices=1

# 2. Reset if exists (safety)
zramctl --reset /dev/zram0 2>/dev/null || true

# 3. Setup (50% of RAM, zstd compression)
# zramctl finds the first free device (zram0) and initializes it
zramctl --find --size 50% --algorithm zstd --mkfs

# 4. Activate swap
mkswap /dev/zram0 >/dev/null
swapon /dev/zram0

# 5. Pause to keep service 'up'
exec chpst -b pause
EOF

    cat <<EOF > /etc/runit/sv/zram/finish
#!/bin/sh
# Cleanup on stop
swapoff /dev/zram0
zramctl --reset /dev/zram0
EOF

    chmod +x /etc/runit/sv/zram/run
    chmod +x /etc/runit/sv/zram/finish
    
    # Enable it
    ln -s /etc/runit/sv/zram /etc/runit/runsvdir/default/
    
    rm /.zram_install
fi

echo ">> Configuring mkinitcpio for LUKS/BTRFS..."
# Safe replacement for HOOKS
# We want: base udev autodetect keyboard keymap modconf block encrypt filesystems fsck
NEW_HOOKS="HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)"
sed -i "s/^HOOKS=.*/$NEW_HOOKS/" /etc/mkinitcpio.conf

echo ">> Generating initramfs..."
mkinitcpio -P

echo ">> Enabling Cron..."
ln -sf /etc/runit/sv/cronie /etc/runit/runsvdir/default/

# Enable weekly fstrim for SSD health
echo ">> Configuring SSD Trim..."
cat <<EOF > /etc/cron.weekly/fstrim
#!/bin/sh
fstrim -v /
EOF
chmod +x /etc/cron.weekly/fstrim

echo ">> Deploying Limine (UEFI)..."
mkdir -p /boot/EFI/BOOT
# We use the "Fallback" path (/EFI/BOOT/BOOTX64.EFI).
# This makes the drive bootable on any UEFI system without needing to register
# NVRAM variables with efibootmgr (which can be flaky in chroot).
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

echo "=== Chroot Setup Complete ==="
