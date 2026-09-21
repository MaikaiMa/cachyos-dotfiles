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
- a row of five toggle tiles: Wallpaper (opens the dash wallpaper tab and shows
  the current wallpaper as its background), Wifi, Bluetooth, Caffeine and
  Do not disturb, filled with the primary colour when active;
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

## Services used

Everything reads and writes live DMS state; nothing shells out.

| Area | Service |
| --- | --- |
| Wi-Fi | `NetworkService` (`wifiEnabled`, `toggleWifiRadio`, `wifiSignalIcon`) |
| Bluetooth | `BluetoothService` (`enabled`, `connected`, `toggleBluetooth`) |
| Caffeine | `SessionService.idleInhibited` / `toggleIdleInhibit` |
| Do not disturb | `SessionData.doNotDisturb` / `setDoNotDisturb` |
| Wallpaper | `SessionData.wallpaperPath`, `PopoutService.toggleDankDash("wallpaper")` |
| Media | `MprisController`, `TrackArtService`, `MediaAccentService`, `DankSeekbar` |
| Brightness | `DisplayService` |
| Volume | `AudioService` (sink and source) |
| Battery | `BatteryService` |
| Power profiles | `PowerProfileWatcher` |
| System stats | `DgopService` |
| Header actions | `PopoutService` (dash, notification center, settings) |

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
