# Omartix runit layer

This directory contains everything that adapts **Omarchy** (systemd) to
**Artix Linux (runit)**. It is deliberately kept **outside** `omarchy-config/`
so the vendored Omarchy tree can be re-synced upstream without losing the
adaptation. The same layer is the seed for **Nullset** (Void/runit), since Void
uses runit too.

Installed to `/usr/share/omartix/runit/` on the target system by
`runit/install.sh`.

## Layout

| Path | Purpose |
| --- | --- |
| `omartix-services` | The systemd → runit service mapping and `enable-all`/`enable`/`disable`/`status` helper (system services). |
| `shims/` | Drop-in replacements for systemd tools: `systemctl`, `systemd-run`, `systemd-cat`, `journalctl`, `timedatectl`, `hostnamectl`, `localectl`, `systemd-firstboot`, `resolvectl`, `dbus-update-activation-environment`. |
| `sv/` | Bundled **system** runit services for daemons Artix ships no `-runit` package for (`zram`, `snapper-timeline`, `snapper-cleanup`, `plocate-updatedb`, `linux-modules-cleanup`) plus the provisioning oneshots. |
| `user-sv/` | Bundled **per-user** runit services (the systemd user units under `default/systemd/user/`). |
| `session/` | `omartix-session` (UWSM replacement), `omartix-session-up` (compositor-up hook), `omartix-session-env`, `omartix-user-services`. |
| `install.sh` | Installs the layer into the target. |

## System service mapping

Omarchy enables these systemd units (in `install/config/enable-services.sh`);
the runit equivalents are:

| systemd | runit (Artix) |
| --- | --- |
| `cups.service` | `cupsd` (`cups-runit`) |
| `avahi-daemon.service` | `avahi-daemon` (`avahi-runit`) |
| `docker.socket` | `docker` (`docker-runit`) |
| `NetworkManager.service` | `NetworkManager` (`networkmanager-runit`) |
| `power-profiles-daemon.service` | `power-profiles-daemon` (`power-profiles-daemon-runit`) |
| `sddm.service` | `sddm` (`sddm-runit`) |
| `systemd-oomd.service` | `earlyoom` (`earlyoom-runit`) |
| `bluetooth.service` | `bluetoothd` (`bluez-runit`) |
| `plocate-updatedb.timer` | `plocate-updatedb` (bundled) |
| `snapper-*.timer` | `snapper-timeline` / `snapper-cleanup` (bundled) |
| `zram-generator` | `zram` (bundled) |
| `cronie` | `fcron` (`fcron-runit`) — Artix has no `cronie` |
| `linux-modules-cleanup.service` | `linux-modules-cleanup` (bundled) |
| `systemd-resolved.service` | — (DNS is owned by NetworkManager) |

## User services

The systemd user units under `default/systemd/user/` map to `user-sv/`:

`bt-agent`, `omarchy-crash-watch`, `omarchy-fcitx5`, `omarchy-migrate-notify`,
`omarchy-recover-internal-monitor`, `omarchy-sleep-lock`,
`omarchy-speaker-tuning`, `omarchy-tailscale-receive`.

Graphical services wait for `WAYLAND_DISPLAY` in the session environment file
(published by `omartix-session-up` once the compositor is up) instead of
systemd's `graphical-session.target` ordering.

## Session model

UWSM is replaced by `omartix-session` (wired into `omarchy.desktop`'s `Exec`
line by the bridge). It starts a session D-Bus + a per-user `runsvdir`, then
execs Hyprland. Hyprland's autostart calls `omartix-session-up`, which publishes
the full environment, starts graphical user services, and runs
`omarchy-provision-first-run`.

## Shims vs. patching upstream

The `systemctl` shim translates Omarchy's `systemctl` calls (system and
`--user`) to `sv`, so most upstream scripts run **unmodified**. Only two small
upstream touchpoints are patched by the bridge (see `bridge/`):

1. `default/wayland-sessions/omarchy.desktop` — `Exec` points at `omartix-session`.
2. `default/hypr/autostart.lua` — the two systemd env-import lines are replaced
   with a call to `omartix-session-up`.
