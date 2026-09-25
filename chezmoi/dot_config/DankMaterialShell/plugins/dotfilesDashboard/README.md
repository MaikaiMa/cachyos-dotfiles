# Dotfiles Dashboard

A DankMaterialShell bar widget that rebuilds the previous Noctalia dashboard
(`maikel/quick-controls`) as a DMS popout. It replaces the built-in
`controlCenterButton` in the right capsule: the bar button shows the same
compact Wi-Fi, Bluetooth and audio-volume indicators, and clicking it opens the
dashboard instead of the Control Center.

## Contents

The popout is a mat-glass panel with, top to bottom:

- a header "Dashboard" with buttons for the DMS dash, the notification center,
  shell settings and close;
- a row of six toggle tiles: Wallpaper (opens the dash wallpaper tab and shows
  the current wallpaper as its background), Rotation lock, Wifi, Bluetooth,
  Caffeine and Do not disturb, filled with the primary colour when active;
- directly under that row, a folding details section for the Wifi or Bluetooth
  tile (see [Connection details](#connection-details));
- a media card with album art, title, artist, previous/play/next and a seekbar
  with elapsed and total time;
- a "Display & audio" card with a brightness slider and output and input volume
  sliders, each with a mute button;
- a "Power" card with battery percentage, status, remaining time, a charge bar
  and the Power Saver / Balanced / Performance profile buttons;
- a row of four stat tiles (CPU, Memory, GPU, Network) with a sparkline each.

## Opening it

- Click the bar button (widget id `dotfilesDashboard`, listed in
  `barConfigs[0].rightWidgets`).
- `dms ipc call widget toggle dotfilesDashboard`.

Both routes need the widget to be present in a bar; DMS only registers widgets
that a bar actually renders.

## Placement

DMS anchors a plugin popout under the pill that opened it. The dashboard instead
opens horizontally centred, with its top edge where Niri starts tiled windows.
`DashboardPopout.placePopout()` does this by writing `triggerX`, `triggerWidth`
and `triggerY` on the injected `parentPopout` (the `PluginPopout`), which the
popout's own `alignedX` / `alignedY` bindings then follow. DMS rewrites those
three values on every open, so the placement is re-applied from `Connections` on
the popout. The DMS open/close animation, backdrop and click-outside-to-close
are untouched.

## Connection details

The Wifi and Bluetooth tiles still toggle their radio on a click. Details are
only available while the radio is on: a chevron at the tile's right edge, on
the vertical centre, then opens that tile's details, and a right click or a
long press (the system press-and-hold interval, 800 ms by default) on the tile
does the same without toggling. While the radio is off the chevron is hidden
and there is no right-click handling, but a long press on the tile turns the
radio on and, once it reports itself on, opens that tile's details; a plain
click still just toggles the radio. The section opens below the toggle row,
one tile at a time: requesting the open tile again closes it, requesting the
other tile swaps the content. The open tile gets a primary ring and a flipped
chevron. Turning a radio off while its section is open collapses that section.
The section also collapses once the dashboard has finished closing, so it
always opens collapsed. If a radio is still turning on when the dashboard
closes, or the user opens a different section in the meantime, the pending
long-press-to-expand is dropped rather than popping the section open later.

The content is DMS's own Control Center panels, `NetworkDetail` and
`BluetoothDetail` from `qs.Modules.ControlCenter.Details`, hosted by
`ConnectionDetails.qml` the way the Control Center's `DetailHost` hosts them:

- 350 pixels high, less when the screen has no room below the dashboard;
- loaded only while the section is open or folding, because `NetworkDetail`
  holds a `NetworkService` ref for its lifetime and that ref keeps DMS scanning
  for Wi-Fi networks every 10 seconds;
- Bluetooth discovery started with the panel's Scan button is stopped when the
  panel unloads, which the Control Center otherwise does on close;
- the panel's audio-codec menu entry opens a `BluetoothCodecSelector` overlay
  over the whole dashboard.

Escape works in layers: it first closes the Bluetooth device menu or the codec
selector when one is open, then collapses an open section with its animation,
and only then closes the dashboard. The dashboard takes the keyboard while a
section is open, and takes it back from the Bluetooth panel after its device
menu and from the codec selector when that hides, so the layers hold wherever
the focus was.

The dashboard closes when NetworkManager asks for Wi-Fi credentials or polkit
asks for authentication, as the Control Center does, because the open popout
holds the keyboard those prompts need.

The popout height is bound to the height the dashboard will have once the
section has finished moving, rather than to its animated height, so DMS's own
resize animation runs alongside the section's instead of chasing it.

## Extra actions

- Clicking a stat tile closes the dashboard and opens the DMS system monitor on
  the matching view: CPU and Memory open the Processes tab sorted by that column
  (`DgopService.setSortBy`), GPU and Network open the Performance tab. It uses
  the modal's `focusOrToggle()`, so an already open monitor is focused instead of
  closed.
- Clicking the album art focuses the window of the playing media player. The
  MPRIS desktop entry, identity and bus name (including their last reverse-DNS
  segment) are matched against `appId` in `CompositorService.sortedToplevels`,
  with the track title against the window title as a fallback for browsers. When
  nothing matches it opens the DMS media dash instead. The activation is delayed
  until the popout has closed, because the open popout holds the keyboard focus.
- The header's settings button uses `focusOrToggleSettings()`, so an open
  settings window is focused rather than closed.

## Rotation lock

The Rotation lock tile runs `~/.local/bin/auto-rotate lock toggle` and shows
the state the command prints; the state is re-read with `auto-rotate lock
status` every time the dashboard opens, because it can also change from a
terminal. `auto-rotate.service` keeps a detached Z13 in its current
orientation while the lock is on; with the keyboard attached the panel stays
upright regardless. See [docs/tablet.md](../../../../../docs/tablet.md).

## Services used

Everything else reads and writes live DMS state and does not shell out.

| Area | Service |
| --- | --- |
| Wi-Fi | `NetworkService` (`wifiEnabled`, `toggleWifiRadio`, `wifiSignalIcon`, `credentialsRequested`); details: `NetworkDetail` |
| Bluetooth | `BluetoothService` (`enabled`, `connected`, `toggleBluetooth`, `adapter.discovering`); details: `BluetoothDetail`, `BluetoothCodecSelector` |
| Caffeine | `SessionService.idleInhibited` / `toggleIdleInhibit` |
| Do not disturb | `SessionData.doNotDisturb` / `setDoNotDisturb` |
| Wallpaper | `SessionData.wallpaperPath`, `PopoutService.toggleDankDash("wallpaper")` |
| Media | `MprisController`, `TrackArtService`, `MediaAccentService`, `DankSeekbar` |
| Brightness | `DisplayService` |
| Volume | `AudioService` (sink and source) |
| Battery | `BatteryService` |
| Power profiles | `PowerProfileWatcher` |
| System stats | `DgopService` |
| Rotation lock | `auto-rotate lock` through a `Quickshell.Io` `Process` |
| Header actions | `PopoutService` (dash, notification center, settings); the dash and notification-center loaders are activated first because DMS 1.6 loads them lazily and the toggles are no-ops before |

## Known limits

- dgop exposes GPU temperature but no GPU utilisation, so the GPU tile shows
  °C where the Noctalia dashboard showed a percentage.
- dgop keeps no GPU history either, so that sparkline only covers the time the
  popout has been open; CPU, memory and network reuse dgop's 60-sample history.
- dgop mutates its history arrays in place without a change signal, so the
  sparklines are repainted from a 1 Hz timer while the popout is open.
- Night light is absent, as it was in the Noctalia dashboard.
- The bar button follows the existing `controlCenterShow*` settings for which
  indicators to show, but has no settings UI of its own.
- The 2 logical pixel offset between the bar and the first window row is Niri's,
  not something DMS reports, so it is a constant in `DashboardPopout.qml`.
- DMS keeps the popout content loaded after a close, so the stat timers and the
  `DgopService` refs are tied to `parentPopout.shouldBeVisible` by hand.
- The details panels are DMS internals, not plugin API, so a DMS update can
  change their properties or behaviour. Their buttons that open DMS settings
  close the Control Center rather than the dashboard.
- `BluetoothDetail` has its own Escape handler that closes the Control Center, so
  `ConnectionDetails.qml` moves the keyboard off that panel whenever it takes
  it; a DMS change to how the panel grabs focus could bring that handler back.
- `DashboardPopout.bindPopoutHeight()` replaces the height binding that
  `PluginPopout` sets on load; a DMS change to that loader would bring back the
  animated binding, which still works but resizes less smoothly.
- A plugin cannot reach its own bar pill's visual geometry, so the notification
  centre is opened from the dashboard popout's trigger values instead, which puts
  it in the same centred place as the dashboard.

## Translations

Every user-facing string goes through `I18n.trFor("dotfilesDashboard", ...)`, and
`translations/nl.json` holds the Dutch catalogue, reusing the wording of the
Noctalia dashboard where it had one. DMS reads the file that matches
`SessionData.locale` (Settings, Locale) and reloads it when the locale changes;
the English strings in the QML are the source and the fallback. Terms whose
Dutch is the English word, such as `Wifi` and `Caffeine`, are listed with an
identical translation so DMS's own catalogue cannot rename them later.

## Reloading during development

`dms ipc call plugins reload <id>` only re-reads the manifest component, so an edit
to any other file in this directory needs a shell restart:

```fish
systemctl --user restart dms.service
```

The `dms-reset` fish function does the same thing.
