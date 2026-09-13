#!/bin/bash
# chroot-setup.sh — configures the freshly installed Artix (runit) base system.
# Run inside `artix-chroot /mnt` by install.sh. Root-owned configuration only;
# Omarchy itself is installed later by bridge/install-omarchy.sh (Phase 2).
set -e

# Overridable via environment (e.g. `artix-chroot /mnt env TIMEZONE=... /root/chroot-setup.sh`)
TIMEZONE="${TIMEZONE:-Europe/Madrid}"
LOCALE="${LOCALE:-en_US.UTF-8}"
HOSTNAME="${HOSTNAME:-omartix}"
USERNAME="${USERNAME:-omartix}"

echo "=== Omartix chroot setup ==="
echo "User: $USERNAME | Host: $HOSTNAME | Locale: $LOCALE | TZ: $TIMEZONE"

# --- Repositories --------------------------------------------------------
echo ">> Configuring repositories..."
sed -i 's/^#ParallelDownloads/ParallelDownloads/' /etc/pacman.conf

# Enable [lib32] (Artix multilib equivalent) so Steam/Wine work later.
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf

pacman -Sy

# --- Timezone / locale / hostname ----------------------------------------
echo ">> Setting timezone..."
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc

echo ">> Setting locale..."
sed -i 's/^#en_US.UTF-8/en_US.UTF-8/' /etc/locale.gen
if [[ $LOCALE != "en_US.UTF-8" ]]; then
    sed -i "s/^#$LOCALE/$LOCALE/" /etc/locale.gen || echo "$LOCALE UTF-8" >> /etc/locale.gen
fi
locale-gen
echo "LANG=$LOCALE" > /etc/locale.conf

echo ">> Setting hostname..."
echo "$HOSTNAME" > /etc/hostname

# --- Core services (runit) ----------------------------------------------
echo ">> Enabling core runit services..."
# Artix runit: a service is "enabled" by symlinking /etc/runit/sv/<name> into
# /etc/runit/runsvdir/default/.
enable_sv() {
    local name="$1"
    if [[ -d /etc/runit/sv/$name ]]; then
        ln -sf "/etc/runit/sv/$name" "/etc/runit/runsvdir/default/$name"
    else
        echo "  (skip) service '$name' not present"
    fi
}

enable_sv dbus
enable_sv elogind
enable_sv NetworkManager
enable_sv fcron
enable_sv dhcpcd

# --- Users / passwords ---------------------------------------------------
echo ">> Setting root password..."
passwd

echo ">> Creating user $USERNAME..."
if id "$USERNAME" &>/dev/null; then
    echo "User $USERNAME already exists."
else
    useradd -m -G wheel,input,audio,video "$USERNAME"
    echo "Enter password for USER $USERNAME:"
    passwd "$USERNAME"
fi

echo ">> Configuring sudo..."
pacman -S --noconfirm --needed sudo
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers

# --- Bootloader + tools --------------------------------------------------
echo ">> Installing bootloader tools..."
pacman -S --noconfirm --needed limine efibootmgr btrfs-progs snapper \
    intel-ucode amd-ucode

# --- NVIDIA (optional) ---------------------------------------------------
if [[ -f /.nvidia_install ]]; then
    echo ">> Installing NVIDIA drivers (DKMS)..."
    pacman -S --noconfirm --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings linux-headers
    sed -i 's/^MODULES=(.*)/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /etc/mkinitcpio.conf
    echo "options nvidia_drm modeset=1 fbdev=1" > /etc/modprobe.d/nvidia.conf
    rm -f /.nvidia_install
fi

# --- ZRAM (optional) -----------------------------------------------------
if [[ -f /.zram_install ]]; then
    echo ">> Configuring ZRAM (runit service)..."
    mkdir -p /etc/runit/sv/zram
    cat > /etc/runit/sv/zram/run <<'EOF'
#!/bin/sh
exec 2>&1
modprobe zram num_devices=1 2>/dev/null || true
zramctl --reset /dev/zram0 2>/dev/null || true
zramctl --find --size 50% --algorithm zstd 2>/dev/null || true
mkswap /dev/zram0 >/dev/null 2>&1 || true
swapon /dev/zram0 2>/dev/null || true
exec sleep infinity
EOF
    cat > /etc/runit/sv/zram/finish <<'EOF'
#!/bin/sh
exec 2>&1
swapoff /dev/zram0 2>/dev/null || true
zramctl --reset /dev/zram0 2>/dev/null || true
EOF
    chmod +x /etc/runit/sv/zram/run /etc/runit/sv/zram/finish
    ln -sf /etc/runit/sv/zram /etc/runit/runsvdir/default/zram
    rm -f /.zram_install
fi

# --- initramfs (LUKS + BTRFS) -------------------------------------------
echo ">> Configuring mkinitcpio for LUKS/BTRFS..."
sed -i "s/^HOOKS=.*/HOOKS=(base udev autodetect keyboard keymap modconf block encrypt filesystems fsck)/" /etc/mkinitcpio.conf

echo ">> Generating initramfs..."
mkinitcpio -P

# --- SSD trim (weekly) ---------------------------------------------------
echo ">> Configuring weekly SSD trim..."
mkdir -p /etc/cron.weekly
cat > /etc/cron.weekly/fstrim <<'EOF'
#!/bin/sh
fstrim -v /
EOF
chmod +x /etc/cron.weekly/fstrim

# --- Limine (UEFI fallback path) ----------------------------------------
echo ">> Deploying Limine (UEFI)..."
mkdir -p /boot/EFI/BOOT
# Fallback path (/EFI/BOOT/BOOTX64.EFI) boots on any UEFI system without
# registering NVRAM variables.
cp /usr/share/limine/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

echo "=== Chroot setup complete ==="
