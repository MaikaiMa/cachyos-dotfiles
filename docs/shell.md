# Own Quickshell bar

The bar is moving from DMS to a repository-owned Quickshell configuration
([ADR-0027](adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)).
DMS stays the service layer: notifications, lock screen, polkit, theming
and wallpaper. This page is the index for the own bar; [dms.md](dms.md)
keeps describing DMS.

## DMS panels while the own bar runs

Switching to the own bar disables the DMS bar window, and the DMS
dashboard, control center, power menu and wallpaper browser are anchored to
that window: they do not open while the own bar is active. Since step 7 no
shortcut calls them any more; the own bar has a panel for each. The DMS
settings window is a separate window and opens from the Wi-Fi and Bluetooth
tiles (right click or long press). `scripts/bar-switch.sh dms` goes back to
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
notification list with dismiss and "Clear all". A right click or a long
press on the Wi-Fi or Bluetooth tile opens the DMS settings window. The island grows to the panel's own height,
so it shrinks in one island animation when notifications leave.

Step 4 made Home real, 560 px wide and 436 px tall: a narrow and a wide
column on the 12 px tile grid. Time (hours over minutes, "zo 04 okt") and
Weather (current conditions, "Voelt als", an Hourly / Daily segmented
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
  DMS's own `-smart`) as 148 px cards in a strip. Light and Dark do not call
  `dms ipc call theme`: that IPC always switches with a Niri screen
  transition (the screen freezes, then cross-fades to a half-rendered
  state). With `matugenSmartMode` off and `syncModeWithPortal` on, DMS
  follows the GNOME colour scheme after a 750 ms settle and switches without
  a transition, so the bar sets smart mode to false (only when it is on;
  while on, DMS re-resolves the mode from the wallpaper) and then sets
  `gsettings ... color-scheme default|prefer-dark`. On the click the bar
  itself already glides to the other mode's colours from the loaded
  `dms-colors.json` (`Colors.preview`), and the next reload of that file
  wins. A second click on the mode already pending is ignored, and every
  queued call is logged with `console.info` ("Dms: theme call: ...") in the
  bar's journal. Auto is DMS's `matugenSmartMode` (matugen picks light or dark from
  the wallpaper), the mode `dms/look.json` records: it sets the key to true
  and re-renders by setting the current wallpaper again. The calls run one
  after another, each after the previous one has exited; the control slides
  to the choice at once and follows DMS again once it has settled (polls at
  300 ms, 1 s and 2.5 s after the last call). Light and Dark get one
  screen-wide crossfade that the bar orchestrates: 300 ms after the click
  (`Theme.themeCrossfadeLead`), once the control has slid and the bar has
  recoloured, it runs `niri msg action do-screen-transition --delay-ms
  2000` (`Theme.themeCrossfadeDelay`), so Niri shows the frozen old desktop
  with the new bar while DMS and its templates render, then cross-fades
  once to the result. `Theme.themeCrossfade: false` or reduce motion skips
  it. Scheme changes get none: DMS starts rendering about 150 ms after
  `settings set`, before a transition 300 ms later could freeze the old
  state. While `themeBusy`, a 2 px `primary` line under the mode control
  fills left to right over the 2.5 s the busy state is expected to last,
  and the mode control and the scheme cards ignore clicks and keys (they
  look the same); the strip still scrolls. DMS has no settable key for its time- or location-based automatic
  mode (`themeModeAutoEnabled` is session state, which `settings set` cannot
  reach). Each card has six dots drawn from the live palette with the hue
  and saturation shifts of its scheme, not a matugen run per card; Smart
  shows the live palette itself. The strip opens on the applied scheme,
  which carries a dot; Left and Right move the selection ring, Enter or a
  click applies it.
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
- **Crossfade delay, measured.** From the bar's and DMS's journals on
  2026-10-05 (`journalctl --user`, five Light/Dark switches through the
  portal alone): from the bar's `gsettings` call to DMS's "Setting desired
  theme" took 1.10, 1.71, 2.30, 4.84 and 5.14 s; from there to "Theme
  generation completed" 0.68 to 0.88 s, and the last template hook (Niri
  reloading its config, ghostty's reload comes earlier) another 0.1 to
  0.5 s, 0.89 to 1.18 s in all. The fastest switch was done 2.28 s after
  the `gsettings` call; minus the 300 ms lead that is 1.98 s, rounded up to
  2000 ms. DMS's pick-up of the portal change varies by seconds (its own
  timing, not the bar's), so a slow switch still reveals part of the
  render; raise the delay if that shows often (3000 ms covers the median
  of 3.29 s, at the cost of a longer frozen screen).
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

The `dms ipc` calls that remain are the ones DMS owns: `lock lock` (Lock
button, `Mod+Alt+L`), `settings openWith` (Wi-Fi and Bluetooth tiles),
`theme getMode` and `settings get|set` for `matugenScheme` and
`matugenSmartMode` (Theme panel), `wallpaper get|set|getFor|setFor`
(Wallpaper panel and the scheme re-render), `notifications
getDoNotDisturb|toggleDoNotDisturb|clearAll`, `inhibit status|toggle` and
`night status`; plus the fallbacks of the media keys (see "Shortcuts") and
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
- **Input mask.** `mask` is a `Region` with one rounded child region per
  island, bound to the island's live `x`, `y`, `width`, `height` and
  `radius`. Each animation frame updates it, so the mask follows the island
  while it grows or shrinks; everything else in the window is click-through.
  A fourth, elliptic region follows the music orb's 32 px hit area (the
  size of its bloom), which sits outside the centre island. While a panel
  is open on any screen, the mask of every bar window switches to a region
  covering the whole window. A separate region of the three islands is the
  blur region (`BackgroundEffect.blurRegion`) in both states, so Niri blurs
  only behind the islands and the orb floats on the wallpaper. Both regions
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
  `updates`, `musicbar`), the screen it applies to, `osdVisible`, `osdKind`
  (`volume`, `mic`, `brightness`) and `hidden`, with `open(state, screen)`,
  `close()`, `toggle(state, screen)`, `showOsd(screen, kind)` and
  `setHidden(value)`. One state at a time, so opening another panel morphs
  the island into it; the OSD closes any panel first, and opening a panel
  shows a hidden bar. IPC target `bar`: `open`, `toggle` and `close` (the
  state `hidden` toggles the hide), `osd`, `volume up|down|mute|micmute`,
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
  shell.qml                             entry point: per screen the bar window, its mask and close area
  Colors.qml                            singleton: DMS palette, watched
  Theme.qml                             singleton: sizes, radii, fonts, panel widths
  Motion.qml                            singleton: durations, curves, reduce motion
  qmldir                                registers the token singletons
  README.md                             short directory guide
  services/                             singletons that own state or data
    Shell.qml                           centre island state machine and IPC target `bar`
    Niri.qml ... Updates.qml            data services, see "Services"
    Session.qml                         Power panel actions: lock, suspend, log out, reboot, power off
    Tablet.qml                          keyboard cover detached, on-screen keyboard, rotation lock
    Wallpapers.qml                      DMS wallpaper folder, its images, the current wallpaper
  islands/                              the three islands
    LeftIsland.qml                      workspace dots of its screen, the active workspace's app icons
    CentreIsland.qml                    weather, clock and battery pill, Detail, orb, music bar, OSD and the seven panels
    RightIsland.qml                     tray stack, fan and menu, attention indicators
  panels/                               centre panel bodies
    HomePanel.qml                       Time, Weather, Performance and Power tiles, actions row
    SettingsPanel.qml                   toggle grid, three sliders, notification list
    UpdatesPanel.qml                    pending packages, Update all, Refresh, Report
    PlayerPanel.qml                     cover, track, seekable progress, controls, output chips
    PowerPanel.qml                      Lock, Suspend, Log out, Reboot, Power off
    ThemePanel.qml                      Light / Dark / Auto and the scheme strip
    WallpaperPanel.qml                  thumbnail strip of the DMS wallpaper folder
  components/                           shared pieces
    Island.qml                          island surface: colour, radius, shadow, size animation
    IslandAnimation.qml                 grow or shrink animation from the Motion tokens
    Hairline.qml                        1 x 14 px separator
    Clock.qml                           SystemClock text in a given format or formatter
    Icon.qml                            Material Symbols glyph by name, placeholder without the font
    WeatherIcon.qml                     Icon for a Weather service icon name
    BatteryIcon.qml                     Icon for the battery charge and state, red when low
    SegmentedControl.qml                pill of segments with a sliding accent, Left and Right keys
    TimeTile.qml                        Home: hours over minutes and the Dutch date
    WeatherTile.qml                     Home: current weather, Hourly / Daily, five cards
    PerformanceTile.qml                 Home: CPU, temperature and memory bars
    PowerTile.qml                       Home: charge, capsule, time, health, capacity, profile
    Tile.qml                            Settings grid toggle, wide with state or small icon-only
    CapsuleSlider.qml                   thumbless capsule slider with the clipped accent layer
    NotificationRow.qml                 one notification with dismiss, collapses when it leaves
    Orb.qml                             music orb: album-colour sphere, rim light, bloom
    RimLight.qml                        conic-gradient ring inside a rounded rectangle (orb, music bar)
    TopWave.qml                         top-edge wave canvas behind the islands
    Carousel.qml                        sideways strip for Theme and Wallpaper: wheel, drag, arrows
    Osd.qml                             OSD body: icon, fill track, value
