# Gaming session: Steam Big Picture

Alongside the Niri desktop session, the greetd/dms-greeter login screen can
offer a second session: Steam Big Picture running under gamescope, through
the official CachyOS package `gamescope-session-cachyos`. This is a better
fit than Niri for controller-driven, TV-style Steam use.
[ADR-0022](adr/ADR-0022-add-a-steam-big-picture-session-with-gamescope-session-cachyos.md)
records why this package was chosen over the ChimeraOS `-git` alternative or
a self-written session script, and the side effects that come with it.
[ADR-0023](adr/ADR-0023-own-the-greeter-session-list-and-hand-steam-over-to-niri.md)
records how the session list is kept to "Niri" and "Steam", and how "Switch
to Desktop" continues into Niri without a new login.

## What is deployed

- `steam`, `gamescope-session-cachyos`, `xbindkeys`, `brightnessctl`,
  `playerctl`, and `wireplumber` are recorded in `packages/pacman.txt`
  ("Gaming session").
- `scripts/setup-sessions.sh` (a manual step, not part of bootstrap) makes
  the greeter list exactly "Niri" and then "Steam":
  - it adds one `NoExtract` line under `[options]` in `/etc/pacman.conf`, so
    pacman never installs `usr/share/wayland-sessions/niri.desktop`,
    `gamescope-session.desktop`, or `gnome.desktop` again, and keeps a
    timestamped `/etc/pacman.conf.backup-*` copy first;
  - it installs `system/wayland-sessions/niri.desktop` and `steam.desktop` in
    `/usr/local/share/wayland-sessions`, and `system/local/bin/steam-session`
    as `/usr/local/bin/steam-session`;
  - it removes the three packaged entries from `/usr/share/wayland-sessions`
    once `NoExtract` is in effect.
  The Steam entry and wrapper are only installed when
  `/usr/bin/start-gamescope-session` exists; otherwise the script says it
  skips them. GNOME disappears from the list only; `gnome-control-center`
  and `gnome-session` stay installed for GNOME Online Accounts.
- `chezmoi/dot_config/gamescope/xbindkeysrc` and the drop-in
  `chezmoi/dot_config/systemd/user/gamescope-xbindkeys.service.d/xbindkeysrc.conf`
  give the packaged `gamescope-xbindkeys.service` a configuration; it
  otherwise reads `/etc/xbindkeysrc`, which nothing installs.
- The Niri-only user services (DMS, Ghostty, auto-rotate, squeekboard) stay
  under `niri.service.wants`, so they do not start in the Steam session; see
  ADR-0022 for the pattern to keep when adding a new user service.

## Install

Install the packages:

```fish
sudo pacman -S --needed steam gamescope-session-cachyos xbindkeys brightnessctl playerctl
```

Apply the dotfiles for the key bindings (see "Deployment" in
[docs/maintenance.md](maintenance.md)), then preview the session list change:

```fish
./scripts/setup-sessions.sh --dry-run
```

Read the preview, then apply it; it asks for sudo per step:

```fish
./scripts/setup-sessions.sh
```

The greeter reads the session directories when it starts, so the new list
shows at the next logout or reboot. Re-run the script after merging a
`/etc/pacman.conf.pacnew`, and whenever `setup-sessions.sh` or
`system/wayland-sessions` changes; it only changes what differs.

## First run

1. Log out of the running Niri session (or reboot to the greeter).
2. At the greeter, pick "Steam" instead of "Niri", then log in as usual.
3. Steam Big Picture starts. Sign in and let it finish its first update.

## Switching between sessions

- **Into the gaming session:** choose "Steam" at the greeter.
- **Back to the desktop:** in Steam Big Picture, use "Switch to Desktop".
  Steam and gamescope stop, and the same login continues into Niri with DMS;
  there is no password prompt. The Steam session's output is in
  `~/.local/state/steam-session.log`, Niri's in
  `~/.local/state/niri-session.log` as usual.
- If Steam crashes or is quit, the session also continues into Niri. Steam's
  "Shut down" and "Restart" still power off or reboot normally.
- There is no switch from Niri into Steam; log out and pick "Steam" at the
  greeter.
- The greeter preselects the session of the last login through it
  (`docs/greeter.md`). After a Steam login that continued into Niri, that is
  still "Steam".

## Keys in the Steam session

- Brightness up and down change the panel backlight in 5% steps through
  `brightnessctl`, never below 1%.
- Play/pause, pause, next, and previous go to the active media player through
  `playerctl`.
- Volume up and down are not bound: Steam handles them itself in this session
  (`STEAM_ENABLE_VOLUME_HANDLER=1`), and a second binding would change the
  volume twice.
- Mute and mic mute toggle the default PipeWire sink and source through
  `wpctl`; Steam does not handle mute.

The drop-in takes effect from the next login, when the user manager reads it.

## Checking pacman

With `NoExtract` in effect, pacman skips the three session entries when it
checks packages, so they are not reported as missing:

```fish
pacman -Qkk niri gamescope-session-cachyos gnome-session
```

## Known limits

- Steam's TDP and fan sliders are Steam Deck-only and do nothing on the Z13;
  use the existing power-profile tools instead.
- `auto-rotate.service` does not run in this session, so the panel does not
  follow the accelerometer; touch input itself is unaffected.
- The power key suspends here too through the ADR-0021 logind drop-in, not
  through any Steam-specific handling (`steam-powerbuttond-git` is
  deliberately not installed).
- `jupiter-hw-support` is pulled in as a dependency (Steam Deck hardware
  support); ADR-0022 records what its boot services, udev rules, and polkit
  rule actually do on non-Deck hardware.
- Upstream changes to the packaged `niri.desktop` or
  `gamescope-session.desktop` no longer reach the machine; the copies in
  `system/wayland-sessions` follow them by hand.
- `xbindkeys` grabs the keys on gamescope's X server; whether they still
  reach it while a game in a separate Xwayland has focus is to be checked
  below.

## Verify on the device

- [ ] The greeter lists exactly "Niri" first and "Steam" second, with no
      "GNOME" and no "Gamescope".
- [ ] The greeter still preselects the last-chosen session.
- [ ] Steam signs in and completes its first update.
- [ ] Touch input and screen orientation work with the keyboard cover
      detached.
- [ ] A short press of the power key suspends and resumes correctly inside
      the session.
- [ ] "Switch to Desktop" lands in Niri with DMS, without a password prompt,
      and with GNOME Keyring unlocked.
- [ ] Portals work in Niri afterwards: a file picker (for example "Open" in
      a browser) opens, and a screenshot works.
- [ ] `systemctl --user show-environment` in Niri afterwards shows
      `XDG_CURRENT_DESKTOP=niri` and no `XDG_DESKTOP_PORTAL_DIR`.
- [ ] Brightness up and down work in Big Picture and inside a running game,
      and stop at the lowest step instead of turning the panel off.
- [ ] Play/pause, next, and previous control a playing media player.
- [ ] Volume up and down change the volume once per press (Steam's own handling).
- [ ] Mute and mic mute keys toggle output and input mute respectively.
- [ ] `pacman -Qkk niri gamescope-session-cachyos gnome-session` reports no
      missing session files.
- [ ] A game runs at the panel's native resolution and refresh rate.
