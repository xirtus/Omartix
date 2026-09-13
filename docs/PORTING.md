# Porting Omarchy (systemd) → Artix runit

This documents every systemd dependency in Omarchy `quattro` and its Omartix
runit equivalent, so the port is auditable and the same map seeds Nullset
(Void/runit).

## System services (`install/config/enable-services.sh`)

| systemd unit | Omartix (runit) | Notes |
| --- | --- | --- |
| `cups.service` | `cupsd` (`cups-runit`) | |
| `avahi-daemon.service` | `avahi-daemon` (`avahi-runit`) | |
| `linux-modules-cleanup.service` | `linux-modules-cleanup` (bundled) | weekly instead of shutdown-hook |
| `docker.socket` | `docker` (`docker-runit`) | no socket activation on runit |
| `systemd-resolved.service` | — | DNS owned by NetworkManager; `etc/systemd/resolved.conf.d` is inert |
| `NetworkManager.service` | `NetworkManager` (`networkmanager-runit`) | |
| `NetworkManager-wait-online.service` (mask) | — (mask is a no-op) | |
| `power-profiles-daemon.service` | `power-profiles-daemon` (`power-profiles-daemon-runit`) | |
| `sddm.service` | `sddm` (`sddm-runit`) | |
| `systemd-oomd.service` | `earlyoom` (`earlyoom-runit`) | PSI→memory-threshold translation in `runit/install.sh` |
| `bluetooth.service` | `bluetoothd` (`bluez-runit`) | |
| `plocate-updatedb.timer` | `plocate-updatedb` (bundled) | daily |
| `snapper-timeline.timer` / `snapper-cleanup.timer` | `snapper-timeline` / `snapper-cleanup` (bundled) | hourly / daily |
| `zram-generator` | `zram` (bundled) | 50% zstd |
| cronie | `fcron` (`fcron-runit`) | Artix has no cronie |

## Systemd config drop-ins

| upstream | Omartix |
| --- | --- |
| `etc/systemd/logind.conf.d/*` (ignore power key, inhibit delay) | `/etc/elogind/logind.conf` (`HandlePowerKey=ignore`, `InhibitDelayMaxSec=15`) |
| `etc/systemd/{system,user}.conf.d/*-nofile.conf` | `/etc/security/limits.conf` nofile 65536:524288 |
| `etc/systemd/oomd.conf.d/*` | `/etc/default/earlyoom` |
| `etc/systemd/resolved.conf.d/*` | inert (NetworkManager DNS) |
| `etc/systemd/system/*.service.d` (cups-browsed, docker, plocate) | handled by the bundled runit services above |
| `etc/systemd/system.conf.d/*-faster-shutdown.conf` | inert (systemd-only) |

## User units (`default/systemd/user/`)

All mapped to `runit/user-sv/`; graphical ones wait for `WAYLAND_DISPLAY` in the
session env file (written by `omartix-session-up`) instead of
`graphical-session.target` ordering.

| systemd user unit | runit user service | Condition |
| --- | --- | --- |
| `bt-agent.service` | `bt-agent` | `/sys/class/bluetooth` + `bt-agent` |
| `omarchy-crash-watch.service` | `omarchy-crash-watch` | needs a journal — inert on runit |
| `omarchy-fcitx5.service` | `omarchy-fcitx5` | `WAYLAND_DISPLAY` |
| `omarchy-migrate-notify.service` | `omarchy-migrate-notify` | oneshot, then pause |
| `omarchy-recover-internal-monitor.service` | `omarchy-recover-internal-monitor` | toggle file exists |
| `omarchy-sleep-lock.service` | `omarchy-sleep-lock` | `WAYLAND_DISPLAY` |
| `omarchy-speaker-tuning.service` | `omarchy-speaker-tuning` | pipewire running |
| `omarchy-tailscale-receive.service` | `omarchy-tailscale-receive` | `tailscale` binary |

## Session manager

UWSM (systemd user manager) → `omartix-session`:

* sources `default/bash/env-bootstrap` (same env UWSM's `env.d/10-omarchy` did)
* starts a session D-Bus
* starts a per-user `runsvdir` on `~/.local/share/omartix/runit/enabled`
* writes the base env file, then `exec`s Hyprland

`omartix-session-up` (from `default/hypr/autostart.lua`) publishes
`WAYLAND_DISPLAY`, refreshes D-Bus activation env, starts graphical services,
and runs `omarchy-provision-first-run`.

## Shims vs. patching

The `systemctl` shim (plus the other systemd tool shims in `runit/shims/`)
covers every `systemctl`/`systemd-run`/`timedatectl`/`hostnamectl`/`localectl`/
`systemd-firstboot` call in Omarchy's `bin/`, so the vendored tree stays
unmodified. Only the two session files above are patched by the bridge.

## Provisioning units

| systemd unit | runit |
| --- | --- |
| `omarchy-provision-owner.service` (tty1, before DM) | `omarchy-provision-owner` (bundled; enables/starts `sddm` when done) |
| `omarchy-system-factory-reset-finish.service` | `omarchy-system-factory-reset-finish` (bundled) |
| `omarchy-provision-autologin-once.service` | `omartix-autologin-once` (bundled) |

Deferred-provisioning/factory-reset ordering against SDDM on runit is
approximate and needs live testing (see `docs/TESTING.md`).

## Known gaps

1. **journald** — `omarchy-crash-watch` and `omarchy-debug`/`omarchy-upload-log`
   read the systemd journal; on runit they degrade (empty / inert). A syslog
   reader could be added to the `journalctl` shim later.
2. **systemd-sleep hooks** — `default/systemd/system-sleep/{unmount-fuse,force-igpu,keyboard-backlight}`
   have no elogind equivalent yet.
3. **socket/device activation** — `docker.socket`, `v4l2-relayd@camlink` device
   units, and `cups.socket` semantics aren't replicated (daemons run as plain
   supervised services).
4. **`omarchy-nvim`/`omarchy-walker`** — these live in `omarchy-pkgs`, not AUR;
   install them from that repo or their upstream sources.
