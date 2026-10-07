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
  the icons of the apps on the current workspace. The focused window's
  icon is at full opacity with a 4 px `primary` dot centred under it; the
  other icons sit at 50 % opacity, so the active app reads at a glance.
  The separator and the icons disappear when the workspace has no windows.
- Click a pill: focus that workspace; clicking the active one does
  nothing. Click an app icon: focus that window. Long press on either:
  Niri overview, as today. Scroll over the island: previous or next
  workspace. A pill's notification colour clears 3 s after that
  workspace gains focus (the retired DMS plugin did the same with a
  shorter delay).
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
  described below. A long press (500 ms) on the pill opens the Power
  panel, so it is reachable by touch from anywhere (added 2026-10-05).

Panels replace the centre island completely: the pill, the clock and the
music dot are not visible while a panel is open. Panels have no title. The
panel is centred on the same x as the pill and grows from the pill's
shape; closing shrinks back into the pill. Exactly one panel is open at a
time; opening another morphs the current one into it. An open panel also
closes when Niri moves focus to another window or workspace while it is
open (a shortcut, a newly opened window, the focused window closing); a
change to "no window focused" caused by the panel's own keyboard grab is
ignored (decided 2026-10-07). The OSD takes
priority: when a volume or brightness key arrives, any open panel closes
and the OSD shows over the collapsed pill.

| Panel | Trigger | Content |
| --- | --- | --- |
| Home | click on the pill, or `Mod+Return` | Tile grid, see below. |
| Player | click on the music bar | Large cover, title, artist, progress, controls, output picker. Approved 2026-10-04, including the orb, the music bar and the transitions (prototype r4). |
| Wi-Fi, Bluetooth | chevron, long press or right click on their Settings tile | See "Wi-Fi and Bluetooth panels" below the Settings panel. Added 2026-10-07. |
| Settings | `Mod+S` (decided 2026-10-05; `Mod+Shift+S` opens the DMS settings window), or click on the right island | Quick toggles, Sound and Display sliders, notifications, see below. |
| Power | `Mod+Escape` | One row of five square buttons: Lock, Suspend, Log Out, Reboot, Power Off. The first is focused. Approved 2026-10-04. |
| Updates | click on the updates indicator | Approved 2026-10-04. Count and "checked just now" line, fragile packages first in `error` with a one-line reason, then the remaining packages in a scrolling list (name, version jump, source tag). Actions: Update all (runs `system-update` in the terminal, with its fragile prompt), Refresh, Report (opens the last report of ADR-0025). No "skip fragile" action: that would be a partial upgrade. The list comes from `system-update --pending`, a read-only mode to add to the helper. |
| Theme | `Mod+Ctrl+Return` | Light / Dark / Auto segmented control: the control moves at once (optimistic, confirmed by the service), Light and Dark switch DMS smart mode off and then set only the desktop portal colour scheme (`gsettings … color-scheme default|prefer-dark`); DMS follows the portal without its Niri screen transition, which is what made the switch janky (the `theme light|dark` IPC always triggers that transition and is not used). Auto switches smart mode on and re-renders. The bar switches its own palette instantly from the other mode in the same palette file, gliding every colour over 300 ms, and later adopts whatever DMS writes. The bar orchestrates one screen-wide crossfade itself: 300 ms after the click, once the control has slid and the bar has recoloured, it calls Niri's screen transition with a delay long enough for DMS and every template to finish (2000 ms by default, the fastest observed switch from the DMS log; DMS reacts to the portal change in 1 to 5 s, so a slow switch may still show part of the recolour, and the token is tunable), so the desktop recolours unseen and one crossfade reveals the finished state. While DMS works the Theme panel shows a static disabled look (mode control and cards at half opacity, nothing animating, since the screen is frozen) and ignores input; the control never reconciles mid-switch (rules revised 2026-10-05 evening). Then the matugen scheme list as a horizontal carousel of six-dot swatches (DMS setting `matugenScheme`, values such as `scheme-tonal-spot`, `scheme-fruit-salad`). Approved 2026-10-04. |
| Wallpaper | `Mod+Shift+Return` (moves from `Mod+Return`, which becomes Home) | Horizontal carousel of wallpaper thumbnails from the DMS wallpaper folder; scrolls horizontally with the wheel, touchpad and drag as well as the arrow keys; Enter applies. Approved 2026-10-04 on that condition. |
| OSD | volume or brightness key | A slim slider pill over the collapsed pill for 1.5 s; it closes any open panel first and never takes keyboard focus. Approved 2026-10-04. |

