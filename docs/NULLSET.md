# Nullset — reuse plan (Void/runit fork of Omartix)

Nullset is a future Void fork heavily inspired by Omartix. Because **Void also
uses runit**, almost the entire Omartix adaptation layer carries over. This
documents what is reusable and what must change.

## Reusable as-is

* `runit/` — the whole runit adaptation layer:
  * `shims/` — the `systemctl` shim already auto-detects Void's `/var/service`
    (see the `SYSTEM_SV_ENABLED` detection in `runit/shims/systemctl`), and the
    other systemd tool shims are init-agnostic.
  * `user-sv/` — per-user runit services (Void's `runsvdir` works identically).
  * `session/` — `omartix-session` / `omartix-session-up` / env machinery.
  * `sv/` bundled services (zram, snapper, plocate, linux-modules-cleanup).
* `omarchy-config/` — the vendored Omarchy tree is distro-agnostic except for
  the two session files the bridge patches.
* `docs/PORTING.md` — the systemd→runit map is the same map Nullset needs.

## What changes for Void

| Omartix (Artix) | Nullset (Void) |
| --- | --- |
| `basestrap` / `artix-chroot` / `fstabgen` | `xbps-install` + `chroot` + hand-written fstab |
| `pacman` / `yay` / AUR | `xbps` + `xbps-src` (source packages) |
| `-runit` companion packages | runit services ship in the main Void packages; enable with `ln -s /etc/sv/<name> /var/service/<name>` |
| `elogind` (logind) | Void uses `elogind` (optional) or plain `seatd`; adjust session/lock stack |
| `fcron` | Void's cron is `cronie` |
| Limine (default) | Void's default is GRUB; Limine is available via xbps-src |
| `omartix-services` hardcodes `/etc/runit/sv` | generalize to Void's `/etc/sv` |

## Suggested refactors before forking

1. Extract the runit service-dir detection (`/etc/runit/runsvdir/current` vs
   `/var/service`) into one shared helper used by `omartix-services` and the
   `systemctl` shim (currently duplicated).
2. Split `base-install/` into a disk/btrfs/luks layer (shared) and a
   package-manager layer (`basestrap` vs `xbps`).
3. Make `bridge/install-omarchy.sh` call a `pkg-helper` abstraction (install a
   list, install-one, aur/xbps-src) so only that helper differs between
   Artix and Void.
4. Keep `omarchy-config/` pinned; the more the vendored tree stays pristine,
   the cheaper both distros are to maintain.
