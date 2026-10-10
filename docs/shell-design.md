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
islands' geometry. What animates continuously with the music (the orb, the
top-edge wave) gets a small surface of its own, because a frame in the
screen-tall window makes the compositor redraw the whole screen.

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
| Player | click on the music bar | Large cover, title, artist, progress, controls, output picker. Approved 2026-10-04, including the orb, the music bar and the transitions (prototype r4). Hovering the cover dims it with an "open" glyph, and a click or Enter brings the playing app to the front (MPRIS Raise, else its Niri window) and closes the panel (added 2026-10-07). |
| Sound, Display | chevron zone of the Volume or Microphone capsule (Sound) or the Brightness capsule (Display) | See "Sound panel" and "Display panel" below the Settings panel. Added 2026-10-07. |
| Wi-Fi, Bluetooth | chevron, long press or right click on their Settings tile | See "Wi-Fi and Bluetooth panels" below the Settings panel. Added 2026-10-07. |
| Settings | `Mod+S` (decided 2026-10-05; `Mod+Shift+S` opens the DMS settings window), or click on the right island | Quick toggles, Sound and Display sliders, notifications, see below. |
| Power | `Mod+Escape` | One row of five square buttons: Lock, Suspend, Log Out, Reboot, Power Off. The first is focused. Approved 2026-10-04. |
| Updates | click on the updates indicator | Approved 2026-10-04. Count and "checked just now" line, fragile packages first in `error` with a one-line reason, then the remaining packages in a scrolling list (name, version jump, source tag). Actions: Update all (runs `system-update` in the terminal, with its fragile prompt), Refresh, Report (opens the last report of ADR-0025). No "skip fragile" action: that would be a partial upgrade. The list comes from `system-update --pending`, a read-only mode to add to the helper. |
| Theme | `Mod+Ctrl+Return` | Light / Dark / Auto segmented control: the control moves at once (optimistic, confirmed by the service), Light and Dark call the `theme light|dark` IPC, which switches DMS at once, turns smart mode off and sets the desktop portal colour scheme for other applications (revised 2026-10-10: the earlier portal-only route let DMS follow `gsettings`, but DMS polls the portal about every 10 s, so switches landed 0 to 10 s late and a quick second click was reverted). Auto switches smart mode on and re-renders. The bar switches its own palette instantly from the other mode in the same palette file, gliding every colour over 300 ms, and later adopts whatever DMS writes. The bar orchestrates one screen-wide crossfade: 300 ms after the click, once the control has slid and the bar has recoloured, it makes the theme call, and right after it re-requests Niri's screen transition with a delay long enough for DMS and every template to finish (1400 ms by default, tunable; Niri replaces DMS's own 0 ms transition and keeps the frozen frame; a blank DMS toast behind the frozen screen makes DMS paint, since its QML timers only advance while it renders), so the desktop recolours unseen and one crossfade reveals the finished state. While DMS works the Theme panel shows a static disabled look (mode control and cards at half opacity, nothing animating, since the screen is frozen) and ignores input; the control never reconciles mid-switch (rules revised 2026-10-05 evening). Then the matugen scheme list as a horizontal carousel of six-dot swatches (DMS setting `matugenScheme`, values such as `scheme-tonal-spot`, `scheme-fruit-salad`). Approved 2026-10-04. |
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
the grid (it follows the hinge; a shortcut covers the manual case). Night
light lives in the Display panel (decided 2026-10-07); colour picker,
screenshot, display profile and the settings window stay shortcut-only.

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

**Slider chevrons** (decided 2026-10-07). The Volume, Microphone and
Brightness capsules carry a 40 px chevron zone at their right end, the
same pattern as the Wi-Fi and Bluetooth tiles: a hairline, then
`chevron_right`. The fill runs from 0 to 100 over the capsule minus that
zone; the 44 px value zone sits left of the hairline. A press that starts
in the chevron zone never drags, a drag that ends over it sets 100, and
Enter, the menu key or a right click on a focused capsule opens the panel
(Right keeps stepping the value). No long press: on touch people hold
before they drag. Volume and Microphone open the Sound panel, Brightness
the Display panel.

**Sound panel** (centre state `sound`, 420 px, morphing from Settings).
Control row: back to Settings, a state such as "Speakers · 44%" without a
switch, and `open_in_new` to the DMS audio settings. Sections, each only
when it has rows:

