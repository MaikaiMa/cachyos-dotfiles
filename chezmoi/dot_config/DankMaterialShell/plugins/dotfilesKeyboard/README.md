# dotfilesKeyboard

A DankMaterialShell bar widget for tablet use on the 2025 ROG Flow Z13: a
keyboard button that shows or hides the squeekboard on-screen keyboard. It is
visible only while the keyboard cover is detached. See
[docs/tablet.md](../../../../../docs/tablet.md) for the whole tablet setup.

## What it does

- Runs `~/.local/bin/tablet-mode watch` and shows the pill while it reports
  `tablet`; on other hardware the helper always reports `laptop`, so the pill
  never appears there. Showing and hiding go through `PluginComponent`'s
  `setVisibilityOverride()`, which collapses the pill to zero width; the bar's
  `Row` skips zero-width widgets, so no gap or doubled spacing is left behind.
  Setting `visible` alone is not enough: the bar sizes each slot from the
  widget's width, not its visibility.
- While squeekboard is visible the pill shows `keyboard_hide` in
  `Theme.primary`, the way built-in toggles such as the idle inhibitor mark
  their active state. The state comes from `osk watch`, which follows
  squeekboard's `Visible` property through `PropertiesChanged` signals and
  resets to hidden when squeekboard stops or restarts.
- A tap runs `osk toggle`, which starts squeekboard's
  `mobi.phosh.OSK.service` when needed and flips its `sm.puri.OSK0`
  `Visible` state.
- When the cover is attached again, the widget runs `osk hide` before hiding
  itself, so squeekboard does not stay on screen.
- If either watcher exits, `LineWatcher.qml` restarts it after five seconds.

## Placing it in the bar

`dms/look.json` puts `dotfilesKeyboard` in `barConfigs[0].rightWidgets`
directly after `dotfilesDashboard`, the widget with the Wi-Fi, Bluetooth and
audio indicators.

## Services used

- `Quickshell` - `env`, `execDetached`; `Quickshell.Io` `Process` and
  `SplitParser` in `LineWatcher.qml`
- `PluginComponent` - `setVisibilityOverride`, `effectiveVisible`
- `Theme` - `widgetIconColor`, `primary`

## Known limits

- The helpers are called by absolute path under `~/.local/bin`, where chezmoi
  deploys them.
- There are no user-facing strings, so there is no translation catalogue and
  no settings UI.

## Reloading during development

`dms ipc call plugins reload <id>` only re-reads the manifest component, so an edit
to any other file in this directory needs a shell restart:

```fish
systemctl --user restart dms.service
```

The `dms-reset` fish function does the same thing.
