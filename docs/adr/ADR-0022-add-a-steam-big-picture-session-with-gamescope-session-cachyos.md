# ADR-0022: Add a Steam Big Picture session with gamescope-session-cachyos

- Status: Accepted
- Date: 2026-09-24
- Amended by: [ADR-0023](ADR-0023-own-the-greeter-session-list-and-hand-steam-over-to-niri.md)
  (session list and "Switch to Desktop")

## Context

The Niri session is not a good fit for controller-driven, TV-style Steam Big
Picture use. ADR-0014 and ADR-0015 already anticipated a second, gaming
session chosen at the greetd/dms-greeter login screen alongside Niri.

Three options were considered:

- **`gamescope-session-cachyos`** (official CachyOS repository): built for
  CachyOS Handheld against the same `gamescope` and `steam` packages this
  repository already installs (see the "Gaming" section of `README.md`).
- **ChimeraOS `gamescope-session-steam-git`** (AUR): a `-git` package that
  tracks upstream head, more frequent breakage, no CachyOS integration.
- **A self-written session script**: full control, but an ongoing
  maintenance burden to track gamescope/Steam changes that the CachyOS
  package already absorbs.

The official CachyOS package was chosen for stability: it is maintained
alongside the CachyOS gaming stack already recorded in `packages/pacman.txt`,
needs no repository-owned script, and no system file changes.

## Decision

Record `steam` and `gamescope-session-cachyos` in `packages/pacman.txt`
("Gaming session" section). No script, system file, or greetd configuration
change is needed:

- The package installs `/usr/share/wayland-sessions/gamescope-session.desktop`
  (`Name=Gamescope`), which dms-greeter lists automatically, as already noted
  in ADR-0014 and ADR-0015. `system/greetd/config.toml` is unchanged.
- The session runs `start-gamescope-session`, which starts the user unit
  `gamescope-session.target` (binds `graphical-session.target`) with
  `gamescope-session.service` and `steam-launcher.service`.
- The Niri-only user services (`dms`, `ghostty`, `auto-rotate`,
  `mobi.phosh.OSK`/squeekboard) are enabled under
  `chezmoi/dot_config/systemd/user/niri.service.wants/`, bound to
  `niri.service`, not `graphical-session.target`, so they do not start in the
  gaming session. Anyone adding a new desktop-only user service must keep
  that pattern. Session-independent services (`protonmail-bridge`,
  `wallpaper-favorites.path`, `z13ctl`) are enabled elsewhere and run in both
  sessions; that is intended.
- Steam's "Switch to Desktop" runs `steamos-session-select plasma`, which
  calls `/usr/lib/steamos/steam-set-session`. That script only writes
  autologin configuration for sddm or plasmalogin and exits 0 for any other
  display manager, then stops `gamescope-session.target`. Under greetd the
  session simply ends and the greeter returns; no repository shadow script is
  needed for this.
  *Amended by ADR-0023:* the session now continues into Niri in the same
  login through `/usr/local/bin/steam-session`, and the packaged
  `gamescope-session.desktop` is replaced by a repository-owned "Steam"
  entry.
- The logind drop-in from ADR-0021 (`HandlePowerKey=suspend`) applies inside
  this session too, since it is a systemwide logind policy, not a Niri
  setting. `steam-powerbuttond-git` is deliberately not installed; it would
  duplicate that handling.
- `cachyos-gamescope-autologin.service`, shipped by the package, has no
  preset and stays disabled.

## Consequences

- Accepted side effect: the package depends on `jupiter-hw-support` (Steam
  Deck hardware support). Verified by extracting its contents:
  - Its boot services `jupiter-biosupdate` and `jupiter-controller-update`
    check for a Valve Jupiter/Galileo board and do nothing on other hardware.
  - `99-holo-automount.rules` auto-mounts USB/SD filesystems on insert, in
    both sessions.
  - `80-gpu-reset.rules` kills the offending process on a GPU reset and tries
    to restart sddm, a no-op here since sddm is not the active display
    manager.
  - A polkit rule lets the `wheel` group eject or power off drives without a
    password prompt.
  - The gamescope session script calls `kwriteconfig6` to set the GTK cursor
    theme to `steam` in `~/.config/gtk-3.0/settings.ini`. `kwriteconfig6` is
    not installed, so this is a no-op today; it would leak the Steam cursor
    theme into the Niri session if a kconfig package is ever installed for
    another reason.
- Steam's TDP and fan sliders are Steam Deck-only and do nothing on the Z13;
  power profiles stay with `power-profiles-daemon` and `z13ctl`.
- `auto-rotate.service` does not run in the gaming session (it is a
  `niri.service.wants` unit), so the panel does not auto-rotate there.
- Things that still need verification on the physical machine are listed in
  [docs/gaming.md](../gaming.md).

## Alternatives considered

- **ChimeraOS `gamescope-session-steam-git`** (AUR): tracks upstream head
  more closely, but `-git` packages break more often and duplicate what the
  CachyOS package already maintains; rejected for stability.
- **A self-written gamescope session script**: avoids `jupiter-hw-support`,
  but trades a maintained package for an ongoing maintenance burden tracking
  gamescope and Steam changes; rejected.
