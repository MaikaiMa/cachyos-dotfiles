# Own Quickshell bar

The bar is moving from DMS to a repository-owned Quickshell configuration
([ADR-0027](adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)).
DMS stays the service layer: notifications, OSD, control center, lock screen,
polkit, theming. This page is the index for the own bar; [dms.md](dms.md)
keeps describing DMS.

## Known limitation while DMS panels are still in use

Switching to the own bar disables the DMS bar window, and the DMS
dashboard, control center and settings panel are anchored to that window:
they do not open while the own bar is active, even though the shortcuts
still fire. Whether notifications, OSD, lock and the standalone settings
window are unaffected still has to be confirmed on the machine. DMS stays
the daily bar until the own bar is good enough: `scripts/bar-switch.sh own`
tries the bar, `scripts/bar-switch.sh dms` goes back to work. ADR-0027
records this as an amendment.

## What is built

Steps 0 to 2 of the build (see "Phases"). Every screen gets one tall,
transparent layer-shell window with three islands: a placeholder "bar" on
the left, the centre island, and a placeholder ring on the right. The centre
island runs the real state machine and morphs: hover rests open Detail, a
click opens a placeholder Home panel, the right island opens a placeholder
Settings panel, Escape and a click outside close.

Step 2 made the centre pill real: a weather icon from `Weather`, the clock
and a battery icon from `Battery` (red when low), separated by hairlines.
In Detail the hairlines fade out and each column gets one label, the
temperature, the Dutch short date ("Zo 04-10") and the battery percentage,
while the clock stays on the centre line.

### Window architecture

- **One tall window per screen.** `shell.qml` creates a `PanelWindow`
  anchored top, left and right, `Theme.windowHeight` (480 px, the largest
  panel) tall, on the `Top` layer with namespace `dotfiles-bar`. Its
  exclusive zone is set explicitly to `Theme.barHeight` (36 px), so windows
  tile below the bar and not below the panels.
- **Input mask.** `mask` is a `Region` with one rounded child region per
  island, bound to the island's live `x`, `y`, `width`, `height` and
  `radius`. Each animation frame updates it, so the mask follows the island
  while it grows or shrinks; everything else in the window is click-through.
  The same region is the blur region (`BackgroundEffect.blurRegion`), so
  Niri blurs only behind the islands.
- **Keyboard focus.** `None` while no panel is open, `Exclusive` on the
  screen with an open panel. `OnDemand` is not enough: panels also open from
  shortcuts (`quickshell ipc`, later Niri binds) without a click, and Niri
  only gives an on-demand layer the keyboard after a click on it. Quickshell
  also has no signal for losing on-demand focus, so a panel could not close
  when focus moved away. Exclusive means no other window takes keys while a
  panel is open, which is what Escape-to-close needs.
- **Click outside.** While a panel is open, every screen also maps a
  transparent full-screen `PanelWindow` (namespace `dotfiles-click-catcher`)
  whose mask is the screen minus the islands; a press on it closes the
  panel. Because the islands are cut out, it does not matter which of the
  two windows Niri stacks on top. The cut-out assumes the bar window starts
  at the top-left of the screen, which holds unless another surface reserves
  an exclusive zone on the top edge (for instance the DMS bar while both
  run).
- **State machine.** `services/Shell.qml` holds `centreState` (`collapsed`,
  `detail`, `home`, `settings`, `player`, `power`, `theme`, `wallpaper`,
  `updates`, `musicbar`), the screen it applies to, and `osdVisible`, with
  `open(state, screen)`, `close()`, `toggle(state, screen)` and
  `showOsd(screen)`. One state at a time, so opening another panel morphs
  the island into it; the OSD closes any panel first. The same functions are
  reachable over IPC (target `bar`); without a screen they act on the last
  used screen, or the first one.
- **Morphing.** `components/Island.qml` animates width, height, radius and
  the shadow with the Motion tokens (280 ms grow or morph, 220 ms shrink);
  panel bodies cross-fade in 140 ms. The centre island is centred on the
  window and its top is fixed, so it grows symmetrically and downward and the
  clock keeps its place in Detail.

## Layout

