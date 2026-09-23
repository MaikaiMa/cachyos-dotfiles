# Terminal

Ghostty is the terminal; Alacritty stays installed as a fallback without a
bind. Why Ghostty was chosen is recorded in
[ADR-0017](adr/ADR-0017-use-ghostty-as-the-terminal.md).

## What is configured

`chezmoi/dot_config/ghostty/config.ghostty` holds only deliberate deviations
from Ghostty's defaults:

- `theme = dankcolors`: the colours DMS renders from the wallpaper.
- `window-decoration = none`: no GTK header bar; Niri draws the focus ring
  and the corners. Tabs still work and the tab bar appears once a window has
  two or more tabs.
- `window-padding-x`, `window-padding-y`, `window-padding-balance`: some
  breathing room, spread evenly around the text grid.
- `background-opacity = 0.9`: slightly translucent, matching the DMS glass
  look. Niri blurs behind it through the global `background-effect` window
  rule in `cfg/rules.kdl`; Ghostty's own `background-blur` only speaks KDE's
  protocol and is not needed.
- `quit-after-last-window-closed = false`: the instance never quits on its
  own, because it is started with the session (see below) and stays warm for
  the whole login. `ghostty -e` (`commandRunner`) still forces
  `quit-after-last-window-closed = true` for that one-off process, so those
  still exit normally.
- `shell-integration-features = ssh-env,no-ssh-terminfo`: over SSH, `TERM`
  falls back to `xterm-256color`; nothing is installed on the remote host.

The font is Ghostty's embedded JetBrains Mono with Nerd Font symbols.

## Opening windows

The packaged `app-com.mitchellh.ghostty.service` starts with the session,
enabled through the chezmoi-managed relative symlink in `niri.service.wants/`
(the same pattern as `dms.service`; see
[ADR-0007](adr/ADR-0007-start-noctalia-as-a-systemd-user-service.md) for why
`niri.service.wants` rather than `graphical-session.target.wants`). It runs
`ghostty --gtk-single-instance=true --initial-window=false`, so it sits idle
with no window until one is requested. `Mod3+Return` focuses the most recent
Ghostty window or opens one, and `Mod3+Shift+Return` always opens a new one;
both run `ghostty +new-window`, which asks the running instance over D-Bus for
a window. D-Bus activation still covers the case where the service is not
running (killed, crashed, or a session started without systemd), so windows
keep opening either way, just with a cold start in that case.

Measured cost of keeping it running: about 100-170 MB RSS with no windows
open, idle CPU near 0%. The trade-off is one shared process: a Ghostty crash
closes every open window at once, not just one. Alacritty is the fallback if
that becomes a problem (see below). Restart it with:

```fish
systemctl --user restart app-com.mitchellh.ghostty.service
```

This closes all open Ghostty windows; it does not reload configuration
in place the way `pkill -USR2 -x ghostty` does (see below).

The DMS launcher's `commandRunner` plugin (`>` prefix) runs commands in
Ghostty as well; see [docs/dms.md](dms.md#registry-plugins).

## Terminal for DMS

DMS opens `Terminal=true` applications from the launcher and "open terminal
here" in the terminal named by its `terminalOverride` session key; without
it, DMS falls back to `$TERMINAL` and then `xterm`, which is not installed. `dms/session.json`
sets it to `ghostty`, and `scripts/dms-apply-look.sh` merges it into
`~/.local/state/DankMaterialShell/session.json`. DMS starts terminal
applications as `ghostty -e sh -c <command>`, which runs in its own Ghostty
process; "open terminal here" starts plain `ghostty` in that folder.

## Colours and reloading

DMS writes `~/.config/ghostty/themes/dankcolors` on every wallpaper or theme
change. The file is runtime state and is not managed by chezmoi. After
matugen has finished writing all templates, DMS sends `SIGUSR2` to every
process named `ghostty`, which makes Ghostty reload its configuration, so
open windows pick up the new colours without a matugen hook of our own.

An edited `config.ghostty` is not reloaded automatically. Press
`Ctrl+Shift+,` in a Ghostty window, or run:

```fish
pkill -USR2 -x ghostty
```

Settings that apply only to new windows, such as the padding, need a new
window.

## Fallback

Alacritty is still installed with its CachyOS default configuration in
`chezmoi/dot_config/alacritty/alacritty.toml`, but has no bind and is not
themed. Start it from the launcher (`Mod+Space`) if a Ghostty update
misbehaves.