**Home panel.** The smarter, combined version of the DMS dashboard: tiles
on a 12 px grid inside a 560 px wide panel, nothing that has its own panel
elsewhere (no music, no calendar, no user block).

| Tile | Content |
| --- | --- |
| Time | Large `HH:mm` stacked, date `zo 04 okt` under it, the whole group centred horizontally and vertically in the tile. |
| Actions row (added 2026-10-05 for touch) | A slim bottom row of icon-only tiles, always shown, in this order: Theme, Wallpaper, Player (while a player exists), Updates, Settings, Power; a tap morphs Home into that panel. |
| Weather | Current: icon, temperature, condition, feels-like, place (Open-Meteo, auto location). Under it an Hourly / Daily segmented control, Hourly selected by default, and a single row of compact cards: hour or day, icon, temperature or high/low. Only human-readable values; no humidity, pressure or visibility. Lower than the DMS weather tab. |
| Performance | Three thin vertical bars with icons: CPU load, CPU temperature, memory. |
| Power | Top row: battery icon, large percentage, state ("Discharging", "Fully charged"). Below it a full-width charge capsule in the Settings slider language, filled to the percentage, `primary`, `error` at 20 % or below, read-only. Then one row of small labelled values: time remaining or time to full, Health, Capacity. Bottom: the power profile as a three-segment control (Power Saver, Balanced, Performance). |

Home approved as prototyped (r3 · tray+) on 2026-10-04.

Optional bottom row, off by default and always as a pair, never one
without the other: Network (SSID, signal, link speed) and Next event
(first calendar entry of today, needs a calendar source).

**Settings panel.** 420 px wide. One 4-column grid with 12 px gaps
(cells of about 90 px); wide tiles span two cells and carry a one-line
state, small tiles span one cell and are icon only. Two rows, no holes:

```text
docked:                                   detached:
| Wi-Fi (wide)     | DND     | Caffeine | | Wi-Fi (wide)     | DND     | Caffeine |
| Bluetooth (wide) | Power profile (wide)| | Bluetooth | Rotation lock | Power profile (wide)|
```

The wide tile alternates sides so the grid reads playful rather than
lopsided (decided 2026-10-05). While the tablet is detached, Bluetooth
shrinks to an icon-only tile and frees the cell for the rotation lock;
power profile always keeps its state line. Tablet mode itself is not in
the grid (it follows the hinge; a shortcut covers the manual case). Night light, colour picker, screenshot, display profile
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
Brightness a cycle through 25, 50, 75, 100, never 0 (the Z13 has no
ambient light sensor). Scrolling over any capsule changes its value by 5
per wheel step, as the DMS sliders do. Muted dims the fill to 40 %, not the row.

The Wi-Fi and Bluetooth tiles carry a full-height chevron zone on their
right (about 40 px, a hairline separating it from the rest of the tile,
`chevron_right`). A click on the main area toggles; the chevron, a long
press and a right click open that tile's own panel. The other tiles have
no secondary action (decided 2026-10-07; replaces opening the DMS
settings window).

**Wi-Fi and Bluetooth panels** (centre states `wifi` and `bluetooth`,
420 px, morphing from Settings). No title; a control row on top: a back
chevron to Settings on the left, the on/off switch with a short state
("On · Home 5G", "On · 2 connected") in the middle, and a button on the
right: `open_in_new` to the DMS settings window (the Wi-Fi tab, or for
Bluetooth the Network tab, since DMS 1.6.2's settings have no Bluetooth page
and its control center cannot open while the own bar runs). Bluetooth adds
`terminal` 8 px left of it, which opens `bluetoothctl` in a terminal.
Escape closes like every panel; the back chevron returns to
Settings. The list below scrolls inside the Settings list maximum.

