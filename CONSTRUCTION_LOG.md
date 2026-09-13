# Build Log: Artix Omarchy (Runit Edition)

This document summarizes the architecture, design decisions, and critical fixes implemented during the creation of this installer. It serves as context for future modifications.

## 1. System Architecture
*   **Base:** Artix Linux (Runit Edition).
*   **Kernel:** Linux (standard) with dual microcode (Intel/AMD).
*   **File System:** BTRFS with `zstd:1` compression and optimized subvolumes.
*   **Encryption:** LUKS2 (AES-XTS-Plain64).
*   **Bootloader:** Limine (UEFI Fallback mode).
*   **Configuration:** Omarchy Distribution (adapted via compatibility layer).

## 2. Implemented Features (Phase 1: Base)
*   **BTRFS Layout:**
*   `@`: Root. 
*   `@home`: User data. 
*   `@snapshots`: Snapper integration. 
*   `@docker`: **No-COW** (`chattr +C`) for optimal container performance. 
*   `@pkg`, `@log`, `@tmp`: Excluded from snapshots to save space.
*   **Resilience:**
*   Smart partition detection for NVMe/eMMC drives (`p1`, `p2`) vs. SATA (`1`, `2`). 
*   `ParallelDownloads` enabled for fast installations. 
*   Forced keyring update prior to installation to prevent GPG signature errors.
*   **UEFI:** Installation to `Fallback` path (`/EFI/BOOT/BOOTX64.EFI`) for maximum portability without relying on NVRAM variables.
*   **Optimization:**
*   **ZRAM:** Compressed swap in RAM (50% capacity) via native Runit service. 
*   **NVIDIA:** Automatic DKMS driver installation and DRM/KMS configuration for Wayland/Hyprland. 
*   **SSD:** Weekly `fstrim` script via cron. ## 3. Compatibility Layer (Phase 2: Bridge)
*   **Systemctl Shim:**
*   Intercepts `systemctl` commands and translates them to `sv` (Runit). 
*   Manages **persistence** by linking services to `/etc/runit/runsvdir/default`. 
*   Maps Systemd service names to Runit (e.g., `bluetooth` -> `bluetoothd`).
*   **Dynamic Patching:**
*   `patch-packages.sh`: Modifies Omarchy package lists to inject `-runit` versions. 
*   Runtime `sed`: Replaces references to `systemd-networkd/resolved` with `NetworkManager` in Omarchy scripts.

## 4. User Workflow
1.  **Live Boot:** Use `connmanctl` for networking.
2.  **Phase 1:** `./install.sh` (Base). The installer is automatically copied to `~/artix-installer`.
3.  **Phase 2:** `./bridge/install-omarchy.sh` (Configuration). Use `nmtui` for networking.

## 5. Future Notes
*   **Adding Software:** If applications depending on services are added, update `systemctl-shim` with the new name mappings if they differ from the Arch version.
*   **Kernels:** If switching to `linux-lts` or `linux-zen`, remember to update `limine.cfg` and the `nvidia-dkms` hook.
*   **Multilib:** Already enabled by default to support Steam/Wine.
