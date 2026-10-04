# Quickshell bar

The repository-owned bar from
[ADR-0027](../../../../docs/adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md).
chezmoi deploys this directory to `~/.config/quickshell/bar/`;
`quickshell-bar.service` runs it. The index for the bar is
[docs/shell.md](../../../../docs/shell.md).

```text
shell.qml        entry point: per screen the bar window (islands, mask, blur,
                 keyboard focus, and the close area while a panel is open)
Colors.qml       singleton: DMS palette from dms-colors.json, with dark fallbacks
Theme.qml        singleton: bar, island and panel sizes, radii, fonts
Motion.qml       singleton: durations and curves, reduce motion
qmldir           registers the token singletons
services/        singletons that own state or data; Shell.qml is the centre island state machine
islands/         LeftIsland (workspaces, apps), CentreIsland (weather, clock, battery,
                 Detail), RightIsland (tray, attention indicators)
panels/          centre panel bodies: HomePanel, SettingsPanel, UpdatesPanel;
                 PlaceholderPanel until the others land
components/      Island surface and its animation, Hairline, Clock, Icon (Material Symbols),
                 WeatherIcon, BatteryIcon, SegmentedControl; Tile, CapsuleSlider and
                 NotificationRow for Settings; TimeTile, WeatherTile, PerformanceTile and
                 PowerTile for Home
```

Every directory with types has its own `qmldir` that lists all of them.

Run the deployed copy by hand, after stopping the service (otherwise two bars
are drawn); docs/shell.md lists what to check:

```fish
systemctl --user stop quickshell-bar.service
quickshell -c bar -n
```

Run the repository copy without deploying it:

```fish
quickshell -p chezmoi/dot_config/quickshell/bar -n
```
