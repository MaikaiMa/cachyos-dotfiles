# Noctalia lock screen

The managed lock screen intentionally stays close to Noctalia's supported
defaults. It uses only built-in `clock` and `login_box` widgets, keeping the
authentication path, session actions, and visual behavior inside Noctalia.

## Composition

`chezmoi/dot_config/noctalia/lockscreen.toml` defines the same three-part
composition for the laptop `eDP-1` output and the known `DP-1` external output:

- a large native digital clock;
- a smaller native date using the current locale;
- a narrowed native login box with the password hint row disabled.

The active wallpaper remains visible and all colors use Noctalia's semantic
palette. The login box keeps the native session-action row, including the
destructive shutdown treatment. Weather and media are omitted to keep the
surface stable and predictable.

## Machine-local verification

The checked-in coordinates use these known logical output geometries:

- `eDP-1`: 1463 by 914 logical pixels;
- `DP-1`: 2560 by 1440 logical pixels.

Noctalia's lock-screen widget editor writes overrides to
`~/.local/state/noctalia/settings.toml`. Promote intentional editor results
back into the managed TOML and remove only the state file's top-level
`lockscreen_widgets` override before testing the managed configuration.

`config-reload` does not currently reconstruct existing lock-screen surfaces
at new coordinates. Fully restart Noctalia after changing widget placement or
box dimensions, then verify the actual locked surface. The editor preview is
useful for rough placement but is not authoritative for the native login box.

The login greeter remains a separate future integration. A replacement shell
may share visual components with a greetd greeter later, but it must preserve
the distinction between starting a session and unlocking an existing one.
