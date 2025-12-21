#!/bin/bash
set -e

# Relative to where this script is run (inside bridge/)
OMARCHY_DIR="../omarchy-config"
PKG_FILE="$OMARCHY_DIR/install/omarchy-base.packages"

echo "Patching Omarchy package list for Artix (runit)..."

# Helper to swap packages
# We use a loose regex (word boundaries) to match packages inside a list
swap_pkg() {
    local old=$1
    local new=$2
    sed -i "s/\b$old\b/$new/g" "$PKG_FILE"
}

# Ensure the file exists
if [ ! -f "$PKG_FILE" ]; then
    echo "Error: $PKG_FILE not found."
    exit 1
fi

# --- Swaps ---
# Add runit companions or swap completely
swap_pkg "cups" "cups cups-runit"
swap_pkg "docker" "docker docker-runit"
swap_pkg "avahi" "avahi avahi-runit"
swap_pkg "iwd" "iwd iwd-runit"
swap_pkg "ufw" "ufw ufw-runit"
swap_pkg "bluez" "bluez bluez-runit"
swap_pkg "sddm" "sddm sddm-runit"
swap_pkg "power-profiles-daemon" "power-profiles-daemon power-profiles-daemon-runit"

# Remove systemd specific packages if they exist (delete lines starting with systemd)
sed -i '/systemd/d' "$PKG_FILE"

# Add NetworkManager if not present
if ! grep -q "networkmanager" "$PKG_FILE"; then
    echo "networkmanager" >> "$PKG_FILE"
    echo "networkmanager-runit" >> "$PKG_FILE"
fi

echo "Package list patched."