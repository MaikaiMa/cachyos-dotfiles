# DMS look: mat-glass bar mirroring Noctalia

`dms/look.json` is a map of DankMaterialShell (DMS) setting keys to the
values that reproduce the previous Noctalia bar and panel look (see
`chezmoi/dot_config/noctalia/bar.toml` and `config.toml`) using DMS 1.6.2
settings only — no QML, no plugin. `scripts/dms-apply-look.sh` applies it to
the running shell. Both files live outside `chezmoi/` until the look is
accepted; see `docs/desktop-migration.md` phase 1.

## Why the apply script edits settings.json directly

`dms ipc call settings set <key> <value>` cannot set `barConfigs`: DMS
1.6.2's IPC `set` handler explicitly rejects object and array values
(`quickshell/DMSShellIPC.qml`, the `settings` handler's `set()` throws
`"Setting Objects and Arrays not supported"` for anything typed `object`,
which includes arrays). Since the bar layout is the point of this look, the
script merges `dms/look.json` into
`~/.config/DankMaterialShell/settings.json` with `jq` instead, for every key,
so there is only one code path to reason about. It stops `dms.service`
before writing and starts it again after, so DMS does not race the edit or
overwrite it with its own autosave.

## Applying it

```fish
./scripts/dms-apply-look.sh --dry-run
```

Review the printed before/after diff, then apply for real:

```fish
./scripts/dms-apply-look.sh
```

The first real run backs up the previous file to
`~/.config/DankMaterialShell/settings.json.before-look` (once — later runs
do not overwrite that backup). The script is idempotent: running it again
with an unchanged `dms/look.json` reports nothing to do and does not touch
`dms.service`.

## Iterating on feedback

Edit `dms/look.json`, re-run `--dry-run` to see the diff, then apply. To
revert everything from this look:

```fish
cp ~/.config/DankMaterialShell/settings.json.before-look ~/.config/DankMaterialShell/settings.json
systemctl --user restart dms.service
```

## What each key does

| Key | Effect |
| --- | --- |
| `cornerRadius` | Global corner radius (`16`, matching Noctalia's `bar.radius`); DMS bar pills and popups use it unless a bar overrides its own corners. |
| `niriLayoutGapsOverride`, `niriLayoutRadiusOverride` | Niri window gap and corner radius, already set live (`-2`, `20`); included so the file is a complete description of the look. |
| `currentThemeName`, `currentThemeCategory` | `"dynamic"`: theme colors are generated from the wallpaper instead of a fixed palette. |
| `matugenSmartMode` | Lets matugen pick light/dark and contrast from the wallpaper automatically. |
| `runUserMatugenTemplates`, `runDmsMatugenTemplates` | Regenerate both the user's and DMS's own matugen templates when the theme changes, so terminals and GTK/Qt apps stay in sync with the wallpaper too. |
| `popupTransparency`, `foregroundLayerTransparency` | `0.85`: Control Center, Dashboard, and other popups read as translucent glass over the wallpaper rather than flat opaque panels. |
| `blurEnabled`, `blurForegroundLayers`, `blurredWallpaperLayer` | All off. DMS's own blur blurred the wallpaper itself; the glass comes from a Niri `layer-rule` on the `^dms:` namespaces in `cfg/rules.kdl` instead. |
| `blurBorderEnabled` | `false`: no outline around the blurred glass, for a cleaner edge. |
| `barElevationEnabled` | `false`: removes the bar's drop shadow; Noctalia's bar had `shadow = false`. |
| `audioVisualizerEnabled` | Enables the cava-driven visualizer bars inside the `music` bar widget. |
| `showWorkspaceApps`, `showOccupiedWorkspacesOnly` | The workspace switcher shows per-app icons grouped in each workspace pill, and hides empty workspaces — this is what gives the left group its "workspace pills with running app icons" look without a separate running-apps widget. |
| `barConfigs[id=default].leftWidgets` | `launcherButton`, `workspaceSwitcher`, `dotfilesApps` — the app grid button, compact workspace pills, and the repository plugin that shows the current workspace's apps with a focus highlight and a notification dot. |
| `barConfigs[id=default].centerWidgets` | `music`, `clock`, `weather` — the `music` widget is where `audioVisualizerEnabled` draws its bars. |
| `barConfigs[id=default].rightWidgets` | `systemTray`, `dotfilesDashboard`, `systemUpdate` (with `hideWhenIdle`), `notificationButton`, `battery`, `powerMenuButton`. The dashboard plugin's button shows the Wi-Fi, Bluetooth and audio state and opens the dashboard; DMS 1.6.2 has no separate toggle widgets. |
| `barConfigs[id=default].spacing`, `.widgetPadding`, `.barLengthPadding`, `.bottomGap`, `.innerPadding` | `6`, `10`, `12`, `4`, `4` — spacing between widgets, padding inside each capsule, and the margins from the screen edges, close to Noctalia's `widget_spacing = 6`, capsule `padding = 8-10`, and `margin_ends = 12`. |
| `barConfigs[id=default].transparency`, `.widgetTransparency`, `.noBackground` | `0.6`, `0.75`, `false` — a translucent bar strip, blurred by Niri, with a glass capsule per widget. In DMS `noBackground` removes the widget capsules, not the bar surface, so it stays off. |
| `barConfigs[id=default].squareCorners`, `.gothCornersEnabled`, `.borderEnabled`, `.widgetOutlineEnabled`, `.shadowIntensity` | `false`, `false`, `false`, `false`, `0` — rounded corners (via the global `cornerRadius`), no borders or outlines, no shadow. |

## Spec keys that do not exist in DMS 1.6.2

- No standalone bar widget for the audio visualizer: it is a mode of the
  `music` widget, gated by `audioVisualizerEnabled` and `cava` being
  installed (`packages/pacman.txt` already lists `cava` per
  `docs/desktop-migration.md` phase 2). There is no `audioVisualizer` widget
  id in `barConfigs`.
- No individual bar widgets for volume, brightness, bluetooth, wifi, or
  power-profile the way Noctalia's `bar.dotfiles` capsule groups had them;
  see the `rightWidgets` row above.