- *Output:* 44 px rows with a type glyph (speaker, headphones, Bluetooth,
  monitor) and the friendly name from the active port ("Speakers",
  "Headphones"), the default tinted `primary`; a click makes it the
  default.
- *Input:* the same rows ("Internal Microphone"), with a live level bar
  under the default input while the panel is open.
- *Apps:* one row per application with its icon, name and a compact
  capsule slider plus mute; streams of the same application are grouped
  into one row whose slider moves all of them (Blip keeps five idle
  streams). Streams are tracked only while the panel is open.

Left out on purpose: port and profile switching (automatic), per-app
routing, channel balance, volume above 100 %.

**Display panel** (centre state `display`, 420 px). Control row: back to
Settings, the night-light switch with "On · 4500 K" or "Off", and
`open_in_new` to the DMS gamma settings (the schedule can only be changed
there). Rows, in this order:

1. Night light temperature as a capsule (DMS's range), and a read-only
   schedule line.
2. Brightness, the same capsule as in Settings.
3. Keyboard backlight as an Off / Low / Medium / High segmented control,
   only while the keyboard cover is attached.
4. Rear window light as Off / Low / Medium / High, with a read-only colour
   dot showing the theme colour it follows.

Left out on purpose: external monitors over DDC (needs a new package and
permissions), gamma and contrast, refresh rate, scale and rotation.

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
per item. Since the bar owns the daemon (ADR-0028) a row also expands
into its full body, actions and reply field; see "Notifications" below
the right island.

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

*Privacy dots* (decided 2026-10-07; verified live the same day with a Meet call and a screen share from Zen). Right of the centre island,
mirroring the orb on its left: one 6 px dot per active capture, 4 px
apart, 6 px from the island's right edge, centred on the top row. Fixed
colours that do not follow the wallpaper palette: orange `#FF9F0A` for
the microphone, green `#30D158` for the camera, blue `#0A84FF` for a
screen share or cast, in that order from the island outward. The dots
follow the island's right edge through Detail, the music bar and every
panel, so they never disappear while something records, including while
the bar is hidden: then they stay where the collapsed island sits. They are steady:
they fade in and out over the crossfade duration and never pulse. No
interaction in this version; a click listing the apps may follow. The
bar's own audio capture for the visualiser does not count as microphone
use. While the bar is hidden and at least one dot is active, the dots
glide to the screen centre over the island's grow timing and sit in a
mini island: a pill of the island surface (16 px tall, 6 px horizontal
padding, full radius, same opacity and blur) centred on the clock's x at
the islands' top. It appears only in that state and fades with the
island's shrink timing; on show the pill dissolves and the dots glide
back to the island's right edge (refined 2026-10-07 after the live test:
bare dots without the island looked like a glitch).

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
monitors; one toggle. Since 2026-10-07 the layer sits under the windows
(Niri's Bottom layer), so its lowest few pixels pass under the tops of
tiled windows instead of over them.

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

### Notifications

Added 2026-10-08 with
[ADR-0028](adr/ADR-0028-own-the-notification-daemon-in-the-bar-for-the-niri-session.md):
the bar is the notification daemon in the Niri session, so a notification
is shown once as a peek, counted in the bell, listed in Settings and kept
in the bar's own history. Nothing opens next to the bar; principle 2
holds for notifications too.

**Peek.** A notification replaces the right island, the way the music bar
replaces the centre pill (rethought 2026-10-08 after the first live
build: rows sitting next to the tray and the indicators were noise, and
the column under the bell was wasted space). When a notification arrives
the right island morphs into a stack of notification rows; nothing else
is drawn in it: no tray, no indicators, no bell. When the last row leaves,
the island morphs back into the status island and the bell with its count
appears with the indicator animation; that morph is what links the
notification to the bell, so the bell does not need to sit beside the
rows. On an empty day with no tray and nothing to attend, the island
appears as the stack and morphs back into a bell-only island. The
indicators are out of sight for the hold; they are status, not alarms.
The stack lives in the right island because the bell is what counts it
and because the centre must stay free for the clock, the OSD, the panels
and the music bar (decided 2026-10-08).

Geometry (settled 2026-10-10, prototype r8): the island keeps its right
edge and is always 360 px wide while the stack shows (the Player panel
width; a width that followed the text made the blob a different shape
every time), capped only by the 8 px clearance from the centre island on
narrow screens, truncating the text instead; it grows downward one row at
a time. Island radius 20 px (expanded), padding 10 px horizontal and 8 px
vertical. Rows are bare content, no surface of their own (tried in r6
and rejected: it took away the blob-like nature), 48 px tall with 12 px
between them, separated by a full-width hairline, 1 px `outline` at
12 %, centred in the gap and never drawn under the last row. Inside a
row, left to right: the app's icon on a 26 px disc (the same icon choice
as the Settings row: the app's own icon first, the notification image
only when the app has none), 10 px, then two lines, the summary (13 px,
500) over one line of body (11 px, `on_surface_variant`, markup
stripped), both truncated with an ellipsis before the dismiss glyph's
area (28 px reserved at the right). A critical notification sets only its
summary in `error`; a low one looks like a normal one. Images and inline
reply are not shown in the peek; they are one click away in the list.

