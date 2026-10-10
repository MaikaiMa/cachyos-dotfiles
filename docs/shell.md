# Own Quickshell bar

The bar is moving from DMS to a repository-owned Quickshell configuration
([ADR-0027](adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)).
DMS stays the service layer: lock screen, polkit, theming and wallpaper;
in the Niri session the bar is also the notification daemon
([ADR-0028](adr/ADR-0028-own-the-notification-daemon-in-the-bar-for-the-niri-session.md)). This page is the index for the own bar; [dms.md](dms.md)
keeps describing DMS.

## DMS panels while the own bar runs

Switching to the own bar disables the DMS bar window, and the DMS
dashboard, control center, power menu and wallpaper browser are anchored to
that window: they do not open while the own bar is active. Since step 7 no
shortcut calls them any more; the own bar has a panel for each. The DMS
settings window is a separate window and opens from the `open_in_new`
button of the Wi-Fi, Bluetooth, Sound and Display panels. `scripts/bar-switch.sh dms` goes back to
the DMS bar; ADR-0027 records this as an amendment.

## What is built

All steps of the build (0 to 7, see "Phases"): the own bar covers
everything the DMS bar and its panels did. Every screen gets one tall,
transparent layer-shell window with three islands: workspaces and apps on
the left, the centre island, and the tray and attention indicators on the
right. The centre island runs the real state machine and morphs: hover
rests open Detail, a click opens the Home panel, the right island opens the
Settings and Updates panels, shortcuts open every panel (see "Shortcuts"),
Escape and a click outside close.

Step 2 made the centre pill real: a weather icon from `Weather`, the clock
and a battery icon from `Battery` (red when low), separated by hairlines.
In Detail the hairlines fade out and each column gets one label, the
temperature, the Dutch short date ("Zo 04-10") and the battery percentage,
while the clock stays on the centre line.

Step 3 made Settings real: a toggle grid (Wi-Fi, Bluetooth, power profile,
do not disturb, caffeine), capsule sliders for volume, microphone and
brightness that drag, click, scroll and take arrow keys, and the
notification list with dismiss and "Clear all". The Wi-Fi and Bluetooth
tiles open their own panels (see below). The island grows to the panel's own height,
so it shrinks in one island animation when notifications leave.

Since ADR-0028 the list is the bar's own daemon's: newest first, a click
on a row expands it in place (one row at a time, with the island's grow
and shrink timing) to the full body in at most four lines, the image at
most 64 px right of the text when it is not already the icon, every
action as a pill (the default action first, tinted `primary`, labelled
"Open" when the sender gives it no text) and, when the sender asks for it
(`hasInlineReply`), a reply field with Send; Enter sends. Actions and the
reply exist only while the sender's notification is alive, so rows
restored from the history after a bar restart show neither. An action or
a reply closes the notification with reason "dismissed by user" and its
row leaves, unless the sender marked it resident. The x closes a live
notification the same way and drops a historic one; "Clear all" does that
for every row. The header count is the list length. The do not disturb
tile is the bar's own flag (`Notifications.doNotDisturb`). The collapsed
row keeps its 62 px three-line look (app, summary, body), as the design
contract records since 2026-10-08.

