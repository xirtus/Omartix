#!/bin/bash
# patch-packages.sh — install the Artix runit *service companion* packages for
# the Omarchy package list.
#
# Unlike the old version, this does NOT mutate the vendored omarchy-config
# package lists; those stay pristine so upstream can be re-synced. It installs
# the `-runit` init-script packages and the runit replacements for systemd
# daemons directly.
set -euo pipefail

echo ">> Installing Artix runit service companions..."

# Service packages that have a native `-runit` companion on Artix.
pacman -Sy --noconfirm artix-keyring archlinux-keyring 2>/dev/null || true
pacman -S --noconfirm --needed \
    dbus-runit \
    elogind-runit \
    networkmanager-runit \
    bluez bluez-runit \
    cups-runit \
    docker-runit \
    avahi-runit \
    iwd-runit \
    ufw-runit \
    sddm-runit \
    power-profiles-daemon-runit \
    fcron fcron-runit \
    earlyoom earlyoom-runit \
    2>/dev/null || echo "  (some companion packages were unavailable — continuing)"

# bluetoothd needs a hostname-aware /etc/bluetooth/... — nothing else required.
echo ">> Service companions installed."
