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
- Approved as prototyped on 2026-10-04; keep as is.

### Centre: dynamic information

Collapsed pill, left to right: weather icon, hairline separator, time
`HH:mm`, hairline separator, battery icon. Icons only, no text except the
time. Left of the pill, with a 6 px gap, the music dot (see "Music" below),
absent when no MPRIS player exists.

The centre island has exactly two interactions on the pill itself:

- **Hover (pointer rests 250 ms): Detail.** The pill grows one row to
  48 px and every icon gets one 11 px label under it in
  `on_surface_variant`: "18°" under the weather icon (never the condition
  text), "Zo 04-10" under the time, "82%" under the battery. No separators
  in Detail, no second text line, the clock does not move. Approved
  2026-10-04; keep as is.
- **Click or tap: Home panel.** The pill is replaced by the Home panel
  described below.

Panels replace the centre island completely: the pill, the clock and the
music dot are not visible while a panel is open. Panels have no title. The
panel is centred on the same x as the pill and grows from the pill's
shape; closing shrinks back into the pill. Exactly one panel is open at a
time; opening another morphs the current one into it. The OSD takes
priority: when a volume or brightness key arrives, any open panel closes
and the OSD shows over the collapsed pill.

| Panel | Trigger | Content |
| --- | --- | --- |
| Home | click on the pill, or `Mod+Return` | Tile grid, see below. |
| Player | click on the music bar | Large cover, title, artist, progress, controls, output picker. Approved 2026-10-04, including the orb, the music bar and the transitions (prototype r4). |
| Settings | `Mod+Shift+S` (today's settings shortcut), or click on the right island | Quick toggles, Sound and Display sliders, notifications, see below. |
| Power | `Mod+Escape` | One row of five square buttons: Lock, Suspend, Log Out, Reboot, Power Off. The first is focused. Approved 2026-10-04. |
| Updates | click on the updates indicator | Approved 2026-10-04. Count and "checked just now" line, fragile packages first in `error` with a one-line reason, then the remaining packages in a scrolling list (name, version jump, source tag). Actions: Update all (runs `system-update` in the terminal, with its fragile prompt), Refresh, Report (opens the last report of ADR-0025). No "skip fragile" action: that would be a partial upgrade. The list comes from `system-update --pending`, a read-only mode to add to the helper. |
| Theme | `Mod+Ctrl+Return` | Light / Dark / Auto segmented control (`dms ipc call theme light|dark`), then the matugen scheme list as a horizontal carousel of six-dot swatches (DMS setting `matugenScheme`, values such as `scheme-tonal-spot`, `scheme-fruit-salad`). Approved 2026-10-04. |
| Wallpaper | `Mod+Shift+Return` (moves from `Mod+Return`, which becomes Home) | Horizontal carousel of wallpaper thumbnails from the DMS wallpaper folder; scrolls horizontally with the wheel, touchpad and drag as well as the arrow keys; Enter applies. Approved 2026-10-04 on that condition. |
| OSD | volume or brightness key | A slim slider pill over the collapsed pill for 1.5 s; it closes any open panel first and never takes keyboard focus. Approved 2026-10-04. |

**Home panel.** The smarter, combined version of the DMS dashboard: tiles
on a 12 px grid inside a 560 px wide panel, nothing that has its own panel
elsewhere (no music, no calendar, no user block).

| Tile | Content |
| --- | --- |
| Time | Large `HH:mm` stacked, date `zo 04 okt` under it, the whole group centred horizontally and vertically in the tile. |
| Weather | Current: icon, temperature, condition, feels-like, place. Under it an Hourly / Daily segmented control, Hourly selected by default, and a single row of compact cards: hour or day, icon, temperature or high/low. Only human-readable values; no humidity, pressure or visibility. Lower than the DMS weather tab. |
| Performance | Three thin vertical bars with icons: CPU load, CPU temperature, memory. |
| Power | Top row: battery icon, large percentage, state ("Discharging", "Fully charged"). Below it a full-width charge capsule in the Settings slider language, filled to the percentage, `primary`, `error` under 15 %, read-only. Then one row of small labelled values: time remaining or time to full, Health, Capacity. Bottom: the power profile as a three-segment control (Power Saver, Balanced, Performance). |

Home approved as prototyped (r3 · tray+) on 2026-10-04.

Optional bottom row, off by default and always as a pair, never one
without the other: Network (SSID, signal, link speed) and Next event
(first calendar entry of today, needs a calendar source).

**Settings panel.** 420 px wide. One 4-column grid with 12 px gaps
(cells of about 90 px); wide tiles span two cells and carry a one-line
state, small tiles span one cell and are icon only. Two rows, no holes:

```text
| Wi-Fi (wide)         | Bluetooth (wide)     |
| Power profile (wide) | Do not disturb | Caffeine |
```

Tablet mode is not in the grid (it follows the hinge; a shortcut covers
the manual case). Night light, colour picker, screenshot, display profile
and the settings window stay shortcut-only.

Under the grid three sliders, Volume, Microphone, Brightness, each a
full-width 32 px capsule with 8 px between them, no thumb: the whole
capsule is the track, the fill in `primary` runs from the left edge and
its edge is the handle, 0 and 100 touch the capsule edges. Two fixed
zones sit on top of the track and never move: a 32 px icon zone on the
left and a 44 px value zone on the right showing "62%" (no space). Icon
and value are each drawn twice, in `on_surface` on the empty track and
in `on_primary` clipped to the fill width, so their colour flips exactly
where the fill passes. Press and drag anywhere sets the value; a click on
the icon zone without movement toggles: Volume mute, Microphone mute,
Brightness auto when the machine exposes it, otherwise a cycle through
25, 50, 75, 100, never 0. Muted dims the fill to 40 %, not the row.

Notifications only when there are any: the section is absent on an empty
list and the panel ends at the brightness slider. With items: "Clear all"
top right, the list scrolls inside a maximum height of 240 px, click-x
per item.

Approved as prototyped (r3 · sliders) on 2026-10-04; keep as is.

**Music.** The orb is a presence, not a visualiser: a small thing that is
visibly alive, in the manner of the iOS 18 Siri edge glow. It sits 6 px
left of the pill, is absent when no MPRIS player exists, and never
changes size.

- *Solid core, living rim.* A solid 16 px sphere in the album art's
  dominant colour (fallback `primary_container`). Around its rim runs a
  travelling light: a conic gradient of two or three album colours plus
  `primary`, 2 px wide, rotating. The audio level drives the rotation
  speed (one turn in about 6 s at rest, down to about 1.5 s at full
  level) and the rim brightness. Internal motion is not readable at this
  size and is not used.
- *Bloom as the beat.* A soft glow around the orb in the rim colours,
  radius at most 8 px beyond the rim, opacity following the low band
  between 0.15 and 0.5 with ~80 ms attack and ~250 ms release. It is the
  only thing that pulses.
- *Nothing else moves.* No breath, no drift, no bob, no scaling on hover
  of the pill or anywhere else. On pause the rim slows to one turn in
  about 12 s and the bloom settles at 0.1; the orb never looks dead while
  a player exists.
- *Hover: the music bar, centred.* The pill grows symmetrically from its
  centre into the music bar, which is centred on the screen like the
  clock (hidden in this state). The orb glides into the bar as its
  leftmost element; title and artist (marquee when long) and
  previous/play/next fade in from 120 ms. While the bar is open the same
  travelling rim light runs around the bar's edge, so the orb hands its
  life to the bar. No cover image in the bar. Leaving reverses it.
- *Click on the orb or the bar:* the Player panel, grown from the pill
  like every other panel; the real cover appears there.

*Top-edge wave.* An addition the user asked back in, but as a wave, not
bars: a separate click-through layer along the top 48 px of the screen,
behind the islands. One continuous curve is drawn through the smoothed
band levels (Catmull-Rom or similar through 24 points across the screen
width, amplitude up to 20 px), stroked wide and blurred (blur radius at
least 16 px) in the orb's colours and faded to transparent toward its
bottom edge, peak opacity 0.3. It must read as a breathing band of light
whose shape moves with the music; no individual band may be
distinguishable. Fades in over 600 ms when playback starts and out over
2 s on pause; off under reduce motion; off by default on external
monitors; one toggle.

Approved as prototyped (r4 · music) on 2026-10-04: orb, top-edge wave,
hover music bar and the transitions. The Player panel is approved.

### Right: status

One island, two groups separated by a hairline: the tray on the left, the
attention indicators on the right. The island is read from its right
edge inward, so everything grows and orders leftward. Nothing in it
grows downward on hover.

**Attention group** (approved 2026-10-04). Fixed order from the far right inward:
notifications, updates, Wi-Fi, muted, do not disturb, caffeine. Each
indicator is one 16 px icon plus a count where it matters; its state is
in the glyph itself (signal strength, struck speaker, moon, cup) and in
the tint (updates turn `error` when a fragile package is pending). No
hover labels. Each indicator is a permanent 24 px tall pill hit area
(radius 12 px, 8 px horizontal padding, 2 px to its neighbours, 4 px
between icon and count, digits vertically centred on the icon); the
pill at either end of the island sits 3 px inside the island edge so its
12 px corner is concentric with the island's 15 px corner; hover only
tints that pill, nothing moves or grows. Every indicator has one click:

| Indicator | Shown when | Click |
| --- | --- | --- |
| Notifications (bell + count), far right | unread exist | Settings panel scrolled to the list; middle click clears all |
| Updates (arrow + count) | packages pending | Updates panel |
| Wi-Fi | off or weak | Settings panel |
| Muted | output muted | unmute; scroll on it changes the volume |
| Do not disturb | on | turns it off |
| Caffeine | idle inhibit on | turns it off |

**Tray group.** Collapsed to one stack at the left end of the island,
directly left of the hairline: the first two tray icons at their normal
16 px size, each on a 24 px circular disc in `surface_container_high`
with a 1 px ring in the island colour, overlapped by about 10 px so the
discs read as a stack; the other icons are not drawn while folded. A
small chevron pointing left sits left of the stack as the only
affordance; there is no count. Hover or tap fans the row out to the
LEFT: the rightmost disc is anchored and never moves, every other disc
slides leftward into its own slot with a 4 px gap so no two discs overlap
when fanned, the hidden icons emerge from under the stack while fading
in, and the chevron glides to the far left and rotates to point right.
Nothing scales. Folding reverses it. Click on an icon
activates the app; right click opens its DBus menu as the island growing
down into a short list. The menu is not anchored to the clicked disc: it
always hangs from the island's left padding, items left-aligned, 160 px
wide, and the island widens leftward only as far as the menu needs; the
geometry is the same whichever disc was clicked, so no dead space
appears. The group is absent when no tray items exist.

Stacking order: an open centre panel is always drawn above the right
island, including a fanned tray; the right island never overlaps a panel.

On a normal day the island is the tray chip alone; on an empty day with
no tray it is absent. Bluetooth, power profile, night light, dark mode
and the power button are not shown; they live in the Settings panel and
in shortcuts. Click or tap on the island background (not on an
indicator) opens the Settings panel in the centre island.

## Visibility

The bar does not auto-hide. A shortcut toggles it fully hidden and shown,
with the exclusive zone following so windows reflow. Islands exist on
every screen; the music dot and OSD only on the screen with the pointer.

## Tokens

| Token | Value |
| --- | --- |
| Bar height / exclusive zone | 36 px |
| Island height collapsed | 30 px |
| Island height in Detail | 48 px |
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
| Panel width | Settings 420 px, Player 360 px, Power 5 x 72 px buttons, Home, Theme and Wallpaper 560 px |
| Tile grid | 12 px gap, tile radius 16 px, tile background `surface_container_high` |
| Settings grid | 4 columns, 12 px gap, tile radius 16 px, tile height 64 px |
| Settings slider | full-width capsule 32 px tall, 8 px gap, icon zone 32 px, value zone 44 px |
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
| Tray fans out or folds | 200 ms spacing | cubic-bezier(0.2, 0.8, 0.2, 1) |
| OSD in / out | 160 ms / 240 ms | ease-out / ease-in |
| Orb rim light and bloom | continuous; rotation speed and rim brightness follow the level, bloom follows the low band, 60 fps; slow and dim on pause |
| Pill grows into the centred music bar | 280 ms, same curve as island grow; content fade-in starts at 120 ms |
| Top-edge wave in / out | 600 ms in, 2 s out, ease-out |
| Audio-driven values | smoothed with ~80 ms attack and ~250 ms release |

Size and position animate; opacity only supports them. No bounces larger
than 2 px. Everything respects a global "reduce motion" switch that drops
durations to 0.

## Open items

- Theme state: confirm that setting `matugenScheme` through
  `dms ipc call settings set` re-renders the palette without a restart.
- Whether the left island needs an expanded state (window titles) later.
- `system-update --pending` (one line per package: source, name, old and
  new version, fragile flag) still has to be added to the helper with a
  test; ADR-0025 gets a note when it lands.
- Niri struts in `layout.kdl` are tuned to the DMS bar and may need a pixel
  change for the 36 px bar.
