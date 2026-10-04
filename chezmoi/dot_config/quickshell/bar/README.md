# Quickshell bar

The repository-owned bar from
[ADR-0027](../../../../docs/adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md).
chezmoi deploys this directory to `~/.config/quickshell/bar/`;
`quickshell-bar.service` runs it. The index for the bar is
[docs/shell.md](../../../../docs/shell.md).

```text
shell.qml    entry point: one PanelWindow per screen, left / centre / right
Clock.qml    HH:mm from SystemClock
Colors.qml   singleton: DMS palette from dms-colors.json, with dark fallbacks
Theme.qml    singleton: font, font size, radius, spacing, bar height
qmldir       registers the singletons and components of this directory
```

Run the deployed copy by hand, after stopping the service (otherwise two bars
are drawn):

```fish
systemctl --user stop quickshell-bar.service
quickshell -c bar -n
```

Run the repository copy without deploying it:

```fish
quickshell -p chezmoi/dot_config/quickshell/bar -n
```