*Dismiss on hover.* A 16 px `close` glyph in `on_surface_variant` sits
8 px from the row's top and right edges with a 24 px hit area. It fades
in with the hover rest (250 ms) and out after the leave grace; hovering
it tints it `on_surface`. A click dismisses the row, which leaves without
a blob. The long press that reveals the actions on touch reveals it too.
Middle click keeps dismissing without a hover.

*Actions on hover* (settled 2026-10-10). A row is compact by default and
shows no actions. When the pointer rests on it (250 ms, the hover rest
delay) a row that has sender actions grows from 48 to 80 px (200 ms, the
tray curve) and the action labels slide up from under the body while
fading in: plain text, no background, 12 px at 500 weight, sentence
case, left-aligned with the text column, 24 px between labels, each in a
32 px tall hit zone; the default action first in `primary`, the others
in `on_surface`, at most three (the rest are in the list). `error` is
reserved for a destructive action the bar can recognise, which the
notification specification does not mark, so it is unused for now. Rows
beneath slide down with the growth; the island width does not change.
Leaving folds the labels after the leave grace. On touch, where there
is no hover, a long press (500 ms) on the row reveals the actions and a
tap outside them folds them. A row with no actions never grows on hover;
the hover only pauses its hold.
Hold: 5 s for normal urgency, 3 s for low, and a critical notification
stays until it is clicked or dismissed. A sender's `expireTimeout` is
honoured when it is positive, clamped to 2 to 15 s; 0 or absent means
the default. The pointer resting on a row pauses that row's hold, as the
now-playing peek turns into a hover, and leaving restarts it with the
usual leave grace. Transient notifications peek like any other but never
enter the list or the count.

*Stacking* (decided 2026-10-08). Each notification is its own row with
its own hold. A notification that arrives while the stack is shown adds
a row on top: the island grows downward by one row (the island grow
timing) and the existing rows slide down, so the newest is always the
top row. At most three rows are shown; a fourth arriving pushes the
bottom row out early, and that one is simply in the count and the list
like any expired row. Rows leave one by one as their holds end, each
collapsing with the shrink timing while the rows below it move up,
until the island morphs back. A sender that updates an existing
notification through `replaces_id` (progress, "3 new messages") updates
its row in place with a cross-fade and restarts that row's hold; it
never adds a row. A burst of more than three within one hold therefore
shows the last three and counts the rest; there is no separate "N new"
row for a burst, only for what arrived while the bar could not show
peeks (below). A fanned tray or an open tray menu finishes first (the
menu closes, the tray folds), then the island morphs into the stack.

*Disc blobs* (settled 2026-10-10). A row that leaves while other rows
remain, because its hold ended or a fourth row pushed it out, does not
vanish into the count: it breaks out of the island as its own small
blob below it. The row shrinks into its 26 px icon disc, the disc
travels down through the island's bottom edge, grows to 30 px as it
clears the edge, and settles 8 px below the island as a separate circle
in the island background (`surface_container` at 92 % over the blurred
wallpaper, with the island shadow). Blobs are right-aligned with the
island's right edge, the newest on the right, 8 px apart, at most six;
further ones collapse into a "+N" blob on the far left. A click on a
blob re-peeks that notification: it returns to the stack as the top row
with its actions and dismiss glyph, its hold restarts and the blob is
gone (decided 2026-10-10; this is the one way back into the stack, by
explicit intent, and it previews how a pinned blob will open). The "+N"
blob opens Settings scrolled to the list, since it stands for several.
Blobs follow the island's bottom edge while it grows or shrinks. A row dismissed by a
click, or closed by running an action, leaves without a blob; the last
row never makes one. Blobs do not climb back into the stack on their own
when a slot frees up (decided 2026-10-10: a blob either expired or had its moment,
and climbing back would keep the island replaced for the length of a
burst and move things under the reader's eyes). When the last row's hold
ends, the island morphs back into the status island and the blobs slide
up into the bell's position while shrinking to 16 px and fading (shrink
timing), so the count appears where they vanished. The blob size is a
single token so a later pinned state can use a smaller one.
Clicks on the peek: the text runs the default action when the sender has
one, otherwise it brings the app's window to the front (Niri focus by the
app key matching already used for the workspace pills) and marks the
notification seen; an action pill invokes that action; both close the
notification with reason "dismissed by user" unless the sender marked it
resident. Middle click dismisses without acting, right click opens
Settings scrolled to the list. The peek never takes keyboard focus; there
is nothing to type in it and Escape is not needed.