Step 4 made Home real, 560 px wide and 436 px tall: a narrow and a wide
column on the 12 px tile grid. Time (hours over minutes, "zo 04 okt") and
Weather (current conditions, "Feels like", an Hourly / Daily segmented
control that cross-fades five forecast cards) on top; Performance (CPU
load, CPU temperature on a 30 to 95 °C scale, memory as thin vertical bars)
and Power (percentage, state, a read-only charge capsule that turns red
at 20 % or below, time remaining or to full, health, capacity, and the power
profile as a segmented control) below. Under them an actions row of 40 px
icon-only tiles spread over the full width: Settings (`tune`), Updates
(`download`, the updates indicator's glyph), Theme (`palette`), Wallpaper
(`wallpaper`), Power (`power_settings_new`), and Player (`music_note`)
while a player exists; a tap morphs Home into that panel. `System` samples
only while Home is open: `Shell` binds `System.active` to the `home` state.
Tab moves between the two segmented controls and then the action tiles,
Left and Right change the focused control, Enter or Space opens a tile. With
Home the own bar covers the DMS dashboard as well as the control center;
music, calendar and the user block are left out on purpose, they get their
own panels.

Step 5 made the side islands and the Updates panel real.

- **Left island.** One dot per workspace of the island's own screen:
  `shell.qml` passes the screen name and the island filters
  `Niri.workspaces` by `output`, because `Niri.focusedOutput` names only
  the one focused output. Dots are 8 px in 3 px padded slots; the active
  one is 22 px and a separate `primary` pill slides over the row to it in
  200 ms. A dot turns `error` when a window on that workspace is urgent or
  belongs to an app with a notification younger than ten minutes
  (`Notifications.hasRecentFor(appId)`, the name matching of the DMS
  plugins' `NotificationMatcher`); the active pill turns `error` then.
  The colour clears when the notification is dismissed from the list, at
  once, or 3 s (`Motion.alertClearDelay`) after its workspace gains focus,
  through the workspace or one of its windows; leaving within those 6 s
  clears nothing, and a new notification for the focused workspace gets
  its own 3 s (the DMS apps plugin's focus clearing, which waited 1.5 s). A
  `chevron_right` separator and 16 px icons (`Niri.iconFor`) follow for the
  windows of the active workspace: the active window at full opacity with
  a 4 px `primary` dot 2 px under it that slides to the next icon on a
  focus change (200 ms), the others at 0.5. Two icon rows take turns, so a
  switch cross-fades them. Click focuses the workspace or window; a click
  on the focused workspace's pill does nothing, because Niri's
  `workspace-auto-back-and-forth` (`input.kdl`) turns focusing the focused
  workspace into a jump to the previous one. A 500 ms long press toggles
  the overview, the wheel steps through the workspaces with the
  accumulator of DMS's switcher. The island animates its width in the
  workspace slide timing.
- **Right island.** Tray group, hairline, then caffeine, muted, Wi-Fi,
  updates and notifications, each a 24 px pill hit area
  that appears and disappears with a 180 ms width and opacity change; the
  outer pills sit 3 px inside the island edge. The hairline is only drawn
  when both the tray and an indicator are there. The tray folds to the
  first two icons on overlapping 24 px discs with a chevron; hover, a tap
  on the chevron or a tap on the folded stack fans it out to the left at a
  28 px pitch with the rightmost disc fixed, and leaving or a tap elsewhere
  on the island folds it. A click on a fanned disc activates the item; a
  right click grows the island down into the item's DBus menu, hanging
  from the island's left padding, submenus flattened one level under a
  header. The menu is as wide as its widest entry on one line, 160 to
  280 px, measured when it opens and when its entries arrive, not when an
  entry's text changes. Rows are at least 32 px and otherwise their text
  plus 8 px: multi-line entries (Hylki puts its status text in its menu)
  wrap to at most three lines and elide after that; disabled entries are
  at half opacity. While that menu is open the window takes the keyboard and the
  full mask like a panel, so Escape or a press anywhere on that screen
  closes it, and so does opening a centre panel. The island's size change
  uses the token of what caused it: indicator, tray fan, or the island
  grow and shrink for the menu (`Island.morphDuration`, `morphCurve`).
  Do not disturb has no indicator of its own: the bell shows
  `notifications_off` while it is on, with the count when there are
  unread notifications, and stays visible with none. Clicks: the bell
  opens Settings with its list scrolled to the top (middle click clears
  all, right click toggles do not disturb), updates toggles the Updates
  panel, Wi-Fi (shown when off or weak) opens Settings, muted unmutes and
  its wheel changes the volume, caffeine turns itself off; a click on the
  background opens Settings. The do not disturb tile stays in Settings.
  The bell counts the list items that are neither peeking nor a disc
  blob (`bellCount`), so a notification joins the count when the stack
  morphs back into the bell.
- **Notification peek** (ADR-0028, `NotificationPeekRow`,
  `NotificationBlobs`). A notification replaces the right island of the
  screen that had Niri's focus: a fanned tray folds first (200 ms) or an
  open tray menu closes first (220 ms), then the island morphs into the
  stack keeping its right edge (280 ms grow, the status content fades out
  in 140 ms) and nothing else is drawn in it: no tray, no indicators, no
  bell. On an empty day the island appears as the stack. The stack is
  360 px wide, capped 8 px clear of the centre island (`peekMaxWidth`
  from `shell.qml`, truncating the text), radius 20 px, padding 10 px
  horizontal and 8 px vertical. Rows are bare, 48 px, 12 px apart, with a
  full-width 1 px `outline` hairline at 12 % centred in each gap and none
  under the last row; up to three, newest on top, each new one growing
  the island down by a row while the others slide down. A row is the
  app's icon on a 26 px disc (the Settings row's icon choice), 10 px, the
  summary (13 px, `error` when critical) over one line of body (11 px),
  both elided 28 px before the right edge. Each row holds on its own: 5 s,
  3 s for low urgency, a positive sender timeout clamped to 2 to 15 s, a
  critical one until it is clicked or dismissed. The pointer on a row
  pauses its hold; leaving restarts it after the 120 ms grace. Resting
  250 ms on a row fades in a 16 px `close` glyph 8 px from its top and
  right (24 px hit area, `on_surface` on hover), and on a row with sender
  actions grows it to 80 px (200 ms, tray curve) while up to three text
  actions rise from under the body: 12 px, 500, 24 px apart in 32 px hit
  zones, the default action first in `primary`, the others in
  `on_surface`. A 500 ms long press on touch does the same, and a tap on
  the row folds it again. A `replaces_id` update cross-fades the row in
  place (140 ms) and restarts its hold. Clicks: the text runs the default
  action, or without one focuses the app's window (the workspace pill's
  app key matching) and marks it seen; a text action runs its action;
  both close the notification with reason "dismissed by user" unless it
  is resident. The glyph and a middle click on a row dismiss that row,
  right click opens Settings. A row whose hold ends, or that a fourth row pushes out, while
  other rows stay breaks out as a disc blob (`Notifications.blobIds`): its
  icon disc travels down through the island's bottom edge, grows from 26
  to 30 px and settles 8 px below the island (220 ms, shrink curve), a
  circle in the island background and shadow, right-aligned with the
  island, newest on the right, 8 px apart, at most six and then a "+N"
  blob on the far left. Blobs follow the island's bottom edge, shift left
  with the shrink timing and never climb back into the stack on their
  own. A click on a blob re-peeks it (`Notifications.repeek`): it rises
  into the island onto the top row's disc while that row grows in place
  (280 ms grow), with its actions, dismiss glyph and a fresh hold; with
  three rows already shown the bottom one breaks out as a blob. A click
  on "+N" opens Settings at the list. A clear-all blob sits at the far
  left of the blob row as long as the stack shows (a hover-only reveal
  was dropped on 2026-10-10: too easy to lose on the trackpad), left of
  "+N" or alone when there are no blobs: the blob size, a 16 px `close`
  glyph in `on_surface_variant`, `on_surface` on hover. Its
  click, and a middle click on a blob or on the stack outside its rows,
  dismisses every row and blob (`Notifications.clearStack`) and the
  island morphs back with nothing of them counted. A row that is
  dismissed, runs an action, or is the last one leaves without a blob. When the last row
  leaves, the island morphs back (220 ms shrink, the status content fades
  in), the blobs slide up into the bell's place shrinking to 16 px and
  fading, and only then the bell with its count fades in (180 ms); with
  nothing to show the island shrinks away. The blobs live in their own
  item beside the island (the island clips its content), and the bar
  window's input and blur regions have one ellipse per blob slot, "+N"
  and the clear-all blob included (`NotificationBlobs.area`), so blobs take clicks and get blur while the
  rest of the window stays click-through. No peek, only the count, while
  do not disturb is on (critical ones still peek), a centre panel is open
  (opening one moves every peeking row and blob into the count), or the
  focused window is fullscreen (`Niri.focusedFullscreen`). While the bar
  is hidden or the session is locked (`Session.locked`) arrivals wait and
  come back as one "N new notifications" row without actions, whose click
  opens Settings. Reduce motion makes every duration 0 and keeps the
  holds. `Theme.notificationPeek` turns the peek off.
- **Updates panel**, 420 px: "48 updates · checked 3 min ago", the fragile
  packages first in `error` with a reason (kernel, shell, greeter, else a
  reboot), then the rest with a source chip and `old → new` in a list that
  scrolls inside 280 px, then Update all, Refresh (its icon spins while
  checking) and Report (disabled until
  `~/.local/state/system-update/last-report.md` exists, opened with
  `xdg-open`). Update all closes the panel and runs `system-update` in a
  terminal: DMS's `terminalOverride` session key (Ghostty here, so the same
  terminal DMS's own updater used), else `xdg-terminal-exec`, else
  `ghostty -e`. Like DMS's updater the window waits for Enter at the end,
  so the summary stays readable, and the list is checked again once the
  terminal closes.

Step 6 added music: a 16 px orb in the album colour with a turning rim
light and a bloom on the beat sits 6 px left of the pill while an MPRIS
player exists; resting on it grows the island into the 280 px music bar
(the orb glides in as its first element, title and artist with a marquee,
previous / play / next, the rim light around the bar's edge), and a click
on the orb or the bar opens the 360 px Player panel (cover, title, artist,
album, a seekable progress track, controls, and output chips when there is
more than one output). Behind the islands a top-edge wave of light follows
cava's bands while music plays, on every screen; see "Music" below for how
it is driven and kept cheap.

Step 7 added the last panels, the OSD, the hide toggle and the tablet
pieces, and moved the shortcuts (built 2026-10-05).

- **Power panel**, 412 x 92 px: Lock, Suspend, Log out, Reboot and Power off
  as 72 px square buttons (`lock`, `bedtime`, `logout`, `restart_alt`,
  `power_settings_new`). Lock has the keyboard when the panel opens, Left and
  Right move it, Enter or Space activate; the button with the keyboard is
  drawn in `primary`, hover tints the others. The panel closes first and
  `Session` runs the action once the island has shrunk (220 ms).
- **Theme panel**, 560 px: Light / Dark / Auto, then the ten schemes DMS 1.6
  accepts (`scheme-tonal-spot`, `-vibrant`, `-content`, `-expressive`,
  `-fidelity`, `-fruit-salad`, `-monochrome`, `-neutral`, `-rainbow`, and
  DMS's own `-smart`) as 148 px cards in a strip. Light and Dark call
  `dms ipc call theme light|dark`, which switches DMS at once, turns smart
  mode off and writes the GNOME colour scheme (`default` or `prefer-dark`)
  for every other application. DMS applies the mode through two 100 ms QML
  timers that only advance while DMS paints a frame, and an idle DMS without
  its bar paints none, so a switch waited until something made it draw: a
  panel opening, a toast, the mouse (journal 2026-10-10, 3 to 23 s). Right
  after the call the bar shows a blank DMS toast (`toast info " "`, hidden
  after `Theme.themeNudgeDuration`, 400 ms), behind the frozen screen, the
  same nudge `dms-settings` uses; DMS then renders within about 0.2 s. The
  bar then sets the GTK theme name, `adw-gtk3` or `adw-gtk3-dark` (package
  `adw-gtk-theme`), and the explicit scheme, `prefer-light` or
  `prefer-dark`, after DMS's own write: GTK 3 applications and Electron ones such
  as the Claude app take light or dark from the theme name, not from the
  colour scheme (checked 2026-10-10: at `prefer-light` the Claude app stayed
  dark until the name changed), and Chromium reads `default` as no
  preference. DMS changes the name only when its own GTK theming is applied,
  which it is not here.
  Until 2026-10-10 the bar set that colour scheme itself through `gsettings`
  and let DMS follow the desktop portal, because the IPC runs DMS's own Niri
  screen transition. The journal showed why that was unstable: DMS 1.6.2
  polls the portal about every 10 s instead of listening, so a switch landed
  0 to 10 s later, and a second click inside that window was applied as the
  earlier value and written back to the colour scheme, reverting every
  application. On the click the bar
  itself already glides to the other mode's colours from the loaded
  `dms-colors.json` (`Colors.preview`), and the next reload of that file
  wins. A second click on the mode already pending is ignored, and every
  queued call is logged with `console.info` ("Theming: theme call: ...") in
  the bar's journal. Auto is DMS's `matugenSmartMode` (matugen picks light or dark from
  the wallpaper), the mode `dms/look.json` records: it sets the key to true
  and re-renders by setting the current wallpaper again. The calls run one
  after another, each after the previous one has exited; the control slides
  to the choice at once and follows DMS again once it has settled (2.5 s
  after the last call; then the mode comes from `dms-colors.json` and smart
  mode and the scheme are read once). Light and Dark get one
  screen-wide crossfade: 300 ms after the click (`Theme.themeCrossfadeLead`),
  once the control has slid and the bar has recoloured, the bar makes the
  theme call; DMS freezes the screen through Niri with a 0 ms delay, which
  would start fading before its render is done, so right after the call
  returns the bar runs `niri msg action do-screen-transition --delay-ms 1400`
  (`Theme.themeCrossfadeDelay`). Niri replaces a pending transition on the
  next request and renders the frozen frame into the new starting texture
  (`do_screen_transition` and `render` in niri's `src/niri.rs`), so the
  desktop stays frozen on the old desktop with the new bar until DMS and its
  templates are done, then cross-fades once. Under reduce motion, or with
  `Theme.themeCrossfade: false`, the bar adds no transition and DMS's own
  short fade shows. Scheme changes get none: DMS starts rendering about
  150 ms after `settings set`, before a transition 300 ms later could freeze
  the old state. While `themeBusy`, a 2 px `primary` line under the mode
  control fills left to right over the 2.5 s the busy state is expected to
  last, and the mode control and the scheme cards ignore clicks and keys
  (they look the same); the strip still scrolls. DMS has no settable key for
  its time- or location-based automatic mode (`themeModeAutoEnabled` is
  session state, which `settings set` cannot reach). Each card has six dots
  drawn from the live palette with the hue and saturation shifts of its
  scheme, not a matugen run per card; Smart shows the live palette itself.
  The strip opens on the applied scheme, which carries a dot; Left and Right
  move the selection ring, Enter or a click applies it.
- **Wallpaper panel**, 560 px: up to 200 images of the DMS wallpaper folder,
  sorted by name, as 120 x 68 px thumbnails with radius 10 and the file name
  under them. DMS has no setting for that folder: its picker remembers the
  last folder it browsed as `wallpaperLastPath` in
  `~/.cache/DankMaterialShell/cache.json`, which is `~/Pictures/Wallpapers`
  here (see [pictures.md](pictures.md)); the bar reads it and falls back to
  that folder. The list is read when the panel opens, with the picker's own
  filter (one level, symlinks followed). Thumbnails load asynchronously at
  twice their size and only for the cards in and near view. The current
  wallpaper (`dms ipc call wallpaper get`, `getFor` in DMS's per-monitor
  mode) carries a dot; Enter or a click applies through
  `dms ipc call wallpaper set` (`setFor` in per-monitor mode).
- **Crossfade delay, measured.** The pipeline after the theme call, read in
  DMS 1.6.2's shipped QML and the journal: the IPC handler freezes the
  screen and starts a 100 ms timer, `setLightMode` debounces another
  100 ms, then the `dms matugen queue` worker renders DMS's and the user's
  templates (0.5 s in the journal, of which matugen's quantisation of the
  3840 x 2400 wallpaper is 160 ms) and writes `dms-colors.json`; Ghostty
  and Niri pick their files up within about 0.2 s more. With the toast
  nudge the timers run about 0.2 s after the call, so the whole switch is
  about 1.0 to 1.2 s, and the default delay is 1400 ms. The portal path it
  replaced measured 1.1 to 5.1 s to DMS's pick-up alone on 2026-10-05 and
  up to 10.5 s on 2026-10-10. To re-measure, switch Light and Dark a few
  times, then let `scripts/theme-switch-timings.sh` pair the bar's calls
  with DMS's "Setting desired theme" and "Theme generation completed" lines
  from the journal of the last seven days (or a `journalctl --since` value)
  and suggest the delay that covers the median:

  ```fish
  ./scripts/theme-switch-timings.sh
  ```
- **Touch.** Every panel is reachable without a keyboard: a tap on the
  centre pill opens Home, whose actions row opens Settings, Updates, Theme,
  Wallpaper, Power and, while a player exists, Player; a 500 ms long press
  on the pill opens Power directly (the release does not also open Home);
  a tap on the right island opens Settings, on its updates indicator (while
  updates wait) Updates; a tap on the orb opens Player. A tap outside the islands closes.
- **Carousels.** Theme and Wallpaper share `components/Carousel.qml`: the
  wheel (either axis; a notch moves 120 px with a glide, touchpad pixels move
  it directly), a drag and a flick move only the strip; Left, Right, Home
  and End move the selection and the strip glides to centre it. The
  wallpaper strip adopts the thumbnail nearest the centre once a scroll
  comes to rest, as in the prototype; the scheme strip does not.
- **OSD.** The volume, microphone and brightness keys call the bar
  (`bar volume up|down|mute|micmute`, `bar brightness up|down`, 5 % steps).
  The bar changes the value through `Audio` or `Brightness` and shows a
  200 px pill over the collapsed pill for 1.5 s: `volume_up`, `volume_off`,
  `mic`, `mic_off` or `brightness_medium`, a 4 px fill track (40 % opacity
  while muted) and the value, "62%". It fades in over 160 ms and out over
  240 ms, closes any open panel first and never takes the keyboard. It
  shows on the screen with the keyboard focus. DMS's own volume, microphone
  and brightness OSDs are off while the own bar runs (`dms/look.json`, set
  by `scripts/bar-switch.sh`); DMS showed them on every change from any
  source, so both would have appeared.
- **Hide toggle.** `bar toggle hidden` slides all three islands
  `Theme.hideDistance` up (`islandTop + islandHeight + 15`, 50 px), until
  their bottom edge is 15 px above the screen (shrink curve; back with the grow curve), and sets the
  exclusive zone to 0, so windows take the bar's strip. The OSD still shows:
  the centre island comes down for it and goes back up. Opening a panel
  shows the bar again.
- **Tablet.** While the keyboard cover is detached, the right island shows a
  keyboard button (between Wi-Fi and updates) that toggles squeekboard; it
  shows `keyboard_hide` in `primary` while the keyboard is on screen. In
  Settings, Bluetooth shrinks to one cell and the rotation lock tile takes
  the other; the tiles move with the grow curve and Bluetooth's icon slides
  to the centre of its smaller tile. See [tablet.md](tablet.md).

On 2026-10-07 the Wi-Fi and Bluetooth tiles got panels of their own: a
chevron zone on the tile, a long press or a right click morphs Settings into a
420 px list of networks or devices with a back button, an on/off switch and a
button to the DMS settings window (Bluetooth adds `bluetoothctl` in a
terminal). Rows connect on a click and expand in place
for a password, Disconnect and Forget, or Pair; see "Wi-Fi and Bluetooth
panels" below.

Also on 2026-10-07 the privacy dots arrived: 6 px right of the centre island,
an orange dot while an app records the microphone, green while one uses the
camera and blue while the screen is shared or cast, 4 px apart in that order
and centred on the top row. They follow the island's right edge through
Detail, the music bar and every panel, fade over 140 ms, never pulse and take
no input; `Privacy` (see "Services") decides what counts, and the bar's own
visualiser capture does not. While the bar is hidden and a dot is active
they stay at the islands' top row and glide (grow timing, sideways only) to
the screen centre, centred on the clock's x, into a mini island: a pill of
the island surface, 16 px tall with 6 px padding on each side (18 x 16 px for
one dot, 38 x 16 px for three), with the islands' colour, opacity and blur.
The pill fades in with the glide; when the bar shows again it fades out with
the shrink timing while the dots glide back to the island's right edge. A
dot that comes or goes while docked resizes the pill around the clock's x.
While the OSD brings the centre island back the dots return to its edge.

Also on 2026-10-07 the three Settings capsules got panels of their own.

- **Slider chevrons.** Volume, Microphone and Brightness end in the Wi-Fi
  tile's 40 px chevron zone (`Theme.tileChevronZone`) behind a full-height
  hairline at 15 % (`tileChevronHairlineOpacity`), `chevron_right`; hovering
  the zone tints only the zone. The value runs from 0 to 100 over the capsule
  minus the zone, so the 44 px value zone sits left of the hairline and the
  fill at 100 % ends against it with a straight edge. `CapsuleSlider` decides
  on press: a press in the zone (or with the right button) never drags and
  opens the panel when released over the zone (the right button anywhere); a
  drag that started on the track and ends over the zone sets 100. Enter, the
  menu key or a right click on a focused capsule open the panel; Left and
  Right keep stepping by 5, Space is the icon zone's click (mute, or the
  brightness cycle). No long press, since on touch people hold before they
  drag. The hit area reaches 4 px into the gap above and below
  (`Theme.sliderHitExtension`), so the zone is a 40 x 40 touch target. Volume
  and Microphone open `sound`, Brightness opens `display`; both return to
  Settings with the back button, Backspace or Alt+Left, like Wi-Fi.
- **Sound panel**, 420 px. `PanelControlRow` without a switch (`hasSwitch:
  false`): back, the state ("Speakers · 44%", "muted" instead of the
  percentage while muted) and `open_in_new` to the DMS settings on `audio`,
  which closes the panel. Then up to three sections in one area that
  scrolls inside 360 px (`Theme.soundListMaxHeight`), each with a small
  header in the notification header's language and only while it has rows:
  *Output* and *Input* as 44 px `NetworkRow`s (glyph `speaker`,
  `headphones`, `bluetooth_audio` or `tv`; `mic` or `headset_mic`), the
  default tinted `primary`, a click makes a row the default through
  `Pipewire.preferredDefaultAudioSink/Source`. The default input carries a
  3 px level bar under its name (the peak on a -60 to 0 dB scale). *Apps*
  has one row per application: its themed icon (`application.icon-name`,
  else the process binary or the lower-cased name through
  `Quickshell.iconPath`, else `graphic_eq`), its name (ALSA clients'
  "PipeWire ALSA [blip]" reads "Blip") and a compact 176 x 24 px capsule
  whose icon zone mutes; the capsule moves every stream of the application
  together. Rows sort by name and keep their delegates, so nothing moves
  under a click or a drag. Tab walks back, settings, the rows and the app
  capsules; a row Tab reaches below the visible part scrolls into view.
- **Display panel**, 420 px. `PanelControlRow` with the night-light switch
  ("On · 4500 K" or "Off") and `open_in_new` to the DMS settings on
  `display_gamma`, where the schedule is changed. Then: the night
  temperature as a capsule over DMS's range (1000 to 6000 K in 500 K steps,
  capped at the day temperature; the value zone reads "4500 K", the fill
  dims to 40 % while night light is off, and the icon zone toggles it), a
  read-only schedule line ("No schedule · set one in settings", or the mode
  and the next change); the Brightness capsule as in Settings; Keyboard as
  Off / Low / Medium / High (`asus::kbd_backlight`, 0 to 3), only while the
  cover is attached; Rear light as Off / Low / Medium / High with a 10 px
  dot in the theme colour it follows, only when z13ctl's state file has a
  lightbar. The segmented controls sit on a `surfaceContainerHigh` track
  (`SegmentedControl.trackColor`). `sync-z13-window-color` keeps the chosen
  rear-light level on theme changes. Tab walks back, switch, settings, the
  two capsules and the two segmented controls.

- **Wi-Fi and Bluetooth panels.** The wide Wi-Fi and Bluetooth tiles end in a
  40 px chevron zone behind a full-height hairline; a click there, a long press, a right
  click, or Right or the menu key on a focused tile opens the panel, a click on
  the rest still toggles. The icon-only Bluetooth tile of the detached grid has
  no zone but keeps the long press and the right click. Both panels start with
  `PanelControlRow`: `arrow_back` (back to Settings, also Backspace or
  Alt+Left), a 36 x 20 px switch with the state next to it, and on the
  right `open_in_new`, which opens the DMS settings window on `network_wifi`
  or, for Bluetooth, `network` (DMS 1.6.2's settings have no Bluetooth page
  and its control center cannot open while the own bar runs). Bluetooth has
  a second button 8 px left of it, `terminal`, which opens `bluetoothctl` in
  the terminal Update all uses (DMS's `terminalOverride`, else
  `xdg-terminal-exec`, else Ghostty). Both close the panel; Tab goes back,
  switch, terminal, settings. Under it a `RowList` of 44 px
  `NetworkRow`s that scrolls inside 240 px; a row expands by 42 px (and an
  error by 16 px) with the grow or shrink curve, and the island follows
  because the panel's height is computed from the settled rows. One row is
  expanded at a time, and while one is the list keeps its order (rows hold
  their places, new ones join at the end), so a password field never moves
  or is rebuilt mid-typing. A row's error stays until the next attempt on it,
  also across closing the panel. Scanner, discovery, errors and attempts
  live in the `Network` and `Bluetooth` services and follow
  `Shell.centreState`, not a panel, so moving the panel to another screen or
  losing a screen cannot leave them running; `Shell` closes the centre state
  when its screen goes away. Tab walks the control row and the rows, Enter
  activates, Escape closes.
  - *Wi-Fi*: one row per SSID, the connected network first (tinted `primary`
    at 16 %, "Connected"), then saved ones, then the rest by signal bars and
    name; hidden networks are left out. The glyph is `signal_wifi_0_bar`,
    `network_wifi_1_bar` to `_3_bar` or `signal_wifi_4_bar`, with `lock` on
    the right when secured. A click connects to a saved or open network; an
    unknown WPA or WEP network expands into a password field (it takes the
    keyboard, Enter connects) and Connect; enterprise networks say "Needs a
    login: open settings". The connected row expands into Disconnect and
    Forget, a right click (or the menu key) on a saved one into Connect and
    Forget. A refused password shows "Wrong password" and opens the field
    again; a client failure (`WifiClientFailed`, `WifiClientDisconnected`)
    within 20 s of connecting to a saved network shows "Could not connect:
    wrong password?" with Forget inline, since NetworkManager often reports a
    stale saved password that way. The state reads "Off", "On · <SSID>", "On · not connected", or
    "Scanning…" for the first 4 s after the scanner starts. Quickshell lists
    networks that are neither connected nor saved only while its scanner is
    on, so the scanner runs while the panel is open and Wi-Fi is on (switching
    Wi-Fi on from the panel starts it) and stops otherwise; it scans at once
    and then rescans at most every 10 s.
  - *Bluetooth*: connected devices first (tinted, battery such as "82% ·
    Connected"), then paired, then discovered devices with a name; the icon
    follows BlueZ's device icon (`headphones`, `mouse`, `keyboard`,
    `smartphone`, `sports_esports`, else `bluetooth`). Discovery runs while
    the panel is open and the adapter is powered (BlueZ reports it ready, not
    just switched on): it starts when either becomes true, so switching the
    adapter on from the panel starts it, and stops on close, on power-off or
    after 30 s; the state reads "Scanning…" for its first 4 s. A click
    connects a paired device; on a connected one it expands into Disconnect
    and Forget, on a discovered one into Pair (then trust and connect). A
    right click on a paired device offers Connect and Forget. The bar has no
    pairing agent and the module does not say why a pair failed: a pair that
    ends without a bond shows "Pairing failed" (pair devices that want a PIN
    or passkey in `bluetoothctl`), a connect that settles disconnected "Could
    not connect"; both give up after 20 s (`Motion.pendingTimeout`). The
    state otherwise reads "Off", "On · N connected" or "On".

The `dms ipc` calls that remain are the ones DMS owns: `lock lock` (Lock
button, `Mod+Alt+L`), `settings openWith` (the settings button of the
Wi-Fi, Bluetooth, Sound and Display panels, through `dms-settings`),
`settings get|set` for `matugenScheme` and
`matugenSmartMode` (Theme panel), `wallpaper get|set|getFor|setFor`
(Wallpaper panel and the scheme re-render), `inhibit status|toggle` and
`night status|toggle|getDayTemp|getSchedule|setTargetTemp` (Display panel); plus the fallbacks of the media keys (see "Shortcuts") and
`dms screenshot` for the screenshot binds.

### Window architecture

- **One window per screen, as tall as the screen.** `shell.qml` creates a
  single `PanelWindow` anchored top, left and right and as tall as its
  screen, on the `Top` layer with namespace `dotfiles-bar`. Its exclusive
  zone is set explicitly to `Theme.barHeight` (36 px), so windows tile below
  the bar and not below the panels; 0 while the bar is hidden. The islands
  start `Theme.islandTop` (5 px) from the top, and every vertical position
  derives from it: the three islands, the orb (centred on the collapsed
  island, y + 15), Detail and the panels (they grow down from the same top),
  the input and blur regions and the hide distance. It is not anchored to the bottom edge:
  layer-shell ignores the exclusive zone of a surface anchored to all four
  edges, and Quickshell 0.3 cannot name the exclusive edge. When another
  surface reserves the top edge (the DMS bar while both run), the window
  starts below it and runs past the bottom of the screen by that much.
- **Three surfaces per screen.** Qt Quick renders and presents a whole
  surface on every frame, and Niri then recomposes everything under it: a
  30 Hz animation in the screen-tall window costs a full-output composite
  30 times a second (measured 2026-10-07: GPU busy 11 to 13 % against
  1.2 % for the DMS bar, see ADR-0027). So whatever animates continuously
  lives in a small surface of its own, and the tall window presents frames
  only when something in it changes (hover, Detail, panels, the hide
  slide, the OSD):

  | Surface | Namespace | Layer | Size and place | Input |
  |---|---|---|---|---|
  | Bar window | `dotfiles-bar` | Top | the screen's height, full width, exclusive zone 36 px | the islands (see below) |
  | Wave strip | `dotfiles-bar-wave` | Bottom | `Theme.waveHeight` (48 px), full width, exclusion ignored | none (`mask: Region {}`) |
  | Orb box | `dotfiles-bar-orb` | Top | about 81 x 36 px at the top edge, ending at the collapsed pill's left edge | the orb's 32 px ellipse |

  The wave strip is mapped only while the wave shows (playing or fading
  out, and `Settings.waveEnabled`), so it costs nothing otherwise. On the
  Bottom layer it lies under the windows and under the islands, whose blur
  still samples it; the bottom few pixels pass under the tops of tiled
  windows. The orb box is mapped while a player exists. It covers every
  place the orb takes outside a panel (collapsed, Detail, the OSD and 7 px
  inside the music bar; `CentreIsland.orbTravelLeft` and
  `orbTravelRight`, from the island's centre line), so the box never moves
  or resizes while music plays: Detail, the music bar glide and the OSD
  only change the orb's x inside it. It grows or shrinks by a pixel or two
  only when the clock's width changes at a minute, together with the pill.
  It ends at the collapsed pill's left edge and clips the bloom's faint
  outermost 2 px there, so a frame of the box damages nothing over the
  blurred island. The orb stays in this box in every
  state, including the music bar, where it lies over the island: the
  pointer never has to cross surfaces while it rests on the orb, so hover,
  the rest delay and the click work as before. Niri stacks the surfaces of
  one layer in the order they map, so the box maps only after the bar
  window has presented its first frame. When a panel opens the orb fades
  out at the box's left edge instead of travelling further out with the
  island. Both small surfaces ignore exclusive zones and so sit at the very
  top of the screen; while another surface reserves the top edge (the DMS
  bar during a switch) the orb sits that much above the island. Niri's
  `^dotfiles-bar` layer rule matches all three namespaces; only the bar
  window requests blur.
- **Input mask.** `mask` is a `Region` with one rounded child region per
  island, bound to the island's live `x`, `y`, `width`, `height` and
  `radius`. Each animation frame updates it, so the mask follows the island
  while it grows or shrinks; everything else in the window is click-through.
  The music orb's 32 px hit area is the input region of its own surface,
  not part of this mask. The privacy
  dots right of the centre island have no region: they take no input and
  get no blur, so clicks there reach the window below. The mini island the
  dots sit in while the bar is hidden is in the blur region (only while
  visible), never in the mask. While a panel
  is open on any screen, the mask of every bar window switches to a region
  covering the whole window. A separate region of the three islands is the
  blur region (`BackgroundEffect.blurRegion`) in both states, so Niri blurs
  only behind the islands; the orb floats unblurred in its own surface. Both regions
  are flat lists of direct children and share no `Region` object.
- **Keyboard focus.** `None` while no panel is open, `Exclusive` on the
  screen with an open panel. `OnDemand` is not enough: panels also open from
  shortcuts (`quickshell ipc` from the Niri binds) without a click, and Niri
  only gives an on-demand layer the keyboard after a click on it. Quickshell
  also has no signal for losing on-demand focus, so a panel could not close
  when focus moved away. Exclusive means no other window takes keys while a
  panel is open, which is what Escape-to-close needs. Every state change
  hands the focus back to the window's root item, so a panel opens with
  nothing focused and Escape reaches the root from any control; Tab then
  walks the panel's controls. Three panels then take the keys themselves:
  Power gives them to Lock, Theme and Wallpaper to their strip, so the
  arrow keys work at once. Keys they do not use, Escape among them, still
  reach the root.
- **Click outside.** At the bottom of the window's root item sits a
  `MouseArea` over the whole window, enabled while a panel is open; a press
  on it closes the panel. The islands are above it and keep their own input,
  and the centre island's panel guard stops presses on empty panel space
  from reaching it. Because the mask is full on every screen while a panel
  is open, a press outside the islands on any screen closes the panel. The
  close area lives in the same window as the islands, so it does not depend
  on where other exclusive zones push that window; a press on a surface
  above it, such as the DMS bar, does not close the panel.
- **State machine.** `services/Shell.qml` holds `centreState` (`collapsed`,
  `detail`, `home`, `settings`, `player`, `power`, `theme`, `wallpaper`,
  `updates`, `wifi`, `bluetooth`, `sound`, `display`, `musicbar`), the screen it applies to, `osdVisible`, `osdKind`
  (`volume`, `mic`, `brightness`) and `hidden`, with `open(state, screen)`,
  `close()`, `toggle(state, screen)`, `back()` (from `wifi`, `bluetooth`,
  `sound` or `display` to `settings`), `showOsd(screen, kind)` and `setHidden(value)`. One state at a time, so opening another panel morphs
  the island into it; the OSD closes any panel first, and opening a panel
  shows a hidden bar. On every open and morph into a panel, `Shell` records
  `Niri.focusedWindowId` and the focused workspace's id
  (`panelFocusWindow`, `panelFocusWorkspace`); the panel closes when Niri
  then reports a focused window (id 0 or higher) or a focused workspace other
  than the recorded one. A change to no window (-1) is ignored, because Niri
  may report that for the panel's own Exclusive keyboard grab; the pill
  states, Detail, the music bar and the OSD do not react. IPC target `bar`: `open`, `toggle` and `close` (the
  state `hidden` toggles the hide; `toggle wifi|bluetooth|sound|display` opens those panels), `osd`, `volume up|down|mute|micmute`,
  `brightness up|down`, `media next|prev|playpause|play|pause` and `state`.
  IPC calls act on the screen Niri reports as focused (`Niri.focusedOutput`),
  else the last used screen, else the first one.
- **Morphing.** `components/Island.qml` animates width, height, radius and
  the shadow with the Motion tokens (280 ms grow or morph, 220 ms shrink);
  panel bodies cross-fade in 140 ms. The centre island is centred on the
  window and its top is fixed, so it grows symmetrically and downward and the
  clock keeps its place in Detail.

## Layout

```text
chezmoi/dot_config/quickshell/bar/      -> ~/.config/quickshell/bar/
  shell.qml                             entry point: per screen the bar window (mask, close area), the wave strip and the orb box
  Colors.qml                            singleton: DMS palette, watched
  Theme.qml                             singleton: sizes, radii, fonts, panel widths
  Motion.qml                            singleton: durations, curves, reduce motion
  qmldir                                registers the token singletons
  README.md                             short directory guide
  services/                             singletons that own state or data
    Shell.qml                           centre island state machine and IPC target `bar`
    Niri.qml ... Updates.qml            data services, see "Services"
    Session.qml                         Power panel actions: lock, suspend, log out, reboot, power off; logind lock state
    Notifications.qml                   the notification daemon: history, do not disturb, peek stack
    Tablet.qml                          keyboard cover detached, on-screen keyboard, rotation lock
    Display.qml                         night temperature and schedule, keyboard backlight, rear light
    Wallpapers.qml                      DMS wallpaper folder, its images, the current wallpaper
    Privacy.qml                         microphone, camera and screen share in use, with app names
    Frames.qml                          frames presented per window, IPC target `bardebug`
  islands/                              the three islands
    LeftIsland.qml                      workspace dots of its screen, the active workspace's app icons
    CentreIsland.qml                    weather, clock and battery pill, Detail, orb, privacy dots, music bar, OSD and the eleven panels
    RightIsland.qml                     tray stack, fan and menu, attention indicators, or the notification stack in their place
    NotificationBlobs.qml               disc blobs of rows that left the stack, below the right island
  panels/                               centre panel bodies
    HomePanel.qml                       Time, Weather, Performance and Power tiles, actions row
    SettingsPanel.qml                   toggle grid, three sliders, notification list
    UpdatesPanel.qml                    pending packages, Update all, Refresh, Report
    PlayerPanel.qml                     cover, track, seekable progress, controls, output chips
    PowerPanel.qml                      Lock, Suspend, Log out, Reboot, Power off
    ThemePanel.qml                      Light / Dark / Auto and the scheme strip
    WallpaperPanel.qml                  thumbnail strip of the DMS wallpaper folder
    WifiPanel.qml                       Wi-Fi switch and networks: connect, password, disconnect, forget
    BluetoothPanel.qml                  Bluetooth switch and devices: connect, pair, disconnect, forget
    SoundPanel.qml                      outputs, inputs with the mic level, per-app volume
    DisplayPanel.qml                    night light, brightness, keyboard backlight, rear light
  components/                           shared pieces
    Island.qml                          island surface: colour, radius, shadow, size animation
    IslandAnimation.qml                 grow or shrink animation from the Motion tokens
    Hairline.qml                        1 x 14 px separator
    Clock.qml                           SystemClock text in a given format or formatter
    Icon.qml                            Material Symbols glyph by name, placeholder without the font
    WeatherIcon.qml                     Icon for a Weather service icon name
    BatteryIcon.qml                     Icon for the battery charge and state, red when low
    SegmentedControl.qml                pill of segments with a sliding accent, Left and Right keys, track colour
    TimeTile.qml                        Home: hours over minutes and the Dutch date
    WeatherTile.qml                     Home: current weather, Hourly / Daily, five cards
    PerformanceTile.qml                 Home: CPU, temperature and memory bars
    PowerTile.qml                       Home: charge, capsule, time, health, capacity, profile
    Tile.qml                            Settings grid toggle, wide with state or small icon-only, chevron zone for a panel
    CapsuleSlider.qml                   thumbless capsule slider with the clipped accent layer, optional chevron zone
    NotificationRow.qml                 one notification with dismiss, expands in place, collapses when it leaves
    NotificationPeekRow.qml             one bare row of the notification stack: hold, dismiss glyph, text actions, replace cross-fade
    NotificationActionPill.qml          one notification action as a 24 px pill in the Settings list
    PanelControlRow.qml                 panels from Settings: back, optional switch with state, DMS settings button
    RowList.qml                         Wi-Fi and Bluetooth: keyed list with its settled height
    NetworkRow.qml                      Wi-Fi, Bluetooth and Sound row: icon, name, detail or level, expands in place
    Orb.qml                             music orb: album-colour sphere, rim light, bloom
    PrivacyDots.qml                     microphone, camera and share dots right of the centre island
    RimLight.qml                        conic-gradient ring inside a rounded rectangle (orb, music bar)
    TopWave.qml                         top-edge wave canvas, in its own strip behind the islands
    FrameCounter.qml                    counts a window's presented frames into Frames
    Carousel.qml                        sideways strip for Theme and Wallpaper: wheel, drag, arrows
    Osd.qml                             OSD body: icon, fill track, value
chezmoi/dot_config/systemd/user/quickshell-bar.service
chezmoi/dot_local/bin/executable_bar-notifications   release/claim hooks and name owner (~/.local/bin/bar-notifications)
scripts/bar-switch.sh                   switches between the DMS and the own bar
tests/bar-switch.sh                     switch script test with stubs
tests/bar-notifications.sh              helper test with stubs
tests/quickshell-bar.sh                 qmldir check and qmllint over every bar QML file
```

Each directory with types has its own `qmldir`; types import each other by
relative directory (`import "../services"`, `import ".."` for the tokens).

`quickshell-bar.service` runs `quickshell -c bar -n`, is part of
`niri.service`, and starts before `dms.service` (see "Notification handover"
under "Switching bars"). It is not enabled through a
chezmoi-managed symlink: `scripts/bar-switch.sh` enables or disables it to
match `dms/look.json`.

The singleton is called `Colors`, not `Palette`, because `Palette` is a
QtQuick type and would shadow it.

## How colours arrive

DMS runs matugen on every wallpaper change and writes
`~/.cache/DankMaterialShell/dms-colors.json` with a `mode` (`dark` or
`light`) and a Material colour set per mode. `Colors.qml` reads that file
with a `FileView`, watches it for changes, and exposes the colours of the
active mode (`primary`, `primaryForeground`, `primaryContainer`, `secondary`,
`tertiary`, `surface`,
`surfaceContainer`, `surfaceContainerHigh`, `foreground`, `foregroundVariant`,
`outline`, `error`), `dark` (the shown palette, which `preview` moves) and
`mode` (the file's own mode, which `Theming.mode` follows). The colours are
assigned, not bound, so a new
palette glides in over `Motion.paletteDuration` (300 ms, 0 under reduce
motion) instead of cutting. Every colour falls back to a Material dark
default when the file or the key is missing, and a missing file is retried
every five seconds, so the bar renders on a fresh machine and picks up the
palette once DMS has written it. A read that does not parse (DMS caught
mid-write) only warns and keeps the loaded palette; the fallbacks apply
only while nothing has loaded yet.

The font is Inter Variable from the `inter-font` package, the same family
DMS uses.

## Switching bars

Since 2026-10-05 the own bar is the daily bar and DMS is the fallback; the
DMS bar's widget layout uses only built-in widgets (`launcherButton`,
`workspaceSwitcher`, `runningApps`), so `scripts/bar-switch.sh dms` works
without the retired plugins.

`dms/look.json` records which bar is active through `barConfigs[0].enabled`:
`false` hands the bar to Quickshell, `true` or absent keeps the DMS bar.
`scripts/bar-switch.sh` changes that flag together with DMS's volume,
microphone and brightness OSD switches (`osdVolumeEnabled`,
`osdMicMuteEnabled`, `osdBrightnessEnabled`: off for the own bar, which
draws its own OSD), applies them with `scripts/dms-apply-look.sh` (which
restarts DMS), and enables or disables `quickshell-bar.service`.

Use the own bar:

```fish
scripts/bar-switch.sh own
```

Go back to the DMS bar:

```fish
scripts/bar-switch.sh dms
```

Show which bar `dms/look.json` records and the state of the unit:

```fish
scripts/bar-switch.sh status
```

`--dry-run` previews any of these without writing `dms/look.json`, restarting
DMS, or enabling a unit. Without an argument the script only brings the unit
in line with what `dms/look.json` already records; `scripts/bootstrap.sh`
runs it that way after applying the DMS look, so a fresh machine comes up
with the recorded bar. The switch edits the tracked `dms/look.json`; commit
it when the choice should stick.

### Notification handover

The own bar is meant to own `org.freedesktop.Notifications`
([ADR-0028](adr/ADR-0028-own-the-notification-daemon-in-the-bar-for-the-niri-session.md)),
and DMS cannot give the name up. DMS is Quickshell too and registers the
name the moment it frees, so a bar that starts while DMS runs never gets it.
`quickshell-bar.service` therefore makes room itself on every start, for a
login, a manual restart and a crash restart alike, through
`~/.local/bin/bar-notifications`
([`chezmoi/dot_local/bin/executable_bar-notifications`](../chezmoi/dot_local/bin/executable_bar-notifications)):

- `ExecStartPre=-bar-notifications release` stops `dms.service` and leaves a
  marker in `$XDG_RUNTIME_DIR`. It does nothing while the session is locked
  (logind `LockedHint`; stopping DMS would take down the DMS lock) and when
  the bar has restarted more than twice (a restart loop leaves DMS alone).
- `ExecStartPost=-gdbus wait --session --timeout 30
  org.freedesktop.Notifications` waits for the name; the `-` keeps a bar
  that cannot register from failing.
- `ExecStartPost=-bar-notifications claim` starts `dms.service` again with
  `--no-block` when the marker exists (a blocking start would deadlock:
  DMS is ordered after the bar). DMS comes back after the bar holds the
  name, and the wallpaper and polkit agent blink for a second.

The drop-in `dms.service.d/notifications.conf` makes `dms.service`
`Type=simple`, so systemd no longer waits for DMS to hold the name. There is
no `PartOf=`: stopping the bar alone leaves DMS running and DMS registers
the name by itself. The drop-in stays installed in both modes.

`scripts/bar-switch.sh own` enables and restarts the bar; the hooks do the
rest. `scripts/bar-switch.sh dms` disables and stops the bar only; DMS keeps
running and takes the name within milliseconds. Each does nothing when the
state already matches (for `own`: the bar enabled and running, DMS running,
the bar holding the name). `scripts/bar-switch.sh status` adds a line with
the process that holds the name (`quickshell`, `dms`, `nobody`, or
`unknown` without `busctl` or a session bus), which is `bar-notifications
status`; it reads `busctl --user status`, and DMS's process is called `qs`,
so it recognises DMS by its command line.

A bar crash while the session is locked leaves DMS the name, by design. When
`status` names `dms` as the holder while the own bar runs, hand the name
back:

```fish
scripts/bar-switch.sh own
```

Check the crash path and the holder by hand:

```fish
systemctl --user kill -s KILL quickshell-bar.service
sleep 5
scripts/bar-switch.sh status
```

Recovery from any state is one command:

```fish
scripts/bar-switch.sh dms
```

## Shortcuts

The Niri binds in
[`cfg/keybinds.kdl`](../chezmoi/dot_config/niri/cfg/keybinds.kdl) call the
bar with `quickshell ipc -c bar call bar ...`:

| Keys | Call | Overlay title |
| --- | --- | --- |
| `Mod+Return` | `toggle home` | Home |
| `Mod+S` | `toggle settings` | Settings |
| `Mod+Shift+S` | `dms-settings --toggle` (the DMS settings window, through the helper that unsticks DMS's lazy loader; see [docs/dms.md](dms.md#known-limits)) | hidden |
| `Mod+Shift+Return` | `toggle wallpaper` | Wallpaper Selector |
| `Mod+Ctrl+Return` | `toggle theme` | Theme |
| `Mod+Escape` | `toggle power` | Session Menu |
| `Mod+Shift+B` | `toggle hidden` | Toggle Bar |
| `XF86AudioRaiseVolume`, `XF86AudioLowerVolume`, `XF86AudioMute`, `XF86AudioMicMute` | `volume up|down|mute|micmute` | hidden |
| `XF86MonBrightnessUp`, `XF86MonBrightnessDown` | `brightness up|down` | hidden |
| `XF86AudioNext`, `XF86AudioPrev`, `XF86AudioPlay`, `XF86AudioPause` | `media next|prev|playpause|pause` | hidden |

The media, volume and brightness keys keep working on the DMS fallback bar:
`quickshell ipc` exits with an error when the bar does not run (or does not
know the function yet), and the bind then runs the `dms ipc` call it used
before. They stay allowed while the screen is locked. `Mod+Alt+L` still
locks through DMS. The DMS settings window opens with `Mod+Shift+S` and from
the settings button of the Wi-Fi and Bluetooth panels.

The notification binds call the bar's IPC target `notifications`
(`quickshell ipc -c bar call notifications ...`):

| Keys | Call | Overlay title |
| --- | --- | --- |
| `Mod+N` | `openList` (toggles Settings at the list, the bell's click; also while the stack shows) | Notifications |
| `Mod+Shift+N` | `clearAll` (rows, blobs and the list, nothing counted) | Clear Notifications |
| `Mod+Ctrl+N` | `toggleDnd` | Do Not Disturb |

`toggleDnd` replaces `dms ipc call notifications toggleDoNotDisturb`; it and
`dnd` print the resulting state, `on` or `off`:

```fish
quickshell ipc -c bar call notifications openList
quickshell ipc -c bar call notifications clearAll
quickshell ipc -c bar call notifications toggleDnd
quickshell ipc -c bar call notifications dnd
```

## Running it by hand

For development, run the repository copy directly. Two instances draw two
bars, so stop the service first; `-n` makes Quickshell exit when an
instance of the same config already runs.

```fish
systemctl --user stop quickshell-bar.service
quickshell -p chezmoi/dot_config/quickshell/bar -n
```

After `chezmoi apply`, the deployed copy runs as `quickshell -c bar -n`, or by
path:

```fish
quickshell -p ~/.config/quickshell/bar -n
```

Quickshell reloads the QML when a file changes, so edits show up without a
restart. A change that adds new QML files is the exception: the reload can
keep the old type list and fail with "X is not a type" (seen 2026-10-07
when the Wi-Fi panel arrived), while the previous config keeps running.
Restart the unit after such an apply:

```fish
systemctl --user restart quickshell-bar.service
```

To test the window architecture spike, check on each screen:

- While no panel is open, clicks and scrolling outside the three islands
  reach the windows and the desktop below, anywhere on the screen: the bar
  window covers it all but takes input only on the islands.
- Windows tile 36 px below the top edge, not below the tallest panel.
- With the DMS bar running alongside, every click inside an open panel
  works across its whole height, including the bottom edge, and the
  pointer cursor shows over its controls there.
- The pill shows the current weather and battery icons as glyphs, not as
  dim squares, and the battery icon matches the charge and turns red at
  20 % or below.
- Resting the pointer on the centre pill for a moment opens Detail with the
  temperature, the date and the percentage under the icons; the clock does
  not move. Leaving closes it.
- A click on the pill opens Home, a click on the right island morphs it into
  Settings. Escape closes the panel, and so does a click anywhere outside
  the islands, on any screen.
- While a panel is open, typing does not reach the focused window; after it
  closes, the window has the keyboard again.
- Panels opened without a click take Escape too:

```fish
quickshell ipc -p ~/.config/quickshell/bar call bar toggle home
quickshell ipc -p ~/.config/quickshell/bar call bar osd
```

- The islands are blurred and the area around them is not.
- Settings: each tile toggles its setting and turns accent when on; the
  power profile tile cycles through the profiles. Dragging a slider (also
  by touch) follows the finger, a click on the track jumps there with a
  glide, a click on the icon mutes (volume, microphone) or steps the
  brightness. A wheel notch over a slider moves it 5, a touchpad scroll
  moves it 5 per notch's worth of travel, with the same glide as a key.
  Tab walks the tiles and sliders, arrow keys (5 per press), Home and End
  move a focused slider, and Escape still closes. Dismissing a notification
  collapses its row and the island shrinks; "Clear all" removes the section.
- Notifications, with the bar holding the name (`busctl --user status
  org.freedesktop.Notifications` names `quickshell`): `notify-send Test
  body` replaces the right island on the focused screen: the tray, the
  indicators and the bell are gone while it shows, the island is exactly
  360 px wide and keeps its right edge, and after the hold it morphs back
  and the bell appears with its count. Resting on the row fades in the
  `close` glyph at its top right; a click on it dismisses the row.
  `notify-send -A yes=Yes -A no=No Test body`: resting on the row grows
  it and shows "Yes" (in the accent) and "No" as plain text under the
  body, no pills; a click prints its key in the terminal and the row
  leaves the list. Three in a row (`notify-send One; notify-send Two;
  notify-send Three`) show three rows with a hairline between them that
  is barely visible, none under the last. A fourth pushes the bottom row
  out as a disc blob below the island; as the holds end the next rows
  become blobs, right-aligned and newest on the right, and the last row
  morphs back while the blobs slide into the bell. Re-peek: send four
  (`for n in 1 2 3 4; notify-send "Row $n"; end`), then click the blob:
  it rises back into the island as the top row with its own hold, and
  the bottom row breaks out as a blob in its place. Clear-all: with a
  blob under the stack, rest the pointer on the island for a moment; a
  blob with a `close` glyph fades in at the far left of the blob row (and
  alone, without other blobs, on a single row) and fades out shortly
  after leaving; its click removes every row and blob, the island morphs
  back and the bell does not count them. A middle click on a blob, or on
  the island's padding between rows, does the same at once; a middle
  click on a row still dismisses only that row. Keys: `Mod+N` opens
  Settings at the list (also while the stack shows, which then joins the
  count) and closes it again; `Mod+Shift+N` empties the stack, the blobs
  and the list; `Mod+Ctrl+N` toggles do not disturb and the bell crosses
  out. The overlay (`Mod+Shift+/`) lists Notifications, Clear
  Notifications and Do Not Disturb. `notify-send -p Progress` prints an id;
  `notify-send -r <id> Progress 50%` cross-fades that row in place.
  `notify-send -u critical Critical` stays until clicked and draws its
  summary in `error`. With do not disturb on (right click on the bell, or
  the IPC call under "Shortcuts") nothing peeks except critical, and the
  state survives `systemctl --user restart quickshell-bar.service`. That
  restart blinks DMS once (the bar's start hooks stop and start it) and
  afterwards `scripts/bar-switch.sh status` still names `quickshell`. A
  crash restart does the same: `systemctl --user kill -s KILL
  quickshell-bar.service`, then `scripts/bar-switch.sh status` must say
  `quickshell` within a few seconds. `scripts/bar-switch.sh dms` no longer
  restarts DMS; DMS's popups come back at once. After a bar crash while
  the session is locked, `status` names `dms` until `scripts/bar-switch.sh
  own`.
  Locking with `Mod+Alt+L`, sending one and unlocking shows "1 new
  notification". A notification DMS sends itself (an update or Bluetooth
  prompt) shows here and its action reaches DMS.
- Wi-Fi and Bluetooth tiles: hovering the chevron zone tints only the zone,
  hovering the rest only the rest; a click on the zone, a right click or a
  500 ms long press morphs Settings into the panel, a click on the rest
  toggles. Detached, the small Bluetooth tile opens its panel by long press
  or right click.
- Wi-Fi panel: the list fills in within a few seconds and "Scanning…" goes
  back to the state; the back arrow, Backspace and Alt+Left return to
  Settings; `open_in_new` opens the DMS settings on the Wi-Fi tab. Connect
  to a saved network, then to an unknown secured one: the field takes the
  keyboard, a wrong password shows "Wrong password" and opens the field
  again, the right one connects. Disconnect and Forget on the connected row;
  a right click on a saved network offers Connect and Forget. Move the
  panel to the other screen (open it there) and close it: the list stops
  refreshing.
- Bluetooth panel: nearby devices appear while it is open; `bluetoothctl
  show` reports `Discovering: no` after closing it. Connect and disconnect a
  paired device, pair a device that needs no PIN (it connects afterwards),
  and try one that needs a PIN: the row says "Pairing failed". The
  `terminal` button opens `bluetoothctl` in a terminal, `open_in_new` the DMS
  settings on the Network tab; both close the panel.
  Switching the adapter on from the panel starts discovery ("Scanning…").
- Power (`Mod+Escape`): Lock is in the accent when the panel opens, Left and
  Right move the accent, hover tints the other buttons. Each action runs
  only after the panel has closed; test Lock first, the others end the
  session.
- Theme (`Mod+Ctrl+Return`): the control shows Auto while DMS's smart mode
  is on; the strip opens centred on the applied scheme with its dot. A
  click or Enter on another scheme re-renders the palette within a few
  seconds and the bar follows; the dot moves. Light or Dark switches the
  mode and turns smart mode off (DMS's behaviour); Auto turns it back on.
  Light or Dark: the bar recolours, then the screen freezes on the old
  desktop with the new bar and one crossfade reveals the finished desktop,
  no half-rendered intermediate (when one shows, see "Crossfade delay").
  While DMS works the control and the cards sit at half opacity and
  ignore clicks; nothing animates, because the screen is frozen anyway.
  The wheel, a touchpad swipe and a drag scroll the strip without changing
  the selection.
- Wallpaper (`Mod+Shift+Return`): the strip opens centred on the current
  wallpaper, the thumbnails are the pictures with rounded corners, a click
  or Enter applies one, and the dot follows. After a scroll comes to rest,
  the thumbnail nearest the centre is selected.
- OSD: the volume, microphone and brightness keys show the slim pill over
  the clock for 1.5 s, on the screen with the keyboard focus, and close an
  open panel; DMS's own OSD no longer appears for these keys once
  `scripts/dms-apply-look.sh` has applied `dms/look.json`. The media keys
  control the player the orb shows.
- `Mod+Shift+B` slides the islands away and windows grow into the strip;
  pressing it again brings them back. A volume key while hidden shows the
  OSD and the centre island goes away again.
- Privacy dots: in a Meet call in Zen, an orange dot appears 6 px right of
  the pill when the microphone is on and a green one next to it when the
  camera is on (allow both in Zen); muting in Meet keeps the orange dot,
  leaving the call removes both within about 4 s. Sharing a tab or the
  screen from Zen adds a blue dot about half a second after the share
  starts. A recording with `wf-recorder` (if installed) shows the blue dot
  too. Open Detail, the music bar and a panel while a dot shows: the dots
  move with the island's right edge and never disappear; a click on a dot
  reaches the window below. While music plays and nothing records, no dot
  shows.
- Slider chevrons: hovering the chevron zone of a Settings capsule tints
  only the zone; a click there, a tap by touch (also just above or below the
  capsule) or a right click anywhere on it opens Sound or Display, and a
  press that starts in the zone never moves the value. Dragging Volume to
  the far right ends at 100 % against the hairline. Tab to a capsule: Enter
  or the menu key opens its panel, Left and Right still step by 5. Backspace
  or Alt+Left goes back to Settings.
- Sound panel: the output reads "Speakers" (plug headphones in: within a
  moment "Headphones" with the headphones glyph while the panel stays
  open), the input "Internal Microphone" with a level bar that moves when
  you speak (the analog input on this Z13 read near full scale even in a
  quiet room on 2026-10-07; if the bar stays full, that is the device, not
  the bar). Blip is one row. Play something in Zen: it gets its own row;
  moving its capsule changes only that app, the icon zone mutes it. Connect
  a Bluetooth headset: it appears under Output and Input; a click makes it
  the default. While the panel is open no orange privacy dot appears.
  `open_in_new` opens the DMS audio settings.
- Display panel: the switch turns night light on and the state reads "On ·
  4500 K"; dragging the temperature capsule warms the screen live in 500 K
  steps; the schedule line matches DMS's settings, which `open_in_new` opens
  on the gamma tab. Brightness follows the Settings capsule. Keyboard Off to
  High changes the cover's backlight (check that `asus::kbd_backlight`
  really drives the detachable cover; detached, the row disappears). Rear
  light Off to High changes the lightbar; then change the wallpaper or theme:
  the colour follows and the chosen level stays.
- Hide the bar (`Mod+Shift+B`) during a Meet call: the islands slide away,
  the privacy dots glide to the screen centre into a small blurred pill;
  showing the bar dissolves the pill and the dots glide back. A click on
  the pill reaches the window below.
- With the cover detached: the keyboard button appears in the right island
  and toggles squeekboard; Settings shows the rotation lock tile and
  Bluetooth as an icon; re-attaching animates back.
- Home: the time and the date sit centred in their tile, the weather icon
  and the forecast icons are glyphs, Hourly is selected when the bar starts
  and Daily cross-fades the cards to weekday, high and low. The three bars
  move every 2 s while Home is open. The capsule matches the percentage,
  the profile control shows the active profile and a click (or Tab to it,
  then Left or Right) switches the profile. Escape still closes from a
  focused segmented control. Each tile of the actions row morphs Home into
  its panel; Player shows only while something plays. A long press on the
  pill opens Power, a short tap still opens Home; try both by touch.

Bring the service back with:

```fish
scripts/bar-switch.sh
```

How many frames each surface presented, per screen, over the last given
seconds (at most 59), for power debugging. Every window counts its frames
all the time into one-second buckets, so the answer comes at once:

```fish
quickshell ipc -c bar call bardebug frames 5
```

It prints a line such as `eDP-1 bar=0 orb=151 wave=151 (5 s)`: `bar` is
the tall window, `orb` the orb box, `wave` the wave strip. With music
playing and nothing open, expect `bar` near 0 and `orb` and `wave` at 151
per 5 s on the charger and 75 on battery (30 and 15 per second); anything
at the display's refresh rate means an animation is running in that
surface.

## Adding a widget

1. Create the file with an upper-case name in the directory it belongs to
   (`islands/`, `panels/`, `components/`, or `services/` for a singleton
   that owns data). Take colours from `Colors`, sizes and fonts from `Theme`
   and durations from `Motion`; never hard-code a colour.
2. Add `<Name> 1.0 <Name>.qml` (or `singleton <Name> 1.0 <Name>.qml`) to
   that directory's `qmldir`. A hand-written `qmldir` stops Quickshell from
   synthesising one, so a type that is not listed is not found.
3. Import it by relative directory where it is used.
   For an icon use `components/Icon.qml` with a Material Symbols ligature
   name (`name: "battery_5_bar"`, see fonts.google.com/icons). The glyphs
   come from the "Material Symbols Rounded" font of the
   `ttf-material-symbols-variable` package, the set DMS embeds; `fill` and
   `weight` drive the font's variable axes. The glyph uses
   `Text.NativeRendering`: the variable outlines overlap, and Qt's default
   distance-field renderer (and the curve renderer) draw filled glyphs with
   holes and fringes. Without the font, or with an
   empty name, the icon draws a dim rounded square of the same size and
   `Theme` logs one warning at start.
4. Run `tests/quickshell-bar.sh`; it fails when a type is missing from its
   `qmldir` and on any qmllint warning other than the known
   `PanelWindow is not creatable` one.
5. Where the widget opens something the own bar has no panel for yet, call
   the matching `dms ipc` function, as ADR-0027 describes.

## Data sources

Decided 2026-10-04 after a read-only survey of the machine (step 1 of the
plan). The bar never depends on DMS's internal daemon socket, which is an
undocumented API with the process id in its path; it uses native
Quickshell services where they exist and `dms ipc` only for actions DMS
owns.

| Data | Source | Notes |
| --- | --- | --- |
| Workspaces, windows, focus | Niri's own socket (`$NIRI_SOCKET`) through `Quickshell.Io.Socket`, event stream | No `niri msg` subprocess. App icons through `DesktopEntries` with an override map for web apps without a desktop file. |
| Battery, health, capacity, time to empty, power profile | `Quickshell.Services.UPower` | Health and capacity are exposed directly. |
| Volume, microphone, mute | `Quickshell.Services.Pipewire` | |
| Outputs, inputs, per-app volume, mic level | `Quickshell.Services.Pipewire` (`preferredDefaultAudioSink/Source`, `PwObjectTracker`, `PwNodePeakMonitor`), port names from `pactl -f json list sinks` and `sources` | Quickshell exposes no ports: the friendly name ("Speakers", "Headphones", "Internal Microphone") is the active port's description, read at start, when the set of sinks and sources changes (300 ms debounce; application streams do not count), when the Sound panel opens and, while it is open, on `pactl subscribe` sink, source or card events (a jack plug moves the port without a node change). Without pactl: Bluetooth by device name, HDMI as "HDMI / DisplayPort", the analog card as "Speakers" or "Microphone". `pactl` is `libpulse`, a dependency of `cava`. Playback streams are bound with `PwObjectTracker` only while the panel is open; the level monitor runs only then too, and its stream flags itself `stream.monitor`, so it is no microphone use for `Privacy`. |
| Brightness | `brightnessctl` | No ambient light sensor on the Z13, so the icon cycles 25, 50, 75, 100. |
| Night temperature and schedule | `dms ipc call night status`, `getDayTemp`, `getSchedule`, `setTargetTemp` | DMS 1.6.2 accepts 1000 to 6000 K, rounds to 500 K and refuses a value above the day temperature (read in its shipped `DisplayService.qml`); the schedule has no IPC setter, only the settings tab `display_gamma`. Read when the Display panel opens and after each write. |
| Keyboard backlight | `brightnessctl -d asus::kbd_backlight` | 0 to 3; read when the Display panel opens and after a write. |
| Rear window light | `~/.local/state/z13ctl/state.json` (watched), `z13ctl brightness off|low|medium|high --device lightbar` | `devices.lightbar.brightness` 0 to 3 (`enabled: false` reads as off) and `color`; `brightness` keeps the mode and colour, and `sync-z13-window-color` keeps the level. |
| Wi-Fi, Bluetooth | `Quickshell.Networking`, `Quickshell.Bluetooth` | Native modules in Quickshell 0.3. Networks that are neither connected nor saved are listed only while the module's scanner is on (rescans at most every 10 s), so the Wi-Fi panel runs it only while open. |
| Night light, do not disturb, caffeine, theme mode, scheme | `dms ipc call night|notifications|inhibit|theme|settings` | `settings set matugenScheme` only saves the key: DMS 1.6.2's IPC assigns the setting directly and skips the `regenSystemThemes` hook its own settings UI runs (read in the shipped QML, not tried). The bar re-renders by setting the current wallpaper again, as [dms.md](dms.md) describes; a light/dark switch would also render but turns smart mode off. |
| Wallpapers | `wallpaperLastPath` in `~/.cache/DankMaterialShell/cache.json`, `find` in that folder, `dms ipc call wallpaper` | DMS has no folder setting; its picker remembers the last folder. |
| Keyboard cover, on-screen keyboard, rotation lock | `~/.local/bin/tablet-mode watch`, `osk watch` (only while detached), `$XDG_STATE_HOME/dotfiles/rotation-lock` | The helpers from [tablet.md](tablet.md); the bar calls `osk toggle` and `auto-rotate lock toggle`. |
| Session actions | `systemctl suspend|reboot|poweroff`, `niri msg action quit --skip-confirmation`, `dms ipc call lock lock` | |
| Notification daemon handover | `dms.service.d/notifications.conf` drop-in (`Type=simple`), `quickshell-bar.service` (`Before=dms.service`, `gdbus wait`, the `bar-notifications release` and `claim` hooks), `~/.local/bin/bar-notifications`, `busctl --user status org.freedesktop.Notifications` | Decided in [ADR-0028](adr/ADR-0028-own-the-notification-daemon-in-the-bar-for-the-niri-session.md), see "Notification handover". The packaged `BusName=` stays: systemd 262 rejects an empty `BusName=` and only `Type=dbus` waits for the name. |
| Notifications list | The bar is the daemon: `Quickshell.Services.Notifications` `NotificationServer` with actions, markup, images, inline reply and persistence announced; history, seen marks and do not disturb in `$XDG_STATE_HOME/dotfiles-bar/notifications.json`; do not disturb by `quickshell ipc -c bar call notifications toggleDnd` | Decided in [ADR-0028](adr/ADR-0028-own-the-notification-daemon-in-the-bar-for-the-niri-session.md). The file holds `doNotDisturb` and `notifications` (non-transient only: `id`, `serverId`, `appName`, `summary`, `body`, `appIcon`, `image` paths, `desktopEntry`, `urgency`, `timestamp`, `seen`), at most 200 entries and 7 days, pruned and written at most once per second. Raw image data is not kept. DMS's history is not imported. Quickshell's notification ids restart at 1 per process, so entries carry their own id. |
| Session locked | logind `LockedHint` of the user's display session (`/org/freedesktop/login1/user/self` `Display`), read with `busctl --system` and followed with `gdbus monitor --system` | DMS sets the hint through its `loginctl.setLockedHint` (in the shipped `dms` binary). Read-only, no polling; verified on 2026-10-08 (`b false`, monitor attached to `/org/freedesktop/login1/session/_33`). The change line format of `gdbus monitor` is read from glib's output format, not seen with a real lock. |
| Music, album colour | `Quickshell.Services.Mpris` plus Quickshell's `ColorQuantizer` | |
| Audio levels for orb and wave | `cava` raw ascii output on stdout, 24 bars, 30 fps, run only while something plays | |
| Tray | `Quickshell.Services.SystemTray` | |
| Weather | Open-Meteo, called by the bar, auto location through geoclue's `where-am-i` demo | DMS keeps weather in memory only. |
| Updates | `system-update --pending` from the repository helper | Never call `dms ipc call systemupdater updatestatus`: it starts a check instead of reporting one. |
| CPU, temperature, memory | `/proc/stat`, `/proc/meminfo`, the `k10temp` hwmon resolved by name | hwmon numbers change between boots. |
| Microphone in use | `Quickshell.Services.Pipewire`: capture streams with an active or paused link from an audio source node | Streams and links are bound with `PwObjectTracker`; unbound, `properties` is empty and every link reads `Unlinked`. Streams flagged `stream.monitor`, `stream.capture.sink` or `node.passive` (peak meters, pavucontrol, cava) and streams linked from a sink monitor do not count. |
| Camera in use | PipeWire video streams linked from a `v4l2_input.*` or `libcamera_input.*` node, plus `/dev/video*` holders | Zen, Chromium and Electron open the webcam directly by default, invisible to PipeWire. The webcam's USB `power/runtime_status` (resolved from `/sys/class/video4linux/video*/device`) is read every 2 s; only while it is not `suspended` does `find /proc/[0-9]*/fd -lname '/dev/video*'` run, every 4 s (about 20 ms), and `pipewire` and `wireplumber` holders are skipped. |
| Screen share or cast | Niri's event stream: `CastsChanged`, `CastStartedOrChanged`, `CastStopped` | A cast counts while `is_active`, after 500 ms without change. The app is the PipeWire consumer linked from the cast's `pw_node_id`, else `/proc/<pid>/comm` of the client Niri names, else "Screen". |

## Services

Every data source above is one `pragma Singleton` under `services/`, with
no UI; widgets import `"../services"` and bind to the properties. Quickshell
creates a singleton on first use, so a service that no widget references
does not run. Percentages are 0..100 and levels 0..1 unless noted.

- `Niri`: `workspaces` (sorted by output, then idx: `id`, `idx`, `name`,
  `output`, `isActive`, `isFocused`, `isUrgent`, `activeWindowId`),
  `windows` (`id`, `title`, `appId`, `workspaceId`, `isFocused`,
  `isFloating`, `isUrgent`, `column`, `row`), `focusedWindowId`,
  `focusedWorkspace`, `focusedOutput`, `overviewOpen`, `connected`,
  `focusedFullscreen` (the focused window is as large as its output's
  logical size: Niri 26.04 reports no fullscreen flag, and a fullscreen
  window is drawn over the bar; windows carry `width` and `height` from
  `layout.window_size`);
  `windowsOn(id)`, `focusWorkspace(id)`, `focusWindow(id)`,
  `toggleOverview()`, `request(message, callback)`, `iconFor(appId)` with
  `iconOverrides`, and `casts` (Niri's screencasts as it reports them:
  `stream_id`, `session_id`, `kind`, `target`, `is_dynamic_target`,
  `is_active`, `pid`, `pw_node_id`). One connection reads the event stream and reconnects
  with a backoff of 1 s doubling to 30 s; each request opens its own.
- `Battery`: `percentage`, `state` (`charging`, `discharging`, `full`,
  `unknown`), `onBattery`, `timeToEmpty`, `timeToFull` (seconds),
  `healthPercentage`, `energyCapacity` (Wh), `isLow` (20 or below), `available`;
  `profile`, `profiles` (`power-saver`, `balanced`, `performance`),
  `setProfile(name)`.
- `Audio`: `volume`, `muted`, `micVolume`, `micMuted`, `ready`, `sink`
  and `source` (the defaults), `sinks` and `sources` (hardware and virtual
  outputs and inputs, no streams, sorted by label), `ports` (node name to
  active port label and type, from pactl), `panelOpen` (`Shell.centreState`
  is `sound`), `playbackStreams`, `appStreams` (`key`, `name`, `icon`,
  `nodes`, grouped by `application.name`, else `media.name`, else node
  name; capture and monitor streams, the bar's cava among them, are never
  in it), `micLevel` (0..1, only while the panel is open);
  `setVolume(v)`, `toggleMute()`, `setMicVolume(v)`, `toggleMicMute()`,
  `sinkLabel(node)` (the friendly name, also for the Player's output chips),
  `deviceIcon(node)`, `setDefaultSink(node)`, `setDefaultSource(node)`
  (PipeWire's configured default), `appGroup(key)`, `groupVolume(group)`
  (the loudest member), `groupMuted(group)`, `setGroupVolume(group, v)`
  and `toggleGroupMute(group)` (every member), `readPorts()`.
- `Brightness`: `percentage` (-1 until read), `device`, `available`,
  `panelShown` (`Shell.centreState` is `settings` or `display`);
  `set(p)` (1 to 100), `cycle()` (25, 50, 75, 100), `refresh()`. Reads the
  backlight class at start, when the Settings or Display panel opens, every
  5 s while one of them is open, and after each write. While a write runs, only
  the newest `set` waits and follows it, so a slider drag never loses its
  last value. `set` moves `percentage` at once, so key repeats step from
  the new value and the OSD shows it.
- `Display`: `panelOpen` (`Shell.centreState` is `display`),
  `nightTemperature` (K, -1 until read), `nightMinimum`, `nightMaximum`,
  `nightStep`, `schedule` (DMS's text), `scheduleText`, `keyboardLevel` and
  `keyboardAvailable`, `rearLevel`, `rearColor` (RRGGBB) and
  `rearAvailable`; `nightFraction(kelvin)` and `nightKelvin(fraction)` (the
  capsule's 0..100), `setNightTemperature(kelvin)` (only the newest waits
  while a call runs), `setKeyboardLevel(level)`, `setRearLevel(level)`,
  `refresh()` (run when the panel opens). Night light on and off stay in
  `Dms`.
- `Network`: `wifiEnabled`, `connected` (any device), `wifiConnected`,
  `ssid`, `strength`, `weak` (under 40), `statusIcon` (the one Wi-Fi glyph
  for the Settings tile and the right island: `wifi_off`, the 0-bar glyph
  when disconnected, else `signalIcon` of the active network), `networks` (Quickshell
  `WifiNetwork`s, one per SSID, ordered for the panel), `scannerWanted`
  (`Shell.centreState` is `wifi`, Wi-Fi is on and a device exists; drives
  the module's `scannerEnabled`), `scanning` (its first 4 s), `errors` (per
  SSID), `wrongPassword`, `lastAttempt`; signal `failed(ssid, kind)`;
  `toggleWifi()`, `attemptConnect(network)`, `attemptPassword(network,
  password)`, `attemptForget(network)`, `reportFailure(network, reason)`
  (an `Instantiator` watches every network of the Wi-Fi device, hidden and
  duplicate SSIDs included), `setError(ssid, text)`,
  the raw `setScanning(value)`, `connectTo`, `connectWithPassword`,
  `disconnectFrom`, `forget`, and the row helpers `signalIcon`, `secured`,
  `needsPassword`, `detailText`, `failureText`.
- `Bluetooth`: `btEnabled`, `powered` (the adapter state is Enabled),
  `connectedDevices`, `available`, `discovering`,
  `devices` (connected, paired, then named discovered devices),
  `discoveryWanted` (`Shell.centreState` is `bluetooth` and the adapter is
  powered; drives discovery, capped at 30 s), `scanning` (its first 4 s),
  `errors` (per address), `pendingPairs`, `pendingConnects`;
  `toggleBluetooth()`, `startConnect(device)`, `startPair(device)` (then
  trust and connect), `setError(address, text)`, `deviceFor(address)`,
  `openTerminal()` (`bluetoothctl`), the raw `setDiscovering(value)`,
  `connectDevice`, `disconnectDevice`, `pair`, `trustAndConnect`, `forget`,
  and the row helpers `deviceIcon`, `batteryText`, `detailText`,
  `connectSettled`. Everything is native: the module has
  discovery, pairing and battery levels, but no pairing agent.
- `Dms`: `nightLight` and `caffeine`, polled every 10 s and after each
  call; `terminal` (DMS's `terminalOverride` from its `session.json`,
  watched); `toggleNightLight()`, `toggleCaffeine()`, `openSettingsTab(tab)`
  (a tab id from `dms ipc call settings tabs`; it runs
  `~/.local/bin/dms-settings`, which nudges DMS when its settings window
  does not map, see docs/dms.md Known limits), `refresh()`.
- `Theming`: the theme state DMS owns. `mode` (`dark` or `light`: bound to
  `Colors.mode` while not busy, the optimistic choice while busy; no poll),
  `smartMode` (`matugenSmartMode`, shown as Auto) and `scheme`
  (`matugenScheme`), read at start, when the Theme panel opens and after
  each action; `schemes` (value and label of every scheme DMS accepts);
  `gtkThemeLight`, `gtkThemeDark` (the theme names written on a switch);
  `setLight()`, `setDark()`, `setAuto()`, `setScheme(name)` (queued and run
  one step at a time; see the Theme panel above), `busy` (true while a
  queued action runs and for 2.5 s after the last call, while DMS renders;
  then `refresh()` runs once), `pendingMode`, the
  `reported` signal (a poll answered while nothing is pending; the panel
  then drops its optimistic choice) and `refresh()`. Light and Dark also
  start the Niri screen transition, see the Theme panel above. The colours
  themselves come through `Colors`.
- `Notifications`: the notification daemon (ADR-0028). `items` (newest
  first: `id`, `serverId`, `appName`, `summary`, `body`, `timestamp` in ms,
  `appIcon`, `image`, `urgency`, `desktopEntry`, `seen`, and `live`: the
  sender's notification still exists), `count` (the list length),
  `bellCount` (items neither peeking nor a blob), `alerts` (items from the last ten
  minutes not yet seen), `recentAppKeys` (name keys of their apps),
  `seenIds`, `focusedAlertIds` (alerts of the apps on
  `Niri.focusedWorkspace`), `liveIds`, `liveNotifications`,
  `doNotDisturb`; `peekIds` (the peek stack, newest first, at most three;
  `backlogRow` is the combined row), `blobIds` (rows that left the stack
  while others stayed, newest first, cleared when the stack ends),
  `peekScreen`, `backlogCount`,
  `peekDeferred` (bar hidden or session locked), `peekBlocked` (a panel
  open or a fullscreen focused window); signal `replaced(id)`.
  `dismiss(id)` (closes a live one with reason "dismissed by user", drops
  the entry), `markSeen(ids)`, `clearAll()` (every entry, row and blob:
  the list, the stack and the count empty), `clearStack()` (only the
  stack's rows and blobs; the combined row just ends and what it stands
  for stays listed), `repeek(id)` (a blob back as the top row with a fresh
  hold), `invoke(id, identifier)`,
  `reply(id, text)`, `activate(id, identifier)` and `open(id)` (the peek's
  verbs: they close unless resident), `isResident(id)`,
  `hasDefaultAction(id)`, `pillActions(notification)`, `holdFor(id)`,
  `expirePeek(id)` (a row's hold ended: a blob when other rows stay),
  `endPeek(id)` (a row leaves without a blob), `liveObject(id)`, `entryFor(id)`, `setDoNotDisturb(on)`,
  `toggleDoNotDisturb()`, `appKeys(name)`, `hasRecentFor(appId)`,
  `iconSource(appIcon, desktopEntry, image)`, `storedImage(image)`,
  `plainText(text)`, `oneLine(text)`. While `focusedAlertIds` is not empty
  and stays the same for `Motion.alertClearDelay`, they are marked seen. A
  sender's `replaces_id` arrives as changed properties on the same
  Quickshell object. A new summary or urgency rewrites the entry as new
  (new timestamp, unseen, back on top); a change of only the body, image
  or actions, as progress senders make every second, updates the entry in
  place and keeps its timestamp and seen mark. Either way `replaced`
  fires, but no new peek starts. A transient notification that does not
  peek on arrival (peeks off, do not disturb, bar hidden or locked, a
  panel open or a fullscreen window) is expired at once. The `now` clock
  that ages alerts out ticks every 30 s only while alerts exist. A notification the sender
  closes stays in the list as history; one that falls out of the 200
  entries or 7 days expires. After a config reload the server keeps its
  notifications (`keepOnReload`) and they find their entries again by
  server id and text. A missing or unreadable state file is an empty
  history.
- `Music`: `hasPlayer`, `title`, `artist`, `album`, `artUrl`, `playing`,
  `position`, `length` (seconds), `canSeek`, `artColors` (the quantiser's
  buckets), `artColorRaw` (the most frequent bucket colour,
  `Colors.primaryContainer` without art; it follows the art of every new
  track), `artColor` (`artColorRaw` lifted to at least 0.35 HSL lightness,
  hue and saturation kept, so a near-black cover still reads), `artLight` and `artWarm` (a lighter and a warmer cut of it for the
  rim light and the wave, lifted the same way); `lifted(color)`; `play()`, `pause()`, `togglePlaying()`, `next()`,
  `previous()`, `seek(seconds)` (absolute, when the player can seek),
  `raise()` (MPRIS Raise when the player can, else Niri focus on the window
  whose app id is the player's desktop entry or identity, case-insensitive;
  false when neither works). playerctld's mirror player is left out of
  `players`. `position` is asked from the player every second only while
  something plays and the Player panel is open.
- `Settings`: the bar's own runtime switches, kept in
  `$XDG_STATE_HOME/dotfiles-bar/settings.json` (defaults when the file is
  missing or unreadable): `waveEnabled`; `setWaveEnabled(enabled)`.
- `Cava`: `running` (cava runs only while a player plays, never under
  reduce motion), `bands` (24 raw levels), `smoothBands`, `level`, `low`
  (mean of the first four bands; all three smoothed with 80 ms attack and
  250 ms release), `rimAngle`, `barRimAngle` and `playerRimAngle` (degrees),
  `rimRate`, `barRimRate` and `playerRimRate` (turns per second), `spin` (0 paused to 1 playing, eased
  over 600 ms), `bloom`, `ringSwell` (0 to 1 and back on a 5 s
  cosine, the resting orb's ring breath), `ringBreath` (its opacity, 0.2 to
  0.8), `waveOn`, `waveOpacity`, `animating`; signal `tick(dt)`. Writes
  its config to `$XDG_RUNTIME_DIR/dotfiles-bar/cava.conf`.
- `Tray`: `items`, `count`; `activate(item)`, `menuFor(item)` (a handle for
  `QsMenuOpener`).
- `Weather`: `ready`, `failed` (the last fetch failed; the previous
  reading stays), `stale` (the reading is older than an hour), `updated`,
  `temperature`, `apparent`, `code`, `conditionText`,
  `iconName` (`clear-day`, `clear-night`, `partly-cloudy-day`,
  `partly-cloudy-night`, `cloudy`, `fog`, `drizzle`, `rain`, `snow`,
  `thunderstorm`), `hourly` (next 5 hours: `time`, `temperature`,
  `iconName`), `daily` (the 5 days after today: `date`, `max`, `min`,
  `iconName`); `refresh()`. Fetches every 15 minutes with XMLHttpRequest
  (aborted after 20 s) and looks up the location every hour. A failed
  fetch is retried after 60 s, doubling up to 15 minutes; a fetch also
  runs when a network connection returns while the reading is failed or
  stale, and after a resume (a jump in wall-clock time). An answer is read
  completely before anything is assigned, so a malformed one changes
  nothing. A stale reading shows "–" in the pill and Detail and is dimmed
  (`Theme.busyOpacity`) in the Home tile. The location comes
  from `where-am-i -t 10`, else the last fix in
  `$XDG_STATE_HOME/dotfiles-bar/weather-location.json`, else Nijmegen
  (51.84, 5.86) with a warning.
- `System`: `active` (bound by `Shell` to the `home` state), `cpu`, `temp` (°C, NaN
  without k10temp), `memory`, `memoryUsedGiB`, `memoryTotalGiB`. Samples
  every 2 s only while `active` is true.
- `Session`: `perform(action)` for `lock`, `suspend`, `logout`, `reboot`,
  `poweroff`: closes the panel, then runs the command once the island has
  shrunk. `locked`: logind's `LockedHint` on the user's display session,
  read once and then followed by one `gdbus monitor` process (restarted
  after 5 s when it exits). An exit resets `locked` to false, so a dead
  watcher cannot hold peeks back; three quick exits in a row are warned
  about once.
- `Tablet`: `detached` (from `tablet-mode watch`), `keyboardVisible` (from
  `osk watch`, which runs only while detached), `rotationLocked` (the state
  file, watched and read again when Settings opens); `toggleKeyboard()`
  (`osk toggle`), `toggleRotationLock()` (`auto-rotate lock toggle`),
  `refresh()`. Re-attaching the cover runs `osk hide`, as the retired DMS
  plugin did. A helper that exits is started again after 5 s.
- `Wallpapers`: `folder`, `files` (absolute paths, at most 200, sorted by
  name), `current`, `loading`; `refresh(screen)` (called when the Wallpaper
  panel opens; it reloads DMS's `cache.json` and lists the folder that
  answer names), `apply(path, screen)`, `fileName(path)`.
- `Privacy`: `micApps`, `cameraApps`, `shareApps` (deduplicated display
  names: `application.name`, else `media.name`, the node description or
  name; for direct camera holders the process name), `micActive`,
  `cameraActive`, `shareActive` (follows the active casts after 500 ms
  without change, so a short screencopy does not flash), `anyActive`;
  `cameraDevices` (the webcam USB devices), `deviceStatus`, `cameraAwake`,
  `cameraHolders` (`pid`, `comm`). Event-driven apart from the 2 s sysfs
  read and the holder scan while the webcam is awake. A muted app that keeps
  its stream open (a paused link) still counts. Holders owned by another user
  (root) are not readable and do not count.
- `Updates`: `items` (fragile first: `source`, `name`, `oldVersion`,
  `newVersion`, `fragile`, `reason`: the helper's one-line text for a
  fragile package, empty otherwise), `count`, `fragileCount`, `checking`, `ready`,
  `lastChecked`, `upgrading`, `reportPath`, `reportAvailable`; `refresh()`,
  `upgradeAll()` (the full helper in a terminal, see step 5 above),
  `openReport()`. Runs `~/.local/bin/system-update --pending` every 30
  minutes, on `refresh()` and after the update terminal closes.

### Music

One clock drives everything that moves with the music: a `Timer` in `Cava`
steps the smoothing, the three rim angles and turn rates (orb, music bar,
Player),
and the bloom, then emits `tick`. Every orb binds to `Cava.rimAngle`, every
music bar rim to `Cava.barRimAngle`, both to `Cava.level` and the orb to
`Cava.bloom`, and every screen's wave repaints on `tick`, so all screens
share one set of values. On pause the rims ease to a standstill over
600 ms and keep their angle; on play the turn rate eases back in over the
same 600 ms.

- **Orb.** A 16 px `Rectangle` in `Music.artColor`, a 2 px `RimLight` ring
  over it (a `Shape` with a `ConicalGradient` fill and an odd-even hole, in
  `artLight`, `primary`, `artWarm` and `artColor`), and a bloom behind it:
  the same gradient on a disc 8 px wider than the rim, faded out by a
  radial mask through `MultiEffect`. The ring and the bloom turn by
  rotating the item, so their layers are not redrawn per frame. The turn
  takes 6 s at rest down to 1.5 s at full level and stops on pause; the rim
  brightens and the bloom runs 0.15 to 0.5 with the low band while playing.
  Paused or stopped, the orb rests: core, rim and bloom scale together from
  16 to 6 px around the same centre while rim and bloom fade out, over the
  island shrink timing, and a 1 px ring of 12 px fades in and breathes with
  `Cava.ringSwell`: opacity 0.2 to 0.8 and a scale to 14 px, once every 5 s
  at about 15 frames per second. The earlier ring (16 px, opacity 0.25 to
  0.55 over 6 s at 10 per second) did animate, but read as a static blob
  on the live bar. The ring is `artColor` on the dark
  palette and `primary` on the light one, where a thin ring in a dark
  album colour would not read. Play reverses it over the
  grow timing. The 32 px hit area and the orb's place never change.
  No `qsb` is installed, so there is no custom shader; MultiEffect's blur
  spreads a 16 px disc by barely 3 px, which is why the bloom is a masked
  disc and not a blur.
- **Music bar.** The orb lives in its own small surface (Window
  architecture), not in the clipped island, and moves with the island's own
  curve between 6 px left of the pill and 7 px inside the bar. Resting on it for 80 ms opens `musicbar`;
  leaving both the orb and the island for 120 ms closes it. The bar is
  280 px as in the prototype: the run of title (12 px semibold) and artist
  (11 px) scrolls as a marquee with soft edges while it is wider than its
  space and the bar is open. A 2.5 px `RimLight` follows the island's
  radius, livelier than the orb's: one turn in 4 s at rest down to 1.2 s at
  full level, its lighter and warmer stops pushed 25 % toward white, and a
  soft outer glow of three 2 px rings 2, 4 and 6 px outside the edge at
  0.3, 0.16 and 0.06 alpha. The glow rings live in the window under the
  island, which clips its own children.
- **Now-playing peek.** `Music` emits `nowPlayingChanged` 500 ms after
  the playing track's identity (track id, title and artist, because
  Firefox reports one constant track id) settles on a new value, after a
  resume from a stop or a pause over 30 s, or when another player starts;
  `Shell.peek()` then opens `musicbar` on the focused screen for 5 s if
  the island is collapsed, and the pointer reaching the orb or the bar
  hands it over to the normal hover. `Theme.nowPlayingPeek: false` turns
  it off; reduce motion, a hidden bar, the OSD and any open state also
  skip it.
- **Player.** The island takes `PlayerPanel`'s height. A 1.5 px `RimLight`
  with the bar's gradient and no glow runs along the island's edge as a
  quiet continuation, on its own angle (`Cava.playerRimAngle`): one turn in
  8 s at rest down to 3 s at full level, fading with the panel body. The track seeks on
  press and drag (and Left and Right in 5 s steps) when the player can
  seek; the output chips show only with more than one output. Hover over the
  cover dims it with `surface` at 45 % and shows `open_in_new`; a click (or
  Enter or Space on the focused cover) calls `Music.raise()` and closes the
  panel when that worked.
- **Top-edge wave.** `TopWave` is a `Canvas` in the click-through wave
  strip on the Bottom layer, under the islands: a Catmull-Rom curve through the 24
  smoothed bands, four strokes from 58 px at 0.2 to 24 px at 0.8 alpha in
  a horizontal gradient of the orb colours, then faded toward the bottom
  with a `destination-in` gradient inside the canvas, because the window
  behind it is transparent. Together the strokes reach about 0.95 alpha on
  the curve, so the top row shows about 0.47 at the peak opacity.
  `Cava.waveOpacity` rises to 0.5 in 600 ms when
  playback starts and falls in 2 s after it stops. The canvas paints at half
  the item's size (`Theme.waveResolution`) and is scaled up with smooth
  filtering, with the strokes and the fade drawn through a scaled context so
  the shape matches; the softer edges disappear in the glow. Before the
  strokes, the band between 8 px above the screen edge and the curve is
  filled at the core stroke's alpha, so the top row stays covered when the
  curve swings down past the core stroke.
  `Theme.topWaveEnabled` switches it off in the code; at runtime
  `Settings.waveEnabled` switches it, kept across restarts, for example for
  a power A/B:

  ```fish
  quickshell ipc -c bar call bar wave toggle
  ```

  `wave on`, `wave off` and `wave toggle` print the new state. Off hides the
  wave at once and stops its repaints; the audio tick keeps running for the
  orb and the rims, and unmaps the wave strip. It draws on every screen for now, also the external
  monitors the design wants it off on by default.
- **CPU gating.** cava runs only while a player plays. The clock ticks at
  30 per second while playing or while the wave fades out on the charger
  (cava's own frame rate, so no audio frame is lost), at 15 per second
  (66 ms, `Motion.audioFrameIntervalBattery`) while playing on battery
  (`Battery.onBattery`, from UPower, switching live), at 15 per second while a
  paused player exists (only the resting ring breathes), and not at all
  without a player or under reduce motion. Smoothing and rotation step by
  the elapsed time, so attack, release and turn rates do not depend on the
  tick. The wave repaints only on a tick while its opacity is above zero. A
  `Timer` and not a `FrameAnimation`: the clock is capped whatever the
  display's refresh rate.
- **Why 15 per second on battery.** Every frame a surface presents makes
  Niri recompose the output, whatever the surface's size or blur mode.
  Measured live on 2026-10-07 on battery (per-process GPU time from the
  amdgpu fdinfo counters, 30 s): with music playing at 30 frames per
  second Niri used 7.5 % GPU, with the paused orb's 15 per second 2.7 %,
  and with no frames 0.6 % (the DMS bar with its visualiser also 0.6 %).
  About 0.2 % GPU per frame per second, so the frame rate is the lever.
  The rotation and smoothing step by elapsed time, so the rims turn at the
  same speed at 15 per second (harness: 151 and 153 degrees per second at
  30 and 15 ticks); the motion is only coarser. `bardebug frames 5` then
  reads 75 to 76 for `orb` and `wave`.
- **Why 30 Hz and half resolution.** On 2026-10-07 the own bar with music
  drew 14.7 W and 47.7 % CPU against 11.0 W for DMS. Profiling put almost
  all of it in the wave: QPainter rasterises its four wide strokes on the
  CPU across a 2560 x 84 device-pixel canvas, and it repainted at 62.5 Hz
  while cava delivers 30 frames. In an offscreen harness on the real GPU
  (2560 x 1600 at scale 1.75, simulated playback, 60 s, CPU from `/proc`)
  the bar with the wave went from 66.8 % of a core (60 Hz, full
  resolution) to 36.4 % at half resolution and 18.5 % with both changes.
  The orb and the rims cost under 5 points. The battery draw did not
  follow, because the screen-tall window was still presented on every
  tick; that is what the separate wave strip and orb box solve.
- **What may animate in the bar window.** Nothing continuously. The music
  bar's rim and glow and the Player's rim read `Cava` only while they show
  (`barLevel`, `playerLevel`, the angle bindings gated on visibility), and
  the Player's progress reads `Music.position` only while the panel is
  visible, the Updates refresh glyph spins and the Home charge fill
  animates only while their panel shows: a hidden item whose property
  changes still makes the window present a frame. In the offscreen harness
  (2560 x 1600 at scale 1.75, real GPU, simulated playback, 60 s,
  collapsed) the bar window went from 1886 frames to 7 to 9 (status
  changes, and the pill resizing when the clock's width changes), the orb
  box and the wave strip present 30 each per second, and opening Detail
  animates the bar window for 300 ms. The process's CPU stayed the same
  (23 % before, 22 to 23 % after; the wave's raster work did not change):
  the saving is GPU and compositor time. Check a new binding to `Cava`,
  `Music.position` or any other value that changes while music plays
  against this.

The services are linted with the rest of the bar:

```fish
tests/quickshell-bar.sh
```

## Phases

[ADR-0027](adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)
sets the direction; [shell-design.md](shell-design.md) is the approved
design contract and [design/bar-prototype.html](design/bar-prototype.html)
shows every state at real size. The build follows the contract as closely
as Quickshell allows and is ordered by risk: the things that could sink
the approach come first, the things that are only work come last.

| Step | What | Why first |
| --- | --- | --- |
| 0 | **Window architecture spike** (verified on the Z13 on 2026-10-04: click-through, morph, Escape, click outside and the IPC path all work under Niri with Exclusive focus while a panel is open). One tall layer-shell window per screen, 36 px exclusive zone, input mask following the islands, keyboard focus only while a panel is open, Niri blur rule for the `dotfiles-bar` namespace, one state machine for the centre island with placeholder islands that morph. | If Niri or Quickshell cannot do this, the whole "islands transform, no popups" design falls. |
| 1 | **Data-layer spike.** Niri event stream for workspaces and windows, where notifications come from while DMS owns the notification daemon, cava raw output for audio levels, album-art colour, which toggles go through `dms ipc`, weather source. | Each of these is a service the widgets sit on; an unknown here changes the design more than any widget. |
| 2 | Centre pill with Detail: clock, weather icon, battery (UPower). | First visible value, exercises the state machine. |
| 3 | Settings panel: toggles, three capsule sliders (Pipewire, brightness), notifications list. | With 2 and 3 the own bar covers the DMS control center. |
| 4 | Home panel (built 2026-10-04; the optional Network and Next event row is not). | With 4 the DMS dashboard is covered; the own bar becomes the daily bar and DMS drops to fallback. |
| 5 | Left island (Niri), right island (tray, indicators), Updates panel plus `system-update --pending` (built 2026-10-04). It takes over the function of the DMS plugins `dotfilesWorkspaces`, `dotfilesApps`, `dotfilesLauncher`, `dotfilesKeyboard` and `dotfilesDashboard`; the plugins were deleted on 2026-10-05, when the user switched to the own bar, and `chezmoi/.chezmoiremove` clears the live copies. | Replaces the remaining DMS bar plugins. |
| 6 | Music: orb, music bar, Player, top-edge wave (Mpris, cava) (built 2026-10-05). | Highest render cost, least risk to daily use. |
| 7 | Theme, Wallpaper, Power, OSD; hide toggle; shortcuts moved; keyboard button and rotation lock tile while detached (built 2026-10-05). | Mostly plumbing to `dms ipc`. |

Code layout from step 0 on, under `chezmoi/dot_config/quickshell/bar/`:
`services/` for singletons that own data (Niri, Audio, Battery, Weather,
Music, Tray, Updates, Dms, Theming), `islands/` for the three islands,
`panels/` for the centre panel states, `components/` for shared pieces,
and `Theme.qml`, `Colors.qml`, `Motion.qml` for the tokens. Every step
lands as its own change with docs and tests; the DMS bar plugins are
deleted in the step that replaces their function.
