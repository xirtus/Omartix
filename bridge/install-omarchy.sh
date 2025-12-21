#!/bin/bash
set -e

# Configuration
INSTALL_DIR="$(dirname "$(realpath "$0")")"
OMARCHY_ROOT="$(realpath "$INSTALL_DIR/../../omarchy-config")"
SHIM_PATH="$INSTALL_DIR/systemctl-shim"

echo "=== Omarchy for Artix (runit) Installer ==="
echo "Working directory: $INSTALL_DIR"
echo "Omarchy source: $OMARCHY_ROOT"

if [ ! -d "$OMARCHY_ROOT" ]; then
    echo "Error: Could not find 'omarchy-config' directory at $OMARCHY_ROOT"
    exit 1
fi

# 1. Patch Packages
echo ">> Step 1: Patching packages..."
cd "$INSTALL_DIR/.." # Go to base-install (parent of bridge) then up to root? No.
# bridge is at repo/bridge. base-install is at repo/base-install.
# patch-packages.sh is in the SAME dir as this script (bridge/).
./patch-packages.sh

# 2. Setup Systemctl Shim
echo ">> Step 2: Installing systemctl shim..."
sudo cp "$SHIM_PATH" /usr/local/bin/systemctl
sudo chmod +x /usr/local/bin/systemctl
# Safety link for scripts using absolute path /usr/bin/systemctl
sudo ln -sf /usr/local/bin/systemctl /usr/bin/systemctl
echo "Shim installed to /usr/local/bin/systemctl and /usr/bin/systemctl"

# 3. Pre-install critical services
echo ">> Step 3: Installing critical Artix services..."
# Update keyrings first to avoid signature errors
sudo pacman -Sy --noconfirm artix-keyring archlinux-keyring
# -Sy is important to ensure we can find packages on a fresh install
sudo pacman -S --noconfirm --needed \
    base-devel git \
    elogind-runit \
    networkmanager networkmanager-runit \
    bluez bluez-runit \
    cups cups-runit \
    docker docker-runit \
    avahi avahi-runit

# 4. Patch Omarchy Scripts (Runtime)
echo ">> Step 4: Patching Omarchy scripts for incompatibility..."
# Replace systemd-networkd checks with NetworkManager
find "$OMARCHY_ROOT" -type f -name "*.sh" -print0 | xargs -0 sed -i 's/systemd-networkd/NetworkManager/g' || true
find "$OMARCHY_ROOT" -type f -name "*.sh" -print0 | xargs -0 sed -i 's/systemd-resolved/NetworkManager/g' || true

# 5. Run Omarchy Installer
echo ">> Step 5: Running Omarchy Installer..."
cd "$OMARCHY_ROOT"
./install.sh

echo "=== Installation Complete ==="
echo "Note: Services have been linked to /etc/runit/runsvdir/default/"
echo "Please reboot to ensure all runit services start correctly."