- *Wi-Fi.* The connected network first, tinted `primary`, then known
  networks, then the rest; 44 px rows with a signal glyph, the SSID and a
  lock glyph when secured. A click connects. An unknown secured network
  expands inline into a password field and a Connect button (the panel
  already holds keyboard focus). Clicking the connected network expands
  it into Disconnect and Forget; a right click on a saved one into Connect
  and Forget. Scanning runs only while the panel is open: Quickshell lists
  unknown networks only while its scanner is on, and the scanner rescans at
  most every 10 s; it stops when the panel closes.
  A static "Scanning…" note sits in the control row's state text for the
  first 4 s after opening (the module does not report when a scan ends).
- *Bluetooth.* Connected devices first with their battery level when
  reported, then paired devices, then devices discovered while the panel
  is open (discovery runs only then). A click connects a paired device; on
  a connected one it expands into Disconnect and Forget; a discovered
  device offers Pair. A failed pair says "Pairing failed"; devices that
  need a PIN or passkey are paired in `bluetoothctl` through the terminal
  button; a passkey dialog is not part of this step.

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
  dominant colour (fallback `primary_container`). Very dark art colours
  are lifted before use: if the HSL lightness is below 0.35 it is raised
  to 0.35 with the hue and saturation kept, so a black cover never yields
  a black orb; in light mode the ring uses `primary` (rules added
  2026-10-05 evening). Around its rim runs a
  travelling light: a conic gradient of two or three album colours plus
  `primary`, 2 px wide, rotating. The audio level drives the rotation
  speed (one turn in about 6 s at rest, down to about 1.5 s at full
  level) and the rim brightness. Internal motion is not readable at this
  size and is not used.
- *Bloom as the beat.* A soft glow around the orb in the rim colours,
  radius at most 8 px beyond the rim, opacity following the low band
  between 0.15 and 0.5 with ~80 ms attack and ~250 ms release. It is the
  only thing that pulses.
- *Nothing else moves while playing.* No drift, no bob, no scaling on
  hover of the pill or anywhere else.
- *Paused or stopped: a smaller, resting orb* (revised 2026-10-05 evening).
  The core shrinks from 16 px to 6 px and loses its rim light and bloom;
  around it a 1 px ring, 12 px in diameter, in the album colour, breathes
  visibly: opacity 0.2 to 0.8 and diameter 12 to 14 px on a 5 s cycle
  (sizes revised 2026-10-05 after the live test: 10 px and a faint ring
  read as a static blob). Nothing else moves. The change between the two states uses the
  island shrink and grow timings: core and rim fade and scale while the
  ring fades the other way; on play the rim spins up from the eased start.
  The 32 px hit area is unchanged. No player at all still hides the orb.
- *Hover: the music bar, centred.* The pill grows symmetrically from its
  centre into the music bar, which is centred on the screen like the
  clock (hidden in this state). The orb glides into the bar as its
  leftmost element; title and artist (marquee when long) and
  previous/play/next fade in from 120 ms. While the bar is open the same
  travelling rim light runs around the bar's edge, so the orb hands its
  life to the bar; on the bar it is livelier than on the orb: 2.5 px wide,
  a brighter gradient with a soft outer glow of about 6 px, and one turn in
  4 s at rest down to 1.2 s at full level (tuned 2026-10-05). No cover image in the bar. Leaving reverses it.
- *Click on the orb or the bar:* the Player panel, grown from the pill
  like every other panel; the real cover appears there. The Player
  carries the rim light too, as a quiet continuation rather than a frame:
  1.5 px, no outer glow, one turn in 8 s at rest down to 3 s at full
  level (added 2026-10-05).

*Now-playing peek* (added 2026-10-05). The music bar also opens by itself
for 5 s (raised from 3 s on 2026-10-05) when what is playing changes, then shrinks back to the orb, so a
song change gets its context without a hover. One trigger: the identity
of the playing track changed, meaning MPRIS track id plus title plus
artist together differ from the last one shown while playback is active
(Firefox reports one track id for every track, so the id alone is not
enough); playback starting after a stop or a pause
longer than 30 s, or a new player starting, counts as the first change.
Never on pause, stop, seek, volume, shuffle or repeat; never on metadata
bursts for the same track (debounce 500 ms plus the identity check);
never on late album art; never while a panel is open, the bar is hidden,
reduce motion is on, or the music bar or Player is already open. A track
change during a peek restarts the 5 s hold; the pointer resting on the
bar turns the peek into a normal hover with the usual leave grace.

