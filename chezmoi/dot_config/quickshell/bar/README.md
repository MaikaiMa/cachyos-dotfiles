# Quickshell bar

The repository-owned bar from
[ADR-0027](../../../../docs/adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md).
chezmoi deploys this directory to `~/.config/quickshell/bar/`;
`quickshell-bar.service` runs it. The index for the bar is
[docs/shell.md](../../../../docs/shell.md).

```text
shell.qml        entry point: the IPC targets (services/BarIpc.qml) and, per screen,
                 the three windows in windows/
Colors.qml       singleton: DMS palette from dms-colors.json, with dark fallbacks; privacy dot colours
Theme.qml        singleton: bar, island and panel sizes, radii, fonts, opacities; slider and seek steps
Motion.qml       singleton: durations and curves; reduce motion follows Settings
qmldir           registers the token singletons
windows/         BarWindow (islands, blobs, glow, privacy dock, mask, blur, keyboard focus,
                 and the close area while a panel is open), OrbSurface (the orb's own box)
                 with Orb, WaveSurface (the top-edge wave's strip) with TopWave; FrameCounter
services/        singletons that own state or data; Shell.qml is the centre island state machine
                 and sets every service's `active`; BarIpc.qml holds the IPC targets `bar` and
                 `notifications`; Notifications.qml is the notification daemon (ADR-0028),
                 NotificationStack.qml its peek stack; Time.qml the one minute clock;
                 Appearance.qml the Light / Dark / Auto and scheme switching through DMS,
                 Dms.qml the rest of `dms ipc`; Settings.qml the bar's runtime switches,
                 Paths.qml the XDG paths; the types Command, CommandReader, CommandWriter and
                 LineWatcher wrap external commands; maps.js (the Maps resource)
islands/         LeftIsland (workspaces, apps); CentreIsland with CentrePill (weather, clock,
                 battery, Detail), Osd, MusicBar with Marquee and RimLight, MusicGlow and
                 MusicFade, CentrePanels (the eleven panels) and PrivacyDock with PrivacyDots
                 beside it; RightIsland (tray, StatusIndicator pills, or the notification
                 stack in their place) with TrayMenu and PeekStack of NotificationPeekRow;
                 NotificationBlobs (disc blobs below it)
panels/          Panel (the base) and the centre panel bodies: HomePanel, SettingsPanel,
                 UpdatesPanel, PlayerPanel, PowerPanel, ThemePanel, WallpaperPanel, WifiPanel,
                 BluetoothPanel, SoundPanel, DisplayPanel; their parts NotificationList and
                 NotificationRow (Settings), AppVolumeRow (Sound), PanelControlRow (the
                 panels opened from Settings)
components/      shared pieces every widget is built from, service-free except Clock and
                 BatteryIcon: Island, IslandShadow and MorphAnimation, Crossfade,
                 ColorCrossfade, Appear, Label, FocusRing, Pressable, IconButton, PillButton,
                 InlineField, KeyedListModel, ScrollHint, SectionHeader, AppIconDisc,
                 FillTrack, ChevronZone, RoundedImage, Surface, Hairline, Clock, Icon
                 (Material Symbols), WeatherIcon, BatteryIcon, SegmentedControl, Tile,
                 CapsuleSlider, Carousel, ListRow, RowList and RowActions.js (the RowActions
                 resource)
components/home/ the Home tiles: TimeTile, WeatherTile, PerformanceTile, PowerTile
```

Every directory with types has its own `qmldir` that lists all of them.

Run the deployed copy by hand, after stopping the service (otherwise two bars
are drawn); docs/shell.md lists what to check:

```fish
systemctl --user stop quickshell-bar.service
quickshell -c bar -n
```

Run the repository copy without deploying it. Files import each other as
`qs` modules (`import qs.services`), which Quickshell resolves from the
folder of `shell.qml`, so any copy of this directory runs as it is:

```fish
quickshell -p chezmoi/dot_config/quickshell/bar -n
```
