# ADR-0023: Own the greeter session list and hand Steam over to Niri

- Status: Accepted
- Date: 2026-09-24
- Amends: [ADR-0022](ADR-0022-add-a-steam-big-picture-session-with-gamescope-session-cachyos.md)
  (its "Switch to Desktop" behaviour)

## Context

With `gamescope-session-cachyos` installed, the greeter lists three sessions
in no chosen order: "Gamescope", "GNOME", and "Niri". The wanted list is
exactly "Niri" first, then "Steam".

- dms-greeter cannot order, rename, or hide sessions. It reads
  `/usr/share/wayland-sessions`, `/usr/local/share/wayland-sessions`, the
  greeter's own `~/.local/share`, and the `XDG_DATA_DIRS` entries, reversed;
  it keeps the first session with a given `Name=`, sorts nothing, and ignores
  `NoDisplay=` and `Hidden=`. It remembers the last session by desktop file
  ID (`niri.desktop`).
- `/usr/share/wayland-sessions/gnome.desktop` comes from `gnome-session`, a
  dependency of `gnome-shell`, which `gnome-control-center` requires. That
  package stays: it is the only UI that adds GNOME Online Accounts
  (`packages/pacman.txt`). The GNOME session itself is not wanted.
- Steam's "Switch to Desktop" runs `steamos-session-select plasma`. Under
  greetd that only runs `steam -shutdown` and stops
  `gamescope-session.target`, so `start-gamescope-session` returns and, per
  ADR-0022, the login session ends and the greeter asks for the password
  again.

## Decision

1. **pacman stops extracting the packaged session entries.** One `NoExtract`
   line under `[options]` in `/etc/pacman.conf` covers
   `usr/share/wayland-sessions/niri.desktop`,
   `usr/share/wayland-sessions/gamescope-session.desktop`, and
   `usr/share/wayland-sessions/gnome.desktop` (`gnome-session` ships no
   `xsessions` entry). The files are then never installed again by an
   upgrade or reinstall, and `pacman -Qkk` skips them instead of reporting
   them as missing (checked with pacman 7.1).
2. **The repository owns the list.** `system/wayland-sessions/niri.desktop`
   (`Name=Niri`, `Exec=niri-session`, ID unchanged, so the remembered choice
   survives) and `system/wayland-sessions/steam.desktop` (`Name=Steam`,
   `Exec=/usr/local/bin/steam-session`, `DesktopNames=gamescope`, so
   `XDG_CURRENT_DESKTOP` still selects gamescope's portal configuration)
   are installed in `/usr/local/share/wayland-sessions`. Within one directory
   the greeter loads files in name order, and `niri.desktop` sorts before
   `steam.desktop`. GNOME is hidden by having no entry at all, while
   `gnome-control-center` and `gnome-session` stay installed.
3. **Steam hands over to Niri in the same login.** `steam-session`
   (`system/local/bin/steam-session`, installed as
   `/usr/local/bin/steam-session`) runs `start-gamescope-session` with its
   output in `~/.local/state/steam-session.log`. When that returns, it
   removes what the gamescope session left in the user manager
   (`XDG_DESKTOP_PORTAL_DIR`, set to an empty value, which would leave
   xdg-desktop-portal without any backend; stale `DISPLAY`,
   `WAYLAND_DISPLAY`, `XAUTHORITY`), stops `xdg-desktop-portal.service` in
   case D-Bus activated it again with the gamescope environment, sets
   `XDG_CURRENT_DESKTOP`, `XDG_SESSION_DESKTOP`, and `DESKTOP_SESSION` to
   `niri`, and `exec`s `niri-session` by name, so the quiet wrapper from
   [docs/greeter.md](../greeter.md) applies. `niri-session` then imports that
   environment into systemd and D-Bus as at a normal login.
4. **`scripts/setup-sessions.sh` applies it**, as a manual step next to
   `scripts/setup-greetd.sh`, not from bootstrap: it changes the package
   manager's configuration and removes package-owned files, which is a
   system change of the same kind as switching the display manager, and
   nothing in the chezmoi configuration depends on it. It adds only the
   missing `NoExtract` entries (keeping any existing line and a timestamped
   backup), installs the session entries, removes the packaged copies only
   once `pacman-conf` reports `NoExtract` in effect, and installs the Steam
   entry and wrapper only when `/usr/bin/start-gamescope-session` exists.

## Consequences

- If Steam crashes or is quit, the session also continues into Niri, not to
  the greeter. Steam's "Shut down" and "Restart" still power off or reboot
  normally.
- There is no Niri to Steam switch within a login; that still goes through
  the greeter.
- `/etc/pacman.conf` is a pacman backup file. A `pacman` upgrade that changes
  the shipped file writes `/etc/pacman.conf.pacnew` and leaves the edited one
  in place; when merging it, keep the `NoExtract` line (re-running the script
  re-adds it if it was lost, and removes any packaged entry that came back).
- A new session package (another compositor) shows up again until its entry
  is added to the script's `NoExtract` list.
- Upstream changes to the packaged `niri.desktop` or
  `gamescope-session.desktop` no longer arrive; the repository copies have to
  follow them by hand.
- In the Steam session `DESKTOP_SESSION` and `XDG_SESSION_DESKTOP` are
  `steam`, not `gamescope-session`; nothing in the gamescope or SteamOS
  scripts reads them.
- The order within a directory relies on the greeter loading files in the
  name order in which it requests them; it loads them asynchronously, so this
  is an observed behaviour, checked on the device (docs/gaming.md).

## Alternatives considered

- **Editing the packaged session files, or a pacman hook that rewrites
  `Name=`**: `pacman -Qkk` reports the modified files, and every upgrade
  restores them until the hook runs again; rejected.
- **Extra entries with the wanted names alongside the packaged ones**: the
  greeter deduplicates by `Name=` only, so a new name adds a fourth and fifth
  entry instead of renaming; the packaged "Gamescope" and "GNOME" stay
  visible; rejected.
- **Removing `gnome-control-center`**: loses the only UI for GNOME Online
  Accounts, which mail depends on; rejected.
- **Autologin back into Niri after "Switch to Desktop"**: needs a greetd
  `initial_session` that SteamOS's `steam-set-session` does not support, and
  would log in without a password; rejected in favour of the handover.
