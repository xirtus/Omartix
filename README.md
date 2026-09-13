# OMARTIX = Artix Linux + Omarchy (Runit Edition)

<img width="1680" height="1184" alt="grok-image-0d33d396-38d9-4d9e-add9-fb214b225cfc" src="https://github.com/user-attachments/assets/60be1ca4-9def-4beb-991d-740dfa7fa0eb" />

This repository contains a complete installer to deploy **Artix Linux (Runit)** with an encrypted BTRFS filesystem (LUKS2) and automatically configure the **Omarchy** distribution.

## Project Structure

*   `base-install/`: Scripts to install the base Artix system (partitioning, encryption, kernel, bootloader).
*   `bridge/`: Compatibility layer to adapt Omarchy (originally Systemd-based) to Artix (Runit).
*   `omarchy-config/`: Original Omarchy configuration files and scripts.

## Installation Guide

### Prerequisites
1.  Boot using an Artix Linux ISO (the **runit** version).
2.  Active Internet connection (WiFi or Ethernet).
3.  Connected to a power source (if using a laptop).

### Step 1: Base System
1.  Clone this repository or copy the `artix-omarchy-repo` folder to the live system.
2.  Enter the base installation folder:
```bash
cd artix-omarchy-repo/base-install
```
3.  Run the master installer:
```bash
./install.sh
```
*   Follow the on-screen instructions to select the disk and set passwords. 
*   Once finished, type `reboot` and remove the USB drive.

### Step 2: Omarchy Installation
After rebooting and logging into your new Artix system (black screen/TTY):

1.  Clone or copy this repository again (since the disk was wiped). *   *Note: If you installed git in the previous step, you can clone it directly.*
2.  Navigate to the "bridge" folder:
```bash
cd artix-omarchy-repo/bridge
```
3.  Run the adapted Omarchy installer:
```bash
./install-omarchy.sh
```
*   This script will install the necessary packages, enable the `systemctl-shim` compatibility layer, and apply the configurations.

## Technical Notes

*   **UEFI:** The installer is designed exclusively for UEFI systems.
*   **Docker:** A special optimized (No-COW) subvolume named `@docker` is created at `/var/lib/docker`.
*   **Compatibility:** A custom *shim* is used to intercept `systemctl` calls and translate them into `runit` (sv) commands, ensuring that Omarchy services function correctly.
