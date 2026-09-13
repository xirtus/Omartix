# Build log: Omartix (Artix runit + Omarchy Quattro)

Architecture, design decisions, and fixes. Kept as context for future work.

## 1. System architecture

* **Base:** Artix Linux (Runit).
* **Kernel:** `linux` with Intel/AMD microcode.
* **Filesystem:** BTRFS, `compress=zstd:1`, optimized subvolumes.
* **Encryption:** LUKS2.
* **Bootloader:** Limine (UEFI Fallback path).
* **Desktop:** Omarchy `quattro` (v4.0.0.alpha), Hyprland + Quickshell.
* **Init:** runit (systemd replaced by a dedicated adaptation layer).

## 2. Why the adaptation lives outside `omarchy-config/`

Upstream Omarchy is systemd-based and moves fast. We vendor it **pristine**
under `omarchy-config/` (pinned in `.omartix-upstream`) and keep every Artix/runit
change in `runit/`, `bridge/`, and `base-install/`. Re-syncing upstream is a
`rsync` away and never loses Omartix work. Only two upstream files are touched
at install time, by the bridge:

1. `default/wayland-sessions/omarchy.desktop` — `Exec` → `omartix-session Hyprland`.
2. `default/hypr/autostart.lua` — systemd env-import lines → `omartix-session-up`.

## 3. The runit layer (`runit/`)

* **`systemctl` shim** — translates system + `--user` systemctl calls to `sv`.
  Most upstream scripts therefore run unmodified. Also ships shims for
  `systemd-run`, `systemd-cat`, `journalctl`, `timedatectl`, `hostnamectl`,
  `localectl`, `systemd-firstboot`, `resolvectl`, and
  `dbus-update-activation-environment`.
* **Native system services** — bundled for daemons Artix has no `-runit` package
  for: `zram`, `snapper-timeline`, `snapper-cleanup`, `plocate-updatedb`,
  `linux-modules-cleanup`, plus the provisioning oneshots.
* **Native user services** — the systemd user units (`bt-agent`, `omarchy-crash-watch`,
  `omarchy-fcitx5`, `omarchy-migrate-notify`, `omarchy-recover-internal-monitor`,
  `omarchy-sleep-lock`, `omarchy-speaker-tuning`, `omarchy-tailscale-receive`)
  become per-user runit services under `~/.local/share/omartix/runit/`.
* **Session manager** — `omartix-session` replaces UWSM: session D-Bus + per-user
  `runsvdir` + env file, then execs Hyprland. `omartix-session-up` publishes
  `WAYLAND_DISPLAY` and starts graphical services once the compositor is up.

## 4. Correctness fixes over the previous Omartix

* **`cronie` → `fcron`** — Artix ships `fcron`, not `cronie`.
* **`dbus-runit`/`elogind-runit`** enabled at base install.
* **snapper** has no runit package → native `snapper-timeline`/`snapper-cleanup`
  services instead of the (nonexistent) systemd timers.
* **systemd-oomd → earlyoom**, **systemd-resolved → NetworkManager DNS**,
  **zram-generator → native zram service**.
* Fixed the old bridge path bug (`cd ..` then `./patch-packages.sh`).
* Fixed the old `--user` shim that silently no-oped instead of mapping to
  per-user runit services.
* Fixed limine.cfg to only load microcode images that are actually present.

## 5. Known gaps (see `docs/PORTING.md`)

* `journalctl`-based crash watching has no journald on runit (the
  `omarchy-crash-watch` user service stays inert unless a journal exists).
* systemd-sleep hooks (`default/systemd/system-sleep/*`) have no elogind
  equivalent — documented, not yet re-implemented.
* Deferred-provisioning/factory-reset oneshots are provided but need live
  testing (tty1 ordering against SDDM is approximate on runit).
* `omarchy-nvim` / `omarchy-walker` come from the separate `omarchy-pkgs` repo,
  not AUR; the bridge logs them as install failures to handle manually.
