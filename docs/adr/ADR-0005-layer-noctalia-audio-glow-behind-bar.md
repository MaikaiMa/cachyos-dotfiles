# ADR-0005: Layer Noctalia audio glow behind the bar

- Status: Accepted
- Date: 2026-09-20

## Context

The managed Noctalia bar should gain a subtle, theme-aware audio visualization
without changing its widget and capsule layout. The motion must represent the
actual output spectrum rather than an unrelated looping animation.

Noctalia bar plugins render inside their own widget bounds and cannot paint a
background beneath all three bar zones. Maintaining a patched Noctalia package
would make this visual detail depend on a local fork.

## Decision

Use Noctalia's built-in `audio_visualizer` desktop widget as a transparent
underlay. Desktop widgets render on the Wayland bottom layer, while the
translucent Noctalia bar and Niri background effect render above it. Configure
the visualizer with primary and secondary palette roles, centered mirrored
bands, no background, and no idle display.

Install an idempotent helper that reads the effective `bar.dotfiles` geometry
and active Niri output geometry. It writes a machine-local generated TOML file
under the Noctalia config directory, validates the resulting source config,
and reloads Noctalia only when the content changed. A Noctalia `started` hook
runs the helper after login. Connector names, resolutions, and generated state
remain outside Git.

The first version intentionally synchronizes at Noctalia startup and when the
helper is run explicitly. Live monitor hotplug watching will only be added if
the visual result proves worth keeping.

## Consequences

- Spectrum motion comes from Noctalia's native PipeWire monitor stream.
- The visualizer follows theme palette changes without regenerating fixed RGB
  values.
- Bar margins, thickness, padding, edge position, and radius determine the
  generated placement. The spectrum fills the bar's padded content height and
  keeps a radius-derived safe distance from its rounded ends, while the
  existing bar and capsule configuration stays intact.
- Selecting the fallback bar removes the generated visualizer on the next sync.
- Display changes during a session require another sync in this first version.
- A GUI-managed desktop widget order can exclude declarative widgets; this
  interaction must be checked before managing other desktop widgets in the GUI.

## Alternatives considered

- **Patch or fork Noctalia:** gives a true bar-background renderer but adds a
  package maintenance burden for a cosmetic feature.
- **Custom bar plugin:** receives spectrum data but is clipped to its own widget
  slot and cannot sit beneath existing widgets.
- **Cava plus a separate layer-shell client:** duplicates Noctalia's audio
  capture and adds another long-running program and rendering surface.
- **Independent animated gradients:** visually similar, but they do not clearly
  communicate the music and keep animating without meaningful audio input.
