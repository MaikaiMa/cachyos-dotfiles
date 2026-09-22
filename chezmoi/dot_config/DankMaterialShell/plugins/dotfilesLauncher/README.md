# dotfilesLauncher

A DankMaterialShell bar widget: the built-in apps-grid launcher icon on a filled
`Theme.primary` pill instead of the default neutral widget background.

## What it does

- Draws the `apps` icon in `Theme.primaryText` on a `Theme.primary` pill, with a
  `Theme.hoverTint` hover state.
- Drop-in replacement for the built-in `launcherButton` widget id in
  `barConfigs[<n>].leftWidgets`.
- Left click opens the app drawer, right click toggles the Niri overview, the same
  as the built-in widget.

## Services used

- `PopoutService` - `appDrawerLoader`, `toggleAppDrawer` (the loader is activated
  first, because DMS 1.6 loads the drawer lazily and the toggle is a no-op before)
- `CompositorService` - `isNiri`, `getScreenScale`
- `NiriService` - `toggleOverview`
- `Theme` - `primary`, `primaryText`, `hoverTint`, `cornerRadius`, `barIconSize`,
  `snap`

## Known limits

- The pill colour is fixed to `Theme.primary`; there is no settings UI of its own.
- Right click does nothing outside niri, because the overview is a niri feature.
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
