# Omartix

<img width="1680" height="1184" alt="Omartix" src="https://github.com/user-attachments/assets/60be1ca4-9def-4beb-991d-740dfa7fa0eb" />

**Omartix** is an installer that turns **Artix Linux (Runit)** into **Omarchy** —
the beautiful, opinionated Hyprland/Quickshell desktop by
[DHH](https://dhh.dk) — on a runit base instead of systemd.

It tracks upstream [Omarchy](https://github.com/omacom/omarchy) `quattro`
(v4.0.0.alpha) and adapts its systemd layer to native runit.

## How it works

| Directory | Purpose |
| --- | --- |
| `base-install/` | Phase 1: install a minimal Artix runit base (LUKS2 + BTRFS + Limine). |
| `bridge/` | Phase 2: install Omarchy v4 and adapt it to runit. |
| `runit/` | The runit adaptation layer: native services, per-user services, the UWSM-replacement session manager, and systemd shims. |
| `omarchy-config/` | Vendored upstream Omarchy source (kept pristine; see `.omartix-upstream`). |
| `docs/` | Porting map, test checklist, and the Nullset plan. |

## Installation

### Prerequisites

1. Boot the **Artix Linux (runit)** ISO.
2. Connect to the network (`connmanctl` on the live ISO).
3. UEFI system (the installer is UEFI-only).

### Phase 1 — base system

```bash
# From the live ISO, as root:
git clone https://github.com/xirtus/Omartix.git artix-installer
cd artix-installer/base-install
./install.sh
```

Follow the prompts (disk, passwords, NVIDIA/ZRAM). The installer partitions the
disk (GPT + LUKS2 + BTRFS), installs a minimal Artix runit base, configures
Limine, and copies itself to `~/artix-installer` on the new system. Reboot.

### Phase 2 — Omarchy

```bash
# On the new system, after logging in and connecting to the network (nmtui):
cd ~/artix-installer/bridge
./install-omarchy.sh
```

This installs the runit adaptation layer, lays down Omarchy, installs the
package set (repo + AUR via yay), enables services, and finalizes the user.
Reboot and SDDM will log you into the Omartix desktop.

## Technical notes

* **UEFI only**, Limine on the `Fallback` path (`/EFI/BOOT/BOOTX64.EFI`).
* **BTRFS** subvolumes: `@`, `@home`, `@snapshots`, plus No-COW `@docker` and
  snapshot-excluded `@pkg`/`@log`/`@tmp`.
* **LUKS2** encryption with snapper snapshots.
* **systemd → runit**: a `systemctl` shim plus native runit services replace
  systemd; UWSM is replaced by `omartix-session`. See [`docs/PORTING.md`](docs/PORTING.md).

## License

MIT. Omarchy upstream is also MIT. See [`omarchy-config/LICENSE`](omarchy-config/LICENSE).
