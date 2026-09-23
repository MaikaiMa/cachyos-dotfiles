# ADR-0017: Use Ghostty as the terminal

- Status: Accepted
- Date: 2026-09-23

## Context

This is the first Linux desktop the user has set up. The terminal should be
lean, clean, stable, fast, modern, and minimal, and look at home next to the
GNOME applications already chosen (Nautilus, Loupe, Hylki). Niri already
handles tiling, and its columns and tabbed columns replace most of what a
terminal multiplexer or split feature would offer, so those features do not
decide the choice.

Alacritty was the CachyOS default and is still bound, with a configuration
that is the unmodified CachyOS file. Ghostty was already installed and matched
by the `code` workspace rule. DMS renders a wallpaper theme for both, as well
as for Kitty, WezTerm, and foot.

## Decision

Make Ghostty the terminal. The packaged `app-com.mitchellh.ghostty.service`
starts with the Niri session, enabled through a chezmoi-managed relative
symlink in `niri.service.wants/`, the same pattern used for `dms.service`
(see ADR-0007). `Mod3+Return` focuses the most recent Ghostty window or opens
one, `Mod3+Shift+Return` always opens a new one; both go through
`ghostty +new-window`, which reaches the running instance over D-Bus. D-Bus
activation still covers the case where the service is not running, so a
window still opens either way, just with a cold start in that case.

The managed configuration in `chezmoi/dot_config/ghostty/config.ghostty`
contains only deliberate deviations from Ghostty's defaults: the DMS
`dankcolors` theme, no client-side decorations because Niri draws the focus
ring, padding, a nearly opaque background that Niri's global
background-effect rule blurs, an instance that stays alive without windows,
and SSH shell integration.
The theme file itself stays DMS-owned runtime state.

The DMS `commandRunner` launcher plugin runs its commands in Ghostty, and
DMS's `terminalOverride` session key points DMS's own terminal launches at
Ghostty.

Alacritty stays installed and in the manifest as a fallback, without a bind.

## Consequences

- Ghostty is GTK4 and libadwaita native, GPU rendered, and ships usable
  defaults, including an embedded JetBrains Mono and Nerd Font symbols, so
  the configuration stays a handful of lines.
- `ssh-env` is enabled: over SSH, `TERM` falls back to `xterm-256color` so
  remote hosts without Ghostty's terminfo still work. `ssh-terminfo` stays
  off explicitly, because it installs terminfo into the remote home
  directory; the user works on client servers under ISO 27001, where a
  terminal must not write to remote hosts on its own.
- DMS rewrites the theme on a wallpaper change and then signals Ghostty to
  reload, so open windows follow the wallpaper; see
  [docs/terminal.md](../terminal.md). A `ghostty_background` user matugen
  template overrides the theme's near-black `surface` background with the
  lighter `surface_container` colour, rendered in the same matugen run.
- Ghostty 1.3 on Linux only requests blur through KDE's protocol. The blur
  comes from Niri's own window rule instead, which also covers every other
  translucent window.
- Commands started with `ghostty -e`, as `commandRunner` does, run in a
  separate Ghostty process. Ghostty forces
  `quit-after-last-window-closed = true` for any process started with `-e`,
  so that process still exits once its command finishes, regardless of the
  managed configuration.
- Running from login costs roughly 100-170 MB RSS at idle with no windows
  open, idle CPU near 0%, measured on the user's machine. The trade-off is a
  single shared process: a Ghostty crash closes every open window at once.
  Restarting it (`systemctl --user restart app-com.mitchellh.ghostty.service`)
  closes all open windows too.
- Alacritty remains a known-good fallback if a Ghostty update regresses.
  Its repository configuration is still the CachyOS default and is not
  themed by this change.

## Alternatives considered

- **Alacritty:** stable, minimal, and fast, kept as the fallback. It has no
  tabs, ligatures, or inline images, and is not a GTK application.
- **Kitty:** mature and feature-rich, but its own toolkit and a large
  configuration surface run against the minimal requirement.
- **WezTerm:** capable and Lua-configurable, but development has slowed and
  its multiplexer overlaps with Niri.
- **foot:** the leanest Wayland terminal, but CPU rendered and without
  ligatures.
- **Rio:** modern and GPU rendered, but still young.