No peek, and the notification goes straight to the count and the list,
while: do not disturb is on (a critical one still peeks); the bar is
hidden; a centre panel is open (the Settings list updates live instead);
the session is locked (read from logind's `LockedHint`, which DMS sets;
to be confirmed in the build); or the focused window is fullscreen and
the bar is not visible over it. What arrived while locked or hidden
shows one combined "N new notifications" row without actions when the
bar is visible again, whose click opens the list; never a backlog of
single peeks. Reduce motion does not suppress
peeks: a notification is information, not decoration, so the peek shows
with every duration at 0 and the same hold. The now-playing peek and a
notification peek can be shown at the same time, one in each island.

*Clear all from the stack* (decided 2026-10-10). As long as the stack
shows, a clear-all blob sits at the far left of the blob row, left of
"+N" when that exists and as the only blob when there are none: the
blob size, the island background, a 16 px `close` glyph in
`on_surface_variant` that tints `on_surface` on hover. It appears and
leaves with the stack's morph. A click dismisses every row and blob and
morphs the island back with nothing counted. A hover-only reveal was
tried first and dropped the same day: on the trackpad the pointer lost
it too easily. Middle click on the island outside the rows (padding
and gaps) or on any blob does the same without the hover, as the mouse
shortcut; middle click on a row keeps dismissing only that row. A text label inside
the island was rejected because it would change the island's height on
hover.

*Keys* (decided 2026-10-10; the bar's bind pattern of a panel on
`Mod+letter` with Shift and Ctrl siblings): `Mod+N` toggles Settings
scrolled to the list, the keyboard twin of the bell click, also while
the stack shows; `Mod+Shift+N` clears all (rows, blobs and the list,
nothing counted); `Mod+Ctrl+N` toggles do not disturb. All three carry
a hotkey overlay title.

**Bell and count.** Unchanged in role: the count is the number of
notifications in the list that are not peeking. A row joins the count
when it leaves the peek, which is what the morph back into the bell
shows; while rows peek the bell is not drawn at all. Opening a centre
panel moves every live row into the count at once, since the list then
shows them. Do not disturb shows the crossed bell, and the three clicks
stay (open the list, middle click clears all, right click toggles do
not disturb). The workspace pill alert is unchanged
and now comes from the daemon itself instead of a history file.

**List.** The Settings list keeps its rows as approved in r3 (app icon,
app name, summary, one line of body, 62 px), newest first, a click-x per
row and "Clear all". A click on a row expands it
in place: the full body (at most four lines, scrolling inside the list
beyond that), the image when there is one (at most 64 px, right of the
text), every action as a pill, and the inline reply field with a Send
button when the sender asked for one (`hasInlineReply`); Enter sends.
A second click, or expanding another row, collapses it. Actions and the
reply field exist only while the sender's notification is still alive;
rows restored from history after a bar restart show neither and say
nothing about it. Dismiss closes a live notification with reason
"dismissed by user" and drops a historic one from the file; "Clear all"
does that for every row. Resident notifications stay in the list after
an action until dismissed.

**History.** `$XDG_STATE_HOME/dotfiles-bar/notifications.json`, the
file that already holds dismissals and seen marks, becomes the history:
every non-transient notification with its id, app, summary, body, icon
and image paths, urgency, timestamp and seen flag; at most 200 entries
and nothing older than 7 days, pruned on write. DMS's history is not
imported. The file is written at most once per second, so a burst of
notifications is one write.

**Do not disturb.** A flag in the same state file, so it survives a bar
restart and a re-login. While on: nothing peeks except critical
notifications, the count still grows, the bell shows `notifications_off`.
Toggles: the Settings tile, the bell's right click, and a bar IPC
function (`quickshell ipc -c bar call notifications toggleDnd`) for a
Niri bind, replacing `dms ipc call notifications toggleDoNotDisturb`.
There is no schedule and no per-app rule.

