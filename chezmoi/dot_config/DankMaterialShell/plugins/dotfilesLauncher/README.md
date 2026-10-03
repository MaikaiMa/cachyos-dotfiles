# dotfilesLauncher

A DankMaterialShell bar widget: the built-in apps-grid launcher icon on a filled
`Theme.primary` pill instead of the default neutral widget background. A click
opens Vicinae, the launcher (`docs/launcher.md` in the repository).

## What it does

- Draws the `apps` icon in `Theme.primaryText` on a `Theme.primary` pill, with a
  `Theme.hoverTint` hover state.
- Drop-in replacement for the built-in `launcherButton` widget id in
  `barConfigs[<n>].leftWidgets`.
- Left click runs `vicinae toggle`, the same as `Mod+Space`; right click toggles
  the Niri overview, the same as the built-in widget.
- A long press (press and hold, for example by touch) also toggles the Niri
  overview and does not open Vicinae. `BasePill` fires its click on
  press and has no long-press hook, so the pill takes the left button in its
  own `MouseArea`: a tap opens Vicinae on release, with the pill's own
  ripple. Right clicks still go through `BasePill`'s `pillRightClickAction`.
  There is no setting for it; the widget has no settings UI.

## Services used

- `Quickshell` - `execDetached`, which runs `vicinae toggle`
- `CompositorService` - `isNiri`, `getScreenScale`
- `NiriService` - `toggleOverview`
- `Theme` - `primary`, `primaryText`, `hoverTint`, `cornerRadius`, `barIconSize`,
  `snap`

## Known limits

- The pill colour is fixed to `Theme.primary`; there is no settings UI of its own.
- Right click and long press do nothing outside niri, because the overview is a
  niri feature.
- The pill's own `MouseArea` covers the visible pill only; a left click in the
  bar spacing next to it still reaches `BasePill`, which opens Vicinae on
  press.
- `BasePill`'s padding is not exposed to plugins, so the fill inset is recomputed
  from `widgetPadding` and `removeWidgetPadding`; a change to that formula in DMS
  will misalign the fill until this copy follows.

## Reloading during development

`dms ipc call plugins reload <id>` only re-reads the manifest component, so an edit
to any other file in this directory needs a shell restart:

```fish
systemctl --user restart dms.service
```

The `dms-reset` fish function does the same thing.
