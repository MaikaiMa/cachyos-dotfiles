# Own Quickshell bar

The bar is moving from DMS to a repository-owned Quickshell configuration
([ADR-0027](adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)).
DMS stays the service layer: notifications, OSD, control center, lock screen,
polkit, theming. This page is the index for the own bar; [dms.md](dms.md)
keeps describing DMS.

## What the scaffold is

The current state is the bar scaffold: a 36 px layer-shell panel on every
screen with a placeholder capsule on the left, a clock in the centre and a
placeholder capsule on the right. It proves the wiring (unit, switch,
colours, font) and is meant to be used for real before widgets and panels
are written. It does not yet replace any function of the DMS bar.

## Layout

```text
chezmoi/dot_config/quickshell/bar/      -> ~/.config/quickshell/bar/
  shell.qml                             entry point, one PanelWindow per screen
  Clock.qml                             HH:mm from SystemClock
  Colors.qml                            singleton: DMS palette, watched
  Theme.qml                             singleton: font, sizes, radius, spacing
  qmldir                                registers the types of this directory
  README.md                             short directory guide
chezmoi/dot_config/systemd/user/quickshell-bar.service
scripts/bar-switch.sh                   switches between the DMS and the own bar
tests/bar-switch.sh                     switch script test with stubs
tests/quickshell-bar.sh                 qmllint over the bar
```

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
active mode (`primary`, `onPrimary`, `primaryContainer`, `surface`,
`surfaceContainer`, `surfaceContainerHigh`, `onSurface`, `onSurfaceVariant`,
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

After `chezmoi apply`, the deployed copy runs as `quickshell -c bar -n`.
Quickshell reloads the QML when a file changes, so edits show up without a
restart. Bring the service back with:

```fish
scripts/bar-switch.sh
```

## Adding a widget

1. Create `chezmoi/dot_config/quickshell/bar/<Name>.qml` with an upper-case
   name. Take colours from `Colors` and sizes and fonts from `Theme`; never
   hard-code a colour.
2. Add `<Name> 1.0 <Name>.qml` to `qmldir`. The directory has its own
   `qmldir`, so Quickshell does not synthesise one and a type that is not
   listed is not found.
3. Place it in one of the three regions in `shell.qml`.
4. Run `tests/quickshell-bar.sh`; it fails on any qmllint warning other than
   the known `PanelWindow is not creatable` one.
5. Where the widget opens something the own bar has no panel for yet, call
   the matching `dms ipc` function, as ADR-0027 describes.

## Phases

[ADR-0027](adr/ADR-0027-own-the-bar-and-panels-in-quickshell-with-dms-as-service-layer.md)
sets the order: bar scaffold with the switch (this page), then one or two
real widgets used day to day, then panels anchored to bar widgets, and
finally the lock screen and greeter as a separate `quickshell/session/`
tree with its own ADR. The DMS bar plugins stay until the own bar has
replaced their function.

Widgets and panels in every phase follow the design contract in
[shell-design.md](shell-design.md); the interactive prototype in
[design/bar-prototype.html](design/bar-prototype.html) shows its states at
real size.
