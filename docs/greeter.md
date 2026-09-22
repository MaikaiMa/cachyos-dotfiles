# Login screen: greetd with the DMS greeter

The login screen is [greetd](https://sr.ht/~kennylevinsen/greetd/) running
`dms-greeter`, the DankMaterialShell greeter (AUR
[`greetd-dms-greeter-bin`](https://aur.archlinux.org/packages/greetd-dms-greeter-bin),
upstream [dank-greeter](https://github.com/AvengeMedia/dank-greeter)), instead
of SDDM. `dms-greeter` renders DMS's own login UI, so the login screen matches
the desktop without a second, repository-owned implementation of the lock
screen. DMS's built-in lock screen stays for locking the running session; see
[ADR-0015](adr/ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md),
which supersedes ADR-0014 and amends ADR-0013 decision 3.

## What is deployed

`greetd` starts `dms-greeter` as the `greeter` user, under its own Niri
session:

```toml
[terminal]
vt = 1

[default_session]
user = "greeter"
command = "/usr/bin/dms-greeter --command niri --cache-dir /var/cache/dms-greeter -C /etc/greetd/niri/config.kdl"
```

This is `system/greetd/config.toml`. `dms-greeter` starts and stops Niri
itself as the greeter compositor; it is not the user's Niri session.

`system/pam.d/greetd` is Arch's default `greetd` PAM stack with the
`pam_gnome_keyring.so` auth/password/session lines copied from
`/etc/pam.d/sddm`, so GNOME Keyring unlocks with the login password exactly
as it does under SDDM (ADR-0012). `dms-greeter` would otherwise manage a
fingerprint/U2F block in that file itself, but `dms/look.json` sets
`greeterPamExternallyManaged`, which tells it to leave the file alone; this
repository's copy is authoritative instead.

The `greeter` user and group come from the official `greetd` package's
sysusers file. The same package ships `/etc/greetd/config.toml` and
`/etc/pam.d/greetd` as pacman backup files (both are in its `backup` array),
so a package upgrade never overwrites a locally modified copy; it writes a
`.pacnew` alongside it instead.

## Quiet session entry

greetd hands the session's stdout and stderr to the VT, so everything
`niri-session` prints stays on screen for a moment at login and at logout.
SDDM used to redirect that stream to a log file; greetd does not. Two
repository-owned files restore the redirect:

- `system/local/bin/niri-session-quiet` installs as
  `/usr/local/bin/niri-session-quiet`. It creates `~/.local/state` if needed
  and then `exec`s `/usr/bin/niri-session` with stdout and stderr redirected
  to `~/.local/state/niri-session.log`. The file is truncated at every login,
  so it holds the current or the last session only.
- `system/wayland-sessions/niri.desktop` installs as
  `/usr/local/share/wayland-sessions/niri.desktop` and runs that wrapper.

The redirect lives in the wrapper, not in the desktop entry, because the
greeter's session launcher parses `Exec=` per the Desktop Entry specification
rather than through a shell: `>` and `2>&1` would be passed to `niri-session`
as literal arguments.

The greeter reads `/usr/local/share/wayland-sessions` before
`/usr/share/wayland-sessions` and deduplicates on `Name=`, so the local entry
replaces the packaged one in the picker instead of appearing next to it. That
is why the file keeps the name `niri.desktop` and the value `Name=Niri`: the
desktop id is what the launcher resolves and what the greeter remembers as
the last-used session.

The packaged `/usr/share/wayland-sessions/niri.desktop` is never touched, so
a niri upgrade cannot conflict with this, and a display manager that reads
only `/usr/share/wayland-sessions` keeps starting the packaged session
unchanged. SDDM's default `SessionDir` lists `/usr/local/share/wayland-sessions`
first as well, so after a rollback to SDDM the quiet entry is used there too;
the only effect is that the session log moves from SDDM's own
`~/.local/share/sddm/wayland-session.log` to `~/.local/state/niri-session.log`.
Removing `/usr/local/share/wayland-sessions/niri.desktop` restores the
packaged entry everywhere.

## How sync works

`dms-greeter sync --yes` (run by `scripts/setup-greetd.sh`) makes the login
screen follow the desktop:

- It symlinks the live `~/.config/DankMaterialShell/settings.json`,
  `~/.local/state/DankMaterialShell/session.json`, and
  `~/.cache/DankMaterialShell/dms-colors.json` into
  `/var/cache/dms-greeter/users/<user>/`. Because these are symlinks, not
  copies, the greeter's look, theme, and wallpaper stay live: a wallpaper or
  theme change reaches the login screen immediately, with no re-sync needed.
- It grants the `greeter` group read and traverse ACLs (`setfacl -m
  g:greeter:rX`) on `~`, `~/.config`, `~/.local`, `~/.local/state`,
  `~/.local/share`, and `~/.cache`, recursively, plus default ACLs on the
  three `DankMaterialShell` state directories above and on the wallpaper file
  and its directories, so the `greeter` system account can read what it needs
  to render the same look.
- It extracts the `input`, `output`, `cursor`, and `debug` sections from
  `~/.config/niri/config.kdl` (following includes) into
  `/etc/greetd/niri/dms.kdl`, wrapped by `/etc/greetd/niri/config.kdl`, so the
  greeter's Niri session uses the same keyboard layout, outputs, and scale
  (including the Z13 panel's automatic 1.75 scale) as the desktop session.
  **This part is a snapshot, not live** — a Niri input or output change needs
  a re-sync (see "Maintenance" below).
- It adds the invoking user to the `greeter` group. Group membership only
  takes effect after that user logs out and back in once.
- It rewrites `/etc/greetd/config.toml` to exactly the command shown above,
  keeping a timestamped `.backup-*` copy of the previous file each time it
  runs.

Everything privileged is escalated through `sudo` per step; `dms-greeter
sync` itself runs as the normal user.

## Install procedure

Run these in order, in a terminal:

If `dms/look.json` changed since the last apply, apply it first, so
`greeterPamExternallyManaged` and the rest of the look are current:

```fish
./scripts/dms-apply-look.sh
```

Preview the greetd setup:

```fish
./scripts/setup-greetd.sh --dry-run
```

Read the dry-run output completely, then run it for real:

```fish
./scripts/setup-greetd.sh
```

The `dms-greeter status` report at the end of this first run shows
`permission denied` and `symlink not found` lines for `/var/cache/dms-greeter`:
the sync added you to the `greeter` group, but the running session does not
have that group yet, so the status check cannot read the cache directory.
Log out and back in once, so the group membership takes effect. Then check
the sync state again; every line should now pass:

```fish
dms-greeter status
```

Preview the greeter UI inside the current session before switching the boot
path. This does not use the greetd socket, so authentication does not work in
the preview:

```fish
dms-greeter run
```

```fish
dms-greeter kill
```

When the preview looks right, switch the boot path. This only disables SDDM
and enables greetd; it does not restart or reboot:

```fish
./scripts/setup-greetd.sh --switch
```

Keep the rollback command below open on a second device or written down
before rebooting:

```fish
sudo systemctl disable greetd; and sudo systemctl enable sddm; and sudo reboot
```

Reboot, and log in through the new greeter.

## Verification checklist

After the first login through greetd, confirm:

- Login works with the keyboard (the synced Niri input config applies).
- GNOME Keyring is unlocked: an SSH signature or a `secret-tool` lookup does
  not prompt for a keyring password.
- The session is Wayland:
  ```fish
  loginctl show-session $XDG_SESSION_ID -p Type
  ```
- The session picker lists exactly one Niri entry, and the session log exists
  instead of scrolling past on the VT:
  ```fish
  ls -l ~/.local/state/niri-session.log
  ```
- The last-used session is remembered on the next boot.
- The wallpaper and colors on the greeter match the desktop.
- DMS starts without an immediate lock screen after login.

## Rollback

From a TTY (`Ctrl+Alt+F2`, then log in):

```fish
sudo systemctl disable greetd; and sudo systemctl enable sddm; and sudo reboot
```

SDDM stays installed throughout as the fallback; `setup-greetd.sh` never
removes it.

## Maintenance

Re-run the sync after:

- An upgrade of `greetd-dms-greeter-bin` (AUR).
- Any change to the `input`, `output`, `cursor`, or `debug` sections of
  `~/.config/niri/config.kdl` or its includes.

```fish
./scripts/setup-greetd.sh
```

Without `--switch`, this only re-installs the four system files if they
differ and re-runs the sync; it does not touch the SDDM/greetd boot path.

If a package upgrade of `greetd` or `dms-greeter` leaves a `.pacnew` next to
`/etc/greetd/config.toml` or `/etc/pam.d/greetd`, compare it against the
repository's `system/greetd/config.toml` and `system/pam.d/greetd`: the
repository files are authoritative, so a `.pacnew` here is normally
discarded, but check it for upstream default changes worth adopting first.

Until `setup-greetd.sh` has run on a machine, `./scripts/check-packages.sh`
reports `greetd`, `acl` and `greetd-dms-greeter-bin` as missing. That is
expected: they are recorded in the manifests but installed by this script,
not by bootstrap. Installing `greetd` alone, for example through the bulk
install command in the README, is harmless; it stays disabled until
`--switch`.

## Known limits

- `journalctl -b -u greetd` shows `gkr-pam: couldn't unlock the login keyring`
  once per boot for the `greeter` user (uid 952). That is the keyring session
  line of `system/pam.d/greetd` running for the greeter's own session, which
  has no keyring; the later `gkr-pam: unlocked login keyring` for your user is
  the line that matters.
- The packaged `/usr/bin/niri-session` calls `systemctl --user
  import-environment` without arguments, which systemd 261 warns about
  (`Calling import-environment without a list of variable names is
  deprecated.`). The quiet session entry above redirects it to
  `~/.local/state/niri-session.log` instead of the VT. It is harmless, and
  the deprecated call is fixed upstream in niri (PRs 3572 and 3776), not
  here.
- The greeter preselects the last successfully logged-in user and session
  from `/var/cache/dms-greeter/.local/state/memory.json`. That file is written
  at the first successful login, so the very first boot through greetd shows
  no preselected user.

- The `greeter` system account gets read access to `~/.cache/DankMaterialShell`
  as part of the ACL sync, which includes clipboard and notification history,
  not just theme state. This is an accepted trade-off of using the live
  symlink approach.
- `/etc/greetd/config.toml` accumulates a timestamped backup on every sync
  run; this is cosmetic and safe to clean up by hand.
- dank-greeter 1.6.2's sync leaves `/etc/greetd/config.toml` owned by the
  invoking user with mode 0600, because its last rewrite moves a user-owned
  temporary file into place. greetd runs as root and reads it regardless;
  `setup-greetd.sh` restores `root:root` and mode 0644 after every sync.
- The greeter UI is embedded in the `dms-greeter` binary and reads the live
  `settings.json` of whatever DMS version is installed. A DMS upgrade does
  not change the login screen; the AUR package has to catch up on its own,
  and until it does the greeter renders an older UI against newer settings.
- `greetd-dms-greeter-bin` is AUR-maintained, not an official package; see
  ADR-0009 for how this repository treats AUR dependencies.
- The Big Picture session appears in the greeter's session picker only once
  `gamescope-session-cachyos` is installed; no greeter change is needed for
  that.
