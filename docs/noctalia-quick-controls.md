# Noctalia Dashboard

`maikel/quick-controls` is the managed, declarative Noctalia dashboard opened
by `Mod+S`. It replaces the built-in Home tab as the normal entry point without
patching Noctalia. The header keeps the original Home tab, notifications, all
Settings, and Close one click away.

The dashboard contains:

- a full-width row of primary quick controls directly below the header;
- a compact MPRIS media card with a stable empty state when no player is active;
- brightness, output-volume, and input-volume sliders;
- wallpaper, Bluetooth, Wi-Fi, Caffeine, and Do Not Disturb shortcuts when
  their state can be read reliably;
- battery charge and remaining-time information;
- direct Power Saver, Balanced, and Performance profile buttons;
- compact CPU, memory, GPU, and network history graphs.

Night Light is intentionally absent. Noctalia currently exposes actions for
the schedule and forced mode but not the complete runtime state through its
plugin or IPC API. The dashboard hides controls whose selected state cannot be
authoritative.

The plugin source lives under
`chezmoi/dot_local/private_share/noctalia/plugins/quick-controls/` and deploys
to `$XDG_DATA_HOME/noctalia/plugins/quick-controls/`. The read-only
`noctalia-dashboard-state` helper runs only for refreshes while the panel is
open. `playerctl` is required for media metadata and controls.

Noctalia keeps its enabled-plugin list as machine-local state. Enable the
dashboard once after the first deployment:

```fish
noctalia msg plugins enable maikel/quick-controls
```

Noctalia watches local plugin files and normally reloads them automatically.
If the panel was open during deployment, close and reopen it with `Mod+S`.

The glass panel uses Niri's configured non-xray background effect. Noctalia's
native panel animation runs at 1.15 times its normal speed and the centered
shadow supplies a soft focus halo without a fullscreen overlay. The dashboard
opens top-centred beneath the bar, in the same position as the built-in panels.
Noctalia's plugin API has no content-fit or percentage height, so the panel uses
a fixed 730 logical pixel height sized around the complete, stable layout. The
media card remains present as an empty state, so starting or stopping playback
does not change the content height. The body scrolls only when the available
space is genuinely smaller while the header stays visible. See
[ADR-0006](adr/ADR-0006-use-a-noctalia-dashboard-plugin.md) for the trade-offs.