*Top-edge wave.* An addition the user asked back in, but as a wave, not
bars: a separate click-through layer along the top 48 px of the screen,
behind the islands. One continuous curve is drawn through the smoothed
band levels (Catmull-Rom or similar through 24 points across the screen
width, amplitude up to 20 px), stroked wide and blurred (blur radius at
least 16 px) in the orb's colours and faded to transparent toward its
bottom edge, peak opacity 0.5 (raised from 0.3 on 2026-10-05, the lower
value was too subtle over the real wallpaper). It must read as a breathing band of light
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

**Attention group** (approved 2026-10-04, do-not-disturb merged into the
bell 2026-10-04 evening). Fixed order from the far right inward:
notifications, updates, Wi-Fi, muted, caffeine. There is no separate
do-not-disturb indicator: the bell shows `notifications_off` while do not
disturb is on, with the count when there are unread notifications and
without it when there are none, and it stays visible in that state even
with zero unread. Each
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
| Notifications (bell + count, crossed bell while do not disturb is on), far right | unread exist, or do not disturb is on | Settings panel scrolled to the list; middle click clears all; right click toggles do not disturb |
| Updates (arrow + count) | packages pending | Updates panel |
| Wi-Fi | off or weak | Settings panel |
| Muted | output muted | unmute; scroll on it changes the volume |
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
always hangs from the island's left padding, items left-aligned, at
least 160 px and at most 280 px wide (the widest entry decides, measured
once when the menu opens), and the island widens leftward only as far as
the menu needs; the geometry is the same whichever disc was clicked, so
no dead space appears. Rows are at least 32 px and grow with their text:
multi-line entries (some apps put status text in their menus) wrap to at
most three lines and never overlap the next row; disabled entries are
dimmed. The group is absent when no tray items exist.

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
| Bar height / exclusive zone | 36 px; islands start 5 px from the top (raised from 3 on 2026-10-05), Niri windows 6 px under them, 8 px from the screen sides and bottom, 6 px gutters |
| Island height collapsed | 30 px |
| Island height in Detail | 48 px |
| Island radius collapsed | 15 px (full pill) |
| Island radius expanded | 20 px |
| Island padding | 10 px horizontal, 6 px vertical |
| Gap between items inside an island | 8 px |
| Hairline separator | 1 px wide, 14 px tall, `outline` at 40 % |
| Island background | `surface_container` at 92 % over the blurred wallpaper, collapsed and expanded (the bar requests blur behind the islands itself through `BackgroundEffect.blurRegion`; the Niri layer rule for `dotfiles-bar` only sets `xray false`) |
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
| Content cross-fade inside an island | 140 ms | ease-out; Detail labels start 60 ms after the grow starts and finish before it settles |
| Hover rest before Detail / leave grace | 250 ms / 120 ms | the hover area never resizes with the island |
| Workspace pill slide | 200 ms | cubic-bezier(0.2, 0.8, 0.2, 1) |
| Indicator appears or disappears in the right island | 180 ms width + opacity | ease-out |
| Tray fans out or folds | 200 ms spacing | cubic-bezier(0.2, 0.8, 0.2, 1) |
| OSD in / out | 160 ms / 240 ms | ease-out / ease-in |
| Orb rim light and bloom | continuous while playing; rotation speed and rim brightness follow the level, bloom follows the low band, 60 fps |
| Orb resting state | core 16 → 6 px and rim/bloom out over the shrink timing, 1 px ring in, ring breath opacity 0.2 ↔ 0.8 and diameter 12 ↔ 14 px over 5 s at ~15 fps |
| Pill grows into the centred music bar | 280 ms, same curve as island grow; content fade-in starts at 120 ms |
| Top-edge wave in / out | 600 ms in, 2 s out, ease-out |
| Audio-driven values | smoothed with ~80 ms attack and ~250 ms release |

Size and position animate; opacity only supports them. No bounces larger
than 2 px. Everything respects a global "reduce motion" switch that drops
durations to 0.

## Open items

- Theme state, answered 2026-10-05: `dms ipc call settings set matugenScheme`
  only saves the key; the bar re-renders by re-setting the current
  wallpaper afterwards, the method docs/dms.md documents.
- Whether the left island needs an expanded state (window titles) later.
- Niri struts in `layout.kdl` are tuned to the DMS bar and may need a pixel
  change for the 36 px bar.
