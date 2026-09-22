# ADR-0015: Use the DMS greeter under greetd and keep the DMS lock screen

- Status: Accepted (2026-09-22)
- Date: 2026-09-22
- Supersedes: ADR-0014
- Amends: ADR-0013 decision 3

## Context

ADR-0013 decision 3 planned a repository-owned Quickshell lock screen and
greeter. ADR-0014 planned greetd running that greeter from a copy under
`/etc/greetd`, with a wallpaper/palette sync helper keeping it in step with
the desktop.

After living with DMS's built-in lock screen, the user judged it acceptable.
The only two wishes left were the distance between the clock and the password
field, and a larger media card. Both are hard-coded in DMS's embedded QML: the
clock is anchored 60 px above the vertical centre, the password field sits one
spacing unit under the date, and the media player is a compact icon row top
right with only an on/off setting. No setting, plugin, or template reaches
them, and DMS plugins cannot draw on the lock layer. Changing them requires
either a custom locker or a full `DMS_SHELL_DIR` tree fork, both of which
ADR-0013 rejected. A custom locker means its own PAM handling, its own MPRIS
card duplicating the dashboard's, its own weather fetch, and a second
Quickshell process, which is disproportionate for two cosmetic points.

Facts discovered that made the original plan stale (verified 2026-09-22
against DMS 1.6.2 and dank-greeter 1.6.2 source):

- DMS 1.6.2 has `customPowerActionLock` for an external locker, so swayidle
  would not have been needed either way, and it writes its palette to
  `~/.cache/DankMaterialShell/dms-colors.json`.
- DMS's greeter moved to the standalone project dank-greeter, packaged in AUR
  as `greetd-dms-greeter-bin` (1.6.2, tracking DMS releases). It is not in the
  official repositories; the official greetd greeters are agreety, regreet,
  and tuigreet, none of which match the shell.
- The DMS lock's built-in features (clock, date, weather, media, keyboard
  layout, caps lock notice, power actions) already cover what a greeter
  needs to mirror.

The stock SDDM login screen runs without a theme and is the part the user
actually wants replaced.

## Decision

1. The DMS built-in lock screen stays; there is no repository-owned lock
   screen. ADR-0013 decision 3 is amended accordingly. The DMS idle timeouts
   in `dms/look.json` remain the idle policy.
2. greetd replaces SDDM and runs dms-greeter from `greetd-dms-greeter-bin`
   (AUR, recorded in `packages/aur.txt` with a rationale; `greetd` and `acl`
   in `packages/pacman.txt`). Repository-owned system files:
   `system/greetd/config.toml` (command `/usr/bin/dms-greeter --command niri
   --cache-dir /var/cache/dms-greeter -C /etc/greetd/niri/config.kdl`, the
   exact form `dms-greeter sync` rewrites it into) and `system/pam.d/greetd`
   (the Arch default plus the `pam_gnome_keyring.so` lines from
   `/etc/pam.d/sddm`, preserving ADR-0012; `pam_kwallet5` is not carried
   over). `dms/look.json` sets `greeterPamExternallyManaged: true` so
   dms-greeter never edits the PAM file itself.
3. `scripts/setup-greetd.sh` (idempotent, supports `--dry-run`, runs as the
   user with sudo per step) installs the packages and files, runs
   `dms-greeter sync --yes`, and validates the generated Niri config. The
   SDDM-to-greetd switch is a separate, explicit `--switch` flag and never
   runs with `--now`. SDDM stays installed as the fallback; rollback from a
   TTY is `sudo systemctl disable greetd; and sudo systemctl enable sddm; and
   sudo reboot`.
4. Theme sync is dank-greeter's own live mechanism: it symlinks the user's
   live DMS settings, session, and colours into
   `/var/cache/dms-greeter/users/<user>/`, and needs read/traverse ACLs for
   the `greeter` group on `~`, `~/.config`, `~/.local`, `~/.local/state`,
   `~/.local/share`, and `~/.cache`, recursively on the three
   DankMaterialShell directories and on the wallpaper. The user explicitly
   accepted that this also exposes `~/.cache/DankMaterialShell` (clipboard
   and notification history) to the local `greeter` system account. There is
   no repository-owned sync helper.
5. Sync also copies the Niri `input`, `output`, `cursor`, and `debug`
   sections into `/etc/greetd/niri/`, so keyboard layout and outputs match
   the desktop. A re-sync is needed after Niri input/output changes and after
   dms-greeter upgrades.

## Consequences

- One look for lock and login without any repository-owned QML. Phase 4 of
  `docs/desktop-migration.md` is dropped and phase 5 is revised.
- AUR maintenance and version coupling: the greeter reads the live
  `settings.json` of a possibly newer DMS.
- `dms-greeter sync` leaves timestamped `config.toml` backups in
  `/etc/greetd`; the two `/etc` files are pacman backup files (`.pacnew` on
  upgrades).
- A broken greeter means no graphical login until the TTY rollback; greetd
  restarts the greeter automatically (`StartLimitBurst` 5/30 s).
- GNOME Keyring behaviour must be verified after the first login.
- The Big Picture session appears in the picker once
  `gamescope-session-cachyos` is installed, as before.

## Alternatives considered

- **Custom Quickshell lock and greeter, as in ADR-0013/ADR-0014:** full
  design freedom, two or three evenings of work, components single-use once
  the lock is dropped, and its own sync/remember logic duplicating
  dank-greeter.
- **`DMS_SHELL_DIR` fork to change two numbers:** rejected as a fork
  requiring a weekly rebase.
- **Keep SDDM with a theme:** the official repositories offer only
  elarun, maldives, maya, and the CachyOS theme; none derive a wallpaper
  palette, and AUR themes would be needed anyway.
- **greetd with regreet or tuigreet:** official packages, but a fixed look
  unrelated to the shell.