```text
chezmoi/dot_config/quickshell/bar/      -> ~/.config/quickshell/bar/
  shell.qml                             entry point: per screen the bar window and the click catcher
  Colors.qml                            singleton: DMS palette, watched
  Theme.qml                             singleton: sizes, radii, fonts, panel widths
  Motion.qml                            singleton: durations, curves, reduce motion
  qmldir                                registers the token singletons
  README.md                             short directory guide
  services/                             singletons that own state or data
    Shell.qml                           centre island state machine and IPC target `bar`
    Niri.qml ... Updates.qml            data services, see "Services"
  islands/                              the three islands
    LeftIsland.qml                      placeholder pill
    CentreIsland.qml                    weather, clock and battery pill, Detail, OSD and panel states
    RightIsland.qml                     placeholder pill, click opens Settings
  panels/                               centre panel bodies
    PlaceholderPanel.qml                stands in for a panel until its step lands
  components/                           shared pieces
    Island.qml                          island surface: colour, radius, shadow, size animation
    IslandAnimation.qml                 grow or shrink animation from the Motion tokens
    Hairline.qml                        1 x 14 px separator
    Clock.qml                           SystemClock text in a given format or formatter
    Icon.qml                            Material Symbols glyph by name, placeholder without the font
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
active mode (`primary`, `primaryForeground`, `primaryContainer`, `surface`,
`surfaceContainer`, `surfaceContainerHigh`, `foreground`, `foregroundVariant`,
`outline`, `error`) and `dark`. Every colour falls back to a Material dark
default when the file or the key is missing, and a missing file is retried
every five seconds, so the bar renders on a fresh machine and picks up the
palette once DMS has written it.

The font is Inter Variable from the `inter-font` package, the same family
DMS uses.

## Switching bars

`dms/look.json` records which bar is active through `barConfigs[0].enabled`:
`false` hands the bar to Quickshell, `true` or absent keeps the DMS bar.
`scripts/bar-switch.sh` changes that flag, applies it with
`scripts/dms-apply-look.sh` (which restarts DMS), and enables or disables
`quickshell-bar.service`.

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

- Clicks and scrolling outside the three islands reach the windows and the
  desktop below, also in the 480 px strip under the bar.
- Windows tile 36 px below the top edge, not below the tallest panel.
- The pill shows the current weather and battery icons as glyphs, not as
  dim squares, and the battery icon matches the charge and turns red under
  15 %.
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
   `weight` drive the font's variable axes. Without the font, or with an
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
| Night light, do not disturb, caffeine, theme mode, scheme | `dms ipc call night|notifications|inhibit|theme|settings` | Whether `settings set matugenScheme` re-renders colours is still to be tested. |
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
  `healthPercentage`, `energyCapacity` (Wh), `isLow` (under 15), `available`;
  `profile`, `profiles` (`power-saver`, `balanced`, `performance`),
  `setProfile(name)`.
- `Audio`: `volume`, `muted`, `micVolume`, `micMuted`, `ready`;
  `setVolume(v)`, `toggleMute()`, `setMicVolume(v)`, `toggleMicMute()`.
- `Brightness`: `percentage` (-1 until read), `device`, `available`;
  `set(p)` (1 to 100), `cycle()` (25, 50, 75, 100), `refresh()`. Reads the
  backlight class every 5 s and after each write.
- `Network`: `wifiEnabled`, `connected` (any device), `wifiConnected`,
  `ssid`, `strength`, `weak` (under 40); `toggleWifi()`.
- `Bluetooth`: `btEnabled`, `connectedDevices`, `available`;
  `toggleBluetooth()`.
- `Dms`: `nightLight`, `doNotDisturb`, `caffeine`, `themeMode`, polled every
  10 s and after each call; `toggleNightLight()`, `toggleDoNotDisturb()`,
  `toggleCaffeine()`, `setLight()`, `setDark()`, `openSettingsWindow()`,
  `setScheme(name)` (whether DMS re-renders the colours is to be verified),
  `refresh()`.
- `Notifications`: `items` (newest first: `id`, `appName`, `summary`,
  `body`, `timestamp` in ms, `appIcon`, `image`, `urgency`,
  `desktopEntry`), `count`; `dismiss(id)`, `clearAll()`. A missing or
  malformed history file is an empty list. Dismissals live in
  `$XDG_STATE_HOME/dotfiles-bar/notifications.json`; `clearAll()` also
  clears DMS's active notifications through `dms ipc`.
- `Music`: `hasPlayer`, `title`, `artist`, `artUrl`, `playing`, `position`,
  `length` (seconds), `artColors`, `artColor` (first quantised colour,
  `Colors.primaryContainer` without art); `play()`, `pause()`,
  `togglePlaying()`, `next()`, `previous()`.
- `Cava`: `enabled` (set by the orb and the wave), `running` (enabled and
  something plays), `bands` (24 levels), `level`, `low` (mean of the first
  four bands). Writes its config to `$XDG_RUNTIME_DIR/dotfiles-bar/cava.conf`.
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
- `System`: `active` (set by the Home panel), `cpu`, `temp` (°C, NaN
  without k10temp), `memory`, `memoryUsedGiB`, `memoryTotalGiB`. Samples
  every 2 s only while `active` is true.
- `Updates`: `items` (fragile first: `source`, `name`, `oldVersion`,
  `newVersion`, `fragile`), `count`, `fragileCount`, `checking`, `ready`,
  `lastChecked`; `refresh()`. Runs `~/.local/bin/system-update --pending`
  every 30 minutes.

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
| 4 | Home panel. | With 4 the DMS dashboard is covered; the own bar becomes the daily bar and DMS drops to fallback. |
| 5 | Left island (Niri), right island (tray, indicators), Updates panel plus `system-update --pending`. | Replaces the remaining DMS bar plugins. |
| 6 | Music: orb, music bar, Player, top-edge wave (Mpris, cava). | Highest render cost, least risk to daily use. |
| 7 | Theme, Wallpaper, Power, OSD; hide toggle; shortcuts moved. | Mostly plumbing to `dms ipc`. |

Code layout from step 0 on, under `chezmoi/dot_config/quickshell/bar/`:
`services/` for singletons that own data (Niri, Audio, Battery, Weather,
Music, Tray, Updates, Dms), `islands/` for the three islands,
`panels/` for the centre panel states, `components/` for shared pieces,
and `Theme.qml`, `Colors.qml`, `Motion.qml` for the tokens. Every step
lands as its own change with docs and tests; the DMS bar plugins are
deleted in the step that replaces their function.
