# Bar design: three dynamic islands

This is the design contract for the own Quickshell bar
([ADR-0027](adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md),
[shell.md](shell.md)). Widget and panel work is measured against it. The
interactive prototype in [design/bar-prototype.html](design/bar-prototype.html)
shows every state below at real size; open it in a browser.

## Principles

1. **Clean, minimal, only what is needed.** A widget earns its place by
   answering a question at a glance. Anything else lives one tap away.
2. **Islands transform, popups do not exist.** Every panel is one of the
   three islands growing in place and shrinking back. Nothing opens next to
   or below the bar as a separate window.
3. **Keyboard and mouse first, touch always works.** Every state has a
   shortcut and closes on Escape. Click and tap are the primary verbs.
   Hover is an addition that reveals detail where a pointer exists and is
   never the only way to reach information.
4. **Fluid, fast, snappy.** Motion explains where things come from and go
   to; it never makes the user wait.
5. **The clock never moves.** It is the fixed point of the centre island;
   everything else grows away from it.

## Architecture the design depends on

A layer-shell surface cannot draw outside its own size. The bar window is
therefore taller than the bar: it covers the full expansion height of the
largest panel, keeps a 36 px exclusive zone so windows tile below the bar,
and sets an input mask that only covers the visible islands. Everything
outside an island is click-through to the desktop. Each island is a
component that owns its collapsed and expanded sizes; the mask follows the
islands' geometry.

## Islands

### Left: workspaces and apps

- Collapsed: one island. Workspace pills as today (compact, the active one
  filled with `primary`, a pill turns `error` when a window on that
  workspace has a notification waiting), then a small `>` separator, then
  the icons of the apps on the current workspace. The separator and the
  icons disappear when the workspace has no windows.
- Click a pill: focus that workspace. Click an app icon: focus that window.
  Long press on either: Niri overview, as today. Scroll over the island:
  previous or next workspace.
- Switching workspaces animates the filled pill sliding to its new place
  and the icon row cross-fading.
- Expanded state: none in this phase.

### Centre: dynamic information

Collapsed pill, left to right: weather icon, hairline separator, time
`HH:mm`, hairline separator, battery icon. Icons only, no text except the
time. Right of the pill, with a 6 px gap, the music dot: a 10 px circle
in `primary` that moves with the audio (cava levels) and is absent when no
MPRIS player exists.

States of the centre island, each reached by a shortcut or a click and left
with Escape, the same shortcut, or a click outside:

| State | Trigger | Content |
| --- | --- | --- |
| Detail | hover rests 250 ms, or click on the pill | Pill grows downward: date under the time, percentage and time-to-empty under the battery, temperature and condition under the weather icon. |
| Music bar | hover on the dot, or click on the dot | The dot grows to the right into a bar: cover, title and artist, previous/play/next. The pill stays. |
| Player | click on the music bar | The whole centre island becomes the player: large cover, title, artist, progress, controls, output picker. |
| Settings | `Mod+Shift+S` (today's settings shortcut), or click on the right island | Quick toggles grid, Sound and Display sliders, notifications list, in that order, tighter than the reference. |
| Power | `Mod+Escape` | One row of five square buttons: Lock, Suspend, Log Out, Reboot, Power Off. The first is focused. |
| Theme | shortcut to be chosen | Light / Dark / Auto segmented control (`dms ipc call theme light|dark`), then the matugen scheme list as a horizontal carousel of six-dot swatches (DMS setting `matugenScheme`, values such as `scheme-tonal-spot`, `scheme-fruit-salad`). |
| Wallpaper | `Mod+Return` (today's wallpaper shortcut) | Horizontal carousel of wallpaper thumbnails from the DMS wallpaper folder, Enter applies. |
| OSD | volume or brightness key | A slim slider overlays the current state for 1.5 s and never changes it. It takes no keyboard focus. |

Only one of Detail, Music bar, Player, Settings, Power, Theme, Wallpaper
is active at a time; a new one replaces the current one with a morph, not
a close-then-open. OSD is an overlay on top of any of them.

Quick toggles, in order of importance, first row to last: Wi-Fi, power
profile, Bluetooth, caffeine, do not disturb, tablet mode. Each toggle is a
rounded rectangle with an icon circle, a title and a one-line state, the
active one in `primary` with `on_primary` text.

### Right: status

Collapsed: the tray icons of background apps, then conditional indicators
that only exist while their state is worth knowing:

| Indicator | Shown when |
| --- | --- |
| Wi-Fi | disconnected or weak |
| Muted | output muted |
| Do not disturb | on |
| Caffeine | idle inhibit on |
| Notifications | unread exist, as a dot with a count |
| Updates | packages pending, as a count |

On a normal day the island is only the tray. Bluetooth, power profile,
night light, dark mode and the power button are not shown; they live in
the Settings state and in shortcuts. Click or tap on the right island opens
the Settings state in the centre island; the right island itself does not
expand in this phase. Hover on an indicator shows a one-line tooltip inside
the island (the island grows by one line).

## Visibility

The bar does not auto-hide. A shortcut toggles it fully hidden and shown,
with the exclusive zone following so windows reflow. Islands exist on
every screen; the music dot and OSD only on the screen with the pointer.

## Tokens

| Token | Value |
| --- | --- |
| Bar height / exclusive zone | 36 px |
| Island height collapsed | 30 px |
| Island radius collapsed | 15 px (full pill) |
| Island radius expanded | 20 px |
| Island padding | 10 px horizontal, 6 px vertical |
| Gap between items inside an island | 8 px |
| Hairline separator | 1 px wide, 14 px tall, `outline` at 40 % |
| Island background | `surface` at 92 % over the blurred wallpaper (Niri blur applies to the layer namespace `dotfiles-bar`) |
| Island border | none |
| Text | Inter Variable 13 px, 500 weight; secondary text 11 px, `on_surface_variant` |
| Icons | 16 px, `on_surface`; 18 px inside toggles |
| Accent | `primary`; attention `error`; on-accent text `on_primary` |
| Expanded panel width | Settings 420 px, Player 360 px, Power 5 x 72 px buttons, Theme and Wallpaper 560 px |
| Shadow on expanded islands | 0 8 px 24 px `shadow` at 35 % |

Colours come from the DMS palette (`Colors.qml`); the names above are the
Material keys of that file.

## Motion

| Transition | Duration | Curve |
| --- | --- | --- |
| Island grows or morphs between states | 280 ms | spring-like: cubic-bezier(0.2, 0.8, 0.2, 1) |
| Island shrinks | 220 ms | cubic-bezier(0.4, 0, 0.2, 1) |
| Content cross-fade inside an island | 140 ms | ease-out |
| Workspace pill slide | 200 ms | cubic-bezier(0.2, 0.8, 0.2, 1) |
| Indicator appears or disappears in the right island | 180 ms width + opacity | ease-out |
| OSD in / out | 160 ms / 240 ms | ease-out / ease-in |
| Music dot | continuous, follows audio levels, 60 fps; idle breathing 2 s when playing but quiet |

Size and position animate; opacity only supports them. No bounces larger
than 2 px. Everything respects a global "reduce motion" switch that drops
durations to 0.

## Open items

- Theme state: confirm that setting `matugenScheme` through
  `dms ipc call settings set` re-renders the palette without a restart.
- Tooltip texts for the right-island indicators.
- Whether the left island needs an expanded state (window titles) later.
- Niri struts in `layout.kdl` are tuned to the DMS bar and may need a pixel
  change for the 36 px bar.