chezmoi/dot_config/systemd/user/quickshell-bar.service
scripts/bar-switch.sh                   switches between the DMS and the own bar
tests/bar-switch.sh                     switch script test with stubs
tests/quickshell-bar.sh                 qmldir check and qmllint over every bar QML file
```

Each directory with types has its own `qmldir`; types import each other by
relative directory (`import "../services"`, `import ".."` for the tokens).

`quickshell-bar.service` runs `quickshell -c bar -n`, is part of
`niri.service`, and starts after `dms.service`. It is not enabled through a
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
`outline`, `error`) and `dark`. The colours are assigned, not bound, so a new
palette glides in over `Motion.paletteDuration` (300 ms, 0 under reduce
motion) instead of cutting. Every colour falls back to a Material dark
default when the file or the key is missing, and a missing file is retried
every five seconds, so the bar renders on a fresh machine and picks up the
palette once DMS has written it.

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

## Shortcuts

The Niri binds in
[`cfg/keybinds.kdl`](../chezmoi/dot_config/niri/cfg/keybinds.kdl) call the
bar with `quickshell ipc -c bar call bar ...`:

| Keys | Call | Overlay title |
| --- | --- | --- |
| `Mod+Return` | `toggle home` | Home |
| `Mod+S` | `toggle settings` | Settings |
| `Mod+Shift+S` | `dms ipc call settings focusOrToggle` (the DMS settings window) | hidden |
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
the Wi-Fi and Bluetooth tiles in Settings.

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
restart.

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
  move a focused slider, and Escape still closes. Right click or a 500 ms
  long press on Wi-Fi opens the DMS settings on the Wi-Fi tab and closes
  the panel; on Bluetooth it opens the Network tab, because DMS 1.6 has no
  Bluetooth settings tab. Dismissing a notification
  collapses its row and the island shrinks; "Clear all" removes the section.
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
| Brightness | `brightnessctl` | No ambient light sensor on the Z13, so the icon cycles 25, 50, 75, 100. |
| Wi-Fi, Bluetooth | `Quickshell.Networking`, `Quickshell.Bluetooth` | Native modules in Quickshell 0.3. |
| Night light, do not disturb, caffeine, theme mode, scheme | `dms ipc call night|notifications|inhibit|theme|settings` | `settings set matugenScheme` only saves the key: DMS 1.6.2's IPC assigns the setting directly and skips the `regenSystemThemes` hook its own settings UI runs (read in the shipped QML, not tried). The bar re-renders by setting the current wallpaper again, as [dms.md](dms.md) describes; a light/dark switch would also render but turns smart mode off. |
| Wallpapers | `wallpaperLastPath` in `~/.cache/DankMaterialShell/cache.json`, `find` in that folder, `dms ipc call wallpaper` | DMS has no folder setting; its picker remembers the last folder. |
| Keyboard cover, on-screen keyboard, rotation lock | `~/.local/bin/tablet-mode watch`, `osk watch` (only while detached), `$XDG_STATE_HOME/dotfiles/rotation-lock` | The helpers from [tablet.md](tablet.md); the bar calls `osk toggle` and `auto-rotate lock toggle`. |
| Session actions | `systemctl suspend|reboot|poweroff`, `niri msg action quit --skip-confirmation`, `dms ipc call lock lock` | |
| Notifications list | DMS history file `~/.cache/DankMaterialShell/notification_history.json`, watched | DMS owns the notification daemon and Quickshell cannot run a second one. DMS's IPC cannot remove history entries (`dismiss` closes the newest popup, `clearAll` clears active notifications), so the bar remembers what it dismissed in its own state file. Taking the daemon over needs an ADR and belongs with the lock-screen phase. |
| Music, album colour | `Quickshell.Services.Mpris` plus Quickshell's `ColorQuantizer` | |
| Audio levels for orb and wave | `cava` raw ascii output on stdout, 24 bars, 30 fps, run only while something plays | |
| Tray | `Quickshell.Services.SystemTray` | |
| Weather | Open-Meteo, called by the bar, auto location through geoclue's `where-am-i` demo | DMS keeps weather in memory only. |
| Updates | `system-update --pending` from the repository helper | Never call `dms ipc call systemupdater updatestatus`: it starts a check instead of reporting one. |
| CPU, temperature, memory | `/proc/stat`, `/proc/meminfo`, the `k10temp` hwmon resolved by name | hwmon numbers change between boots. |

## Services

Every data source above is one `pragma Singleton` under `services/`, with
no UI; widgets import `"../services"` and bind to the properties. Quickshell
creates a singleton on first use, so a service that no widget references
does not run. Percentages are 0..100 and levels 0..1 unless noted.

- `Niri`: `workspaces` (sorted by output, then idx: `id`, `idx`, `name`,
  `output`, `isActive`, `isFocused`, `isUrgent`, `activeWindowId`),
  `windows` (`id`, `title`, `appId`, `workspaceId`, `isFocused`,
  `isFloating`, `isUrgent`, `column`, `row`), `focusedWindowId`,
  `focusedWorkspace`, `focusedOutput`, `overviewOpen`, `connected`;
  `windowsOn(id)`, `focusWorkspace(id)`, `focusWindow(id)`,
  `toggleOverview()`, `request(message, callback)`, `iconFor(appId)` with
  `iconOverrides`. One connection reads the event stream and reconnects
  with a backoff of 1 s doubling to 30 s; each request opens its own.
- `Battery`: `percentage`, `state` (`charging`, `discharging`, `full`,
  `unknown`), `onBattery`, `timeToEmpty`, `timeToFull` (seconds),
  `healthPercentage`, `energyCapacity` (Wh), `isLow` (20 or below), `available`;
  `profile`, `profiles` (`power-saver`, `balanced`, `performance`),
  `setProfile(name)`.
- `Audio`: `volume`, `muted`, `micVolume`, `micMuted`, `ready`, `sink`
  (the default output), `sinks` (hardware and virtual outputs, no streams);
  `setVolume(v)`, `toggleMute()`, `setMicVolume(v)`, `toggleMicMute()`,
  `sinkLabel(node)`, `setDefaultSink(node)` (PipeWire's configured default).
- `Brightness`: `percentage` (-1 until read), `device`, `available`;
  `set(p)` (1 to 100), `cycle()` (25, 50, 75, 100), `refresh()`. Reads the
  backlight class every 5 s and after each write. While a write runs, only
  the newest `set` waits and follows it, so a slider drag never loses its
  last value. `set` moves `percentage` at once, so key repeats step from
  the new value and the OSD shows it.
- `Network`: `wifiEnabled`, `connected` (any device), `wifiConnected`,
  `ssid`, `strength`, `weak` (under 40); `toggleWifi()`.
- `Bluetooth`: `btEnabled`, `connectedDevices`, `available`;
  `toggleBluetooth()`.
- `Dms`: `nightLight`, `doNotDisturb`, `caffeine`, `themeMode`, polled every
  10 s and after each call; `smartMode` (`matugenSmartMode`, shown as Auto)
  and `matugenScheme`, read at start, when the Theme panel opens and after
  each call; `schemes` (value and label of every scheme DMS accepts);
  `terminal` (DMS's `terminalOverride` from its `session.json`, watched);
  `toggleNightLight()`, `toggleDoNotDisturb()`, `toggleCaffeine()`,
  `setLight()`, `setDark()`, `setAuto()`, `setScheme(name)` (queued and run
  one call at a time; see the Theme panel above), `themeBusy` (true while a
  queued theme call runs or its follow-up polls are pending; Light and Dark
  also start the Niri screen transition, see the Theme panel above),
  `openSettingsWindow()`, `openSettingsTab(tab)` (a tab id from
  `dms ipc call settings tabs`), `refresh()`, `refreshTheme()`.
- `Notifications`: `items` (newest first: `id`, `appName`, `summary`,
  `body`, `timestamp` in ms, `appIcon`, `image`, `urgency`,
  `desktopEntry`), `count`, `alerts` (items from the last ten minutes not
  yet seen), `recentAppKeys` (name keys of their apps), `seenIds`,
  `focusedAlertIds` (alerts of the apps on `Niri.focusedWorkspace`);
  `dismiss(id)`, `markSeen(ids)`, `clearAll()`, `appKeys(name)`,
  `hasRecentFor(appId)`. While `focusedAlertIds` is not empty and stays
  the same for `Motion.alertClearDelay`, they are marked seen. A missing or
  malformed history file is an empty list. Dismissals and seen marks live in
  `$XDG_STATE_HOME/dotfiles-bar/notifications.json`; `clearAll()` also
  clears DMS's active notifications through `dms ipc`.
- `Music`: `hasPlayer`, `title`, `artist`, `album`, `artUrl`, `playing`,
  `position`, `length` (seconds), `canSeek`, `artColors` (the quantiser's
  buckets), `artColorRaw` (the most frequent bucket colour,
  `Colors.primaryContainer` without art; it follows the art of every new
  track), `artColor` (`artColorRaw` lifted to at least 0.35 HSL lightness,
  hue and saturation kept, so a near-black cover still reads), `artLight` and `artWarm` (a lighter and a warmer cut of it for the
  rim light and the wave, lifted the same way); `lifted(color)`; `play()`, `pause()`, `togglePlaying()`, `next()`,
  `previous()`, `seek(seconds)` (absolute, when the player can seek).
  playerctld's mirror player is left out of `players`.
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
- `Weather`: `ready`, `temperature`, `apparent`, `code`, `conditionText`,
  `iconName` (`clear-day`, `clear-night`, `partly-cloudy-day`,
  `partly-cloudy-night`, `cloudy`, `fog`, `drizzle`, `rain`, `snow`,
  `thunderstorm`), `todayMax`, `todayMin`, `sunrise`, `sunset`, `hourly`
  (next 5 hours), `daily` (the 5 days after today), `place`,
  `locationSource`, `updated`; `refresh()`. Fetches every 15 minutes with
  XMLHttpRequest and looks up the location every hour. The location comes
  from `where-am-i -t 10`, else the last fix in
  `$XDG_STATE_HOME/dotfiles-bar/weather-location.json`, else Nijmegen
  (51.84, 5.86) with a warning. `place` stays empty: where-am-i names its
  source (GeoIP, Wi-Fi), not a place, and Open-Meteo has no reverse
  geocoding.
- `System`: `active` (bound by `Shell` to the `home` state), `cpu`, `temp` (°C, NaN
  without k10temp), `memory`, `memoryUsedGiB`, `memoryTotalGiB`. Samples
  every 2 s only while `active` is true.
- `Session`: `perform(action)` for `lock`, `suspend`, `logout`, `reboot`,
  `poweroff`: closes the panel, then runs the command once the island has
  shrunk.
- `Tablet`: `detached` (from `tablet-mode watch`), `keyboardVisible` (from
  `osk watch`, which runs only while detached), `rotationLocked` (the state
  file, watched and read again when Settings opens); `toggleKeyboard()`
  (`osk toggle`), `toggleRotationLock()` (`auto-rotate lock toggle`),
  `refresh()`. Re-attaching the cover runs `osk hide`, as the retired DMS
  plugin did. A helper that exits is started again after 5 s.
- `Wallpapers`: `folder`, `files` (absolute paths, at most 200, sorted by
  name), `current`, `loading`; `refresh(screen)` (called when the Wallpaper
  panel opens), `apply(path, screen)`, `fileName(path)`.
- `Updates`: `items` (fragile first: `source`, `name`, `oldVersion`,
  `newVersion`, `fragile`), `count`, `fragileCount`, `checking`, `ready`,
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
- **Music bar.** The orb lives in the bar window, not in the clipped
  island, and moves with the island's own curve between 6 px left of the
  pill and 7 px inside the bar. Resting on it for 80 ms opens `musicbar`;
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
  seek; the output chips show only with more than one output.
- **Top-edge wave.** `TopWave` is a `Canvas` under the islands, outside the
  input mask and the blur region: a Catmull-Rom curve through the 24
  smoothed bands, four strokes from 58 px at 0.2 to 24 px at 0.8 alpha in
  a horizontal gradient of the orb colours, then faded toward the bottom
  with a `destination-in` gradient inside the canvas, because the window
  behind it is transparent. Together the strokes reach about 0.95 alpha on
  the curve, so the top row shows about 0.47 at the peak opacity.
  `Cava.waveOpacity` rises to 0.5 in 600 ms when
  playback starts and falls in 2 s after it stops. `Theme.topWaveEnabled`
  switches it off everywhere; it draws on every screen for now, also the
  external monitors the design wants it off on by default.
- **CPU gating.** cava runs only while a player plays. The clock ticks at
  60 per second while playing or while the wave fades out, at about 15 per
  second (66 ms) while a paused player exists (only the resting ring breathes), and
  not at all without a player or under reduce motion. The wave repaints
  only on a tick while its opacity is above zero. A `Timer` and not a
  `FrameAnimation`: the clock is capped at 60 per second whatever the
  display's refresh rate.

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
Music, Tray, Updates, Dms), `islands/` for the three islands,
`panels/` for the centre panel states, `components/` for shared pieces,
and `Theme.qml`, `Colors.qml`, `Motion.qml` for the tokens. Every step
lands as its own change with docs and tests; the DMS bar plugins are
deleted in the step that replaces their function.
