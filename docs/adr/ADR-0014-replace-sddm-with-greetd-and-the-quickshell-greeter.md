# ADR-0014: Replace SDDM with greetd running the repository-owned Quickshell greeter

- Status: Accepted (2026-09-21); implemented as the last phase of
  [the desktop migration plan](../desktop-migration.md)
- Date: 2026-09-21
- Depends on: ADR-0013

## Context

The machine logs in through SDDM with a stock theme. The desired login screen
is a session picker between the Niri session and a future Steam Big Picture
session, in the same visual language as the lock screen, with colors derived
from the current wallpaper. SDDM themes are QML too, but they cannot share
code or palette state with the Quickshell lock screen of ADR-0013 and would be
a second implementation of the same screen.

ADR-0012 depends on `pam_gnome_keyring.so` in `/etc/pam.d/sddm` to start and
unlock GNOME Keyring with the login password. Any greeter replacement must
preserve that, or SSH signing, GNOME Online Accounts, and the `gh` credential
helper stop working after login.

`greetd` and `swaylock` are in `extra`; `gamescope-session-cachyos` is in the
CachyOS repository and installs its session file under
`/usr/share/wayland-sessions`, which is where the greeter lists sessions from.

## Decision

Replace SDDM with `greetd`. greetd runs Niri as the `greeter` user with a
minimal repository-owned configuration whose only task is to spawn the
Quickshell greeter entry point from ADR-0013. The greeter authenticates
through Quickshell's greetd module, lists sessions from
`/usr/share/wayland-sessions`, remembers the last user and session, and
starts the chosen session.

System files live under `system/greetd/` and `system/pam.d/` in this
repository and are installed by an idempotent `scripts/setup-greetd.sh` that
supports `--dry-run`:

- `/etc/greetd/config.toml` and `/etc/greetd/niri.kdl`;
- `/etc/pam.d/greetd` with the same `pam_gnome_keyring.so` auth and session
  lines SDDM uses today;
- `/etc/greetd/quickshell/session/`, a copy of the deployed
  `~/.config/quickshell/session/` tree, because the greeter user cannot read
  the home directory;
- `/var/lib/greeter/`, group-writable by `greeter`, holding the synced
  wallpaper, palette, and remembered session.

A chezmoi-managed helper, `sync-greeter-theme`, copies the current wallpaper
and matugen palette into `/var/lib/greeter/` after a palette change so the
login screen follows the desktop. The user is added to the `greeter` group for
that purpose.

SDDM stays installed and disabled as the fallback. The rollback is one
documented command pair from a TTY. Enabling greetd and disabling SDDM is the
only step of the migration that changes the boot path, and it runs last.

## Consequences

- One implementation serves lock and login; palette and layout changes land
  in both.
- The Big Picture session appears in the picker as soon as
  `gamescope-session-cachyos` is installed; no greeter change is needed.
- A broken greetd configuration means no graphical login. The setup script
  validates the Niri configuration and the greeter QML before enabling the
  service, and the plan includes a rollback drill before the first reboot.
- GNOME Keyring behavior of ADR-0012 is preserved through the managed PAM
  stack; `pam_kwallet5.so` is not carried over.
- The greeter runs from a copy of the user's tree, so a change to the shared
  components reaches the login screen only after `setup-greetd.sh` runs again.
  The maintenance guide lists this step.
- `greetd` and `swaylock` are recorded in `packages/pacman.txt`; SDDM is not,
  because it is installer-owned (ADR-0009) and kept only as a fallback.

## Alternatives considered

- **`noctalia-greeter`:** available from the CachyOS repository with a session
  picker and Noctalia sync, but it ties the login screen to the shell this
  migration leaves.
- **`greetd-dms-greeter-bin`:** AUR only, and it renders DMS's built-in lock
  screen, which ADR-0013 replaces.
- **A custom SDDM theme:** a second QML implementation without access to the
  Quickshell modules or the shared components.
- **`greetd-regreet` or `greetd-tuigreet`:** solid, but a fixed GTK or
  terminal look that cannot match the lock screen.