Left out on purpose: sounds (ADR-0028), per-app rules, a notification
center of its own (the Settings list is it), swipe to dismiss, and
grouping by app in the list. Parked for a later change, not dropped:
pinning (controls animating in left of the dismiss glyph on hover; a
pinned notification keeps its blob below the island, smaller once the
stack is gone, and hover-opens) and snoozing (re-peek after 30 minutes).

Prototyped as r5 · notifications on 2026-10-08 (controls: Notify, Burst,
`replaces_id` update, Lock, Empty island), reworked through r6 (stack
replaces the island, actions below), r7 (bare rows, fixed width, text
actions, separator control) and r8 (dismiss glyph, subtle divider, disc
blobs). Approved as prototyped (r8 · notifications) on 2026-10-10 with
the full divider; the prototype's "Fixed width", "Disc blobs" and
"Separator" controls stay for comparison.


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
| Settings slider | full-width capsule 32 px tall, 8 px gap, icon zone 32 px, value zone 44 px; with a panel a 40 px chevron zone at the right end, the value zone left of its hairline |
| Shadow on expanded islands | 0 8 px 24 px `shadow` at 35 % |
| Notification peek | replaces the right island: 360 px wide (8 px clear of the centre island), radius 20 px, padding 10 px horizontal and 8 px vertical, at most three bare rows of 48 px with 12 px between them and a full-width 1 px `outline` hairline at 12 % in each gap; app icon on a 26 px disc, 10 px to the text, 28 px reserved at the right for the 16 px dismiss glyph (24 px hit area, 8 px from the top and right); a hovered row with actions grows to 80 px with text actions (12 px, 500, `primary` for the default, `on_surface` for the rest, 24 px apart, 32 px hit zones) |
| Disc blobs | 30 px circles in the island background and shadow, 8 px below the island, 8 px apart, right-aligned with the newest on the right, at most six then "+N"; a clear-all blob with a 16 px `close` glyph appears on hover at the far left; one size token |
| Notification list row expanded | body at most four lines, image at most 64 px, actions as pills, reply field with Send |

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
| Segmented control accent slide | 200 ms | cubic-bezier(0.2, 0.8, 0.2, 1); the same slide as the workspace pill, its own token since 2026-10-10 |
| Meter and charge fills (performance, charge, level bars) | 560 ms | ease-out; four times the content cross-fade, so a reading glides instead of jumping |
| Indicator appears or disappears in the right island | 180 ms width + opacity | ease-out |
| Tray fans out or folds | 200 ms spacing | cubic-bezier(0.2, 0.8, 0.2, 1) |
| OSD in / out | 160 ms / 240 ms | ease-out / ease-in |
| Right island morphs into the notification stack and back | island grow 280 ms / shrink 220 ms, same curves, content cross-fade 140 ms; a fanned tray folds or a tray menu closes first; the bell with its count appears after the morph back with the indicator timing | hold 5 s normal, 3 s low, critical until dismissed; sender timeout clamped 2 to 15 s; pointer pauses that row's hold; a new row pushes the stack down with the grow timing, a leaving row collapses with the shrink timing; `replaces_id` updates in place with a 140 ms cross-fade; shown with 0 ms durations under reduce motion |
| Notification actions reveal | 200 ms, tray curve: the row grows from 48 to 80 px, the text actions slide up from under the body and fade in, rows beneath slide down; the dismiss glyph fades in over the cross-fade duration | on hover rest (250 ms) or long press (500 ms); fold after the leave grace |
| Row breaks out into a disc blob | shrink timing: the row collapses into its icon disc, the disc crosses the island's bottom edge growing from 26 to 30 px and settles 8 px below; existing blobs shift left with the same timing | on hold end or push-out while other rows remain; blobs slide up into the bell and shrink to 16 px while fading on the morph back |
| Orb rim light and bloom | continuous while playing; rotation speed and rim brightness follow the level, bloom follows the low band, 30 fps (cava's own frame rate; 60 fps cost about a third of a core more for no new audio data, measured 2026-10-07) |
| Music motion on battery | 15 fps for the orb, the rims and the wave while on battery; 30 fps on the charger. Every frame the bar presents makes niri recompose the screen (measured 2026-10-07: about 0.2 % GPU per frame per second), so the frame rate is the battery lever (decided 2026-10-07) |
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
