# DankMaterialShell: the deployed desktop shell

[ADR-0013](adr/ADR-0013-replace-noctalia-with-dms-and-quickshell-surfaces.md)
replaces Noctalia with DankMaterialShell (DMS) 1.6.2. `docs/desktop-migration.md`
phase 2 moved the shell into the chezmoi-managed tree; this guide documents the
result and how to iterate on it day to day. The former Noctalia configuration
is preserved only as the `noctalia-final` Git tag.

## What is deployed

- **Service wiring.** DMS starts from its own packaged systemd user unit,
  `/usr/lib/systemd/user/dms.service`, wanted by `niri.service` through the
  chezmoi-managed symlink
  `chezmoi/dot_config/systemd/user/niri.service.wants/symlink_dms.service`,
  the same pattern ADR-0007 used for Noctalia.
- **The look.** `dms/look.json` maps DMS setting keys to the mat-glass look
  (corner radius, transparency, blur, bar widget layout, wallpaper theming);
  `scripts/dms-apply-look.sh` merges it into
  `~/.config/DankMaterialShell/settings.json`. See "The mat-glass look" below
  for why it edits the file directly instead of using `dms ipc call settings
  set`.
- **Four repository plugins** under
  `chezmoi/dot_config/DankMaterialShell/plugins/`, enabled through
  `chezmoi/dot_config/DankMaterialShell/plugin_settings.json`:
  - [`dotfilesLauncher`](../chezmoi/dot_config/DankMaterialShell/plugins/dotfilesLauncher/README.md)
    draws the built-in apps-grid launcher icon on a filled primary-colour
    pill instead of the default neutral background; a drop-in replacement
    for the built-in `launcherButton` widget.
  - [`dotfilesWorkspaces`](../chezmoi/dot_config/DankMaterialShell/plugins/dotfilesWorkspaces/README.md)
    replaces the built-in workspace switcher with compact pills that turn
    red when a window on that workspace has a notification waiting.
  - [`dotfilesApps`](../chezmoi/dot_config/DankMaterialShell/plugins/dotfilesApps/README.md)
    shows the running and pinned applications as bar icons, with a focus
    highlight, a red notification dot, and dismissal of that app's
    notifications once it has held focus for a moment.
  - [`dotfilesDashboard`](../chezmoi/dot_config/DankMaterialShell/plugins/dotfilesDashboard/README.md)
    rebuilds the former Noctalia dashboard as a DMS popout on `Mod+S`
    (wallpaper, Wi-Fi, Bluetooth, caffeine, do-not-disturb toggles, media,
    display and audio, power, and system stats), centred under the bar.
- **Niri integration.** `chezmoi/dot_config/niri/config.kdl` includes
  `dms/layout.kdl` and `dms/colors.kdl`, which DMS itself writes, so the Niri
  focus ring width and colour follow the DMS primary colour on every theme
  change. A `layer-rule` in `chezmoi/dot_config/niri/cfg/rules.kdl` turns off
  x-ray background effects for layers matching `^dms:`, so DMS's own blurred
  surfaces are not see-through. `chezmoi/dot_config/niri/cfg/layout.kdl` sets
  `gaps 10` and struts that align tiled windows with the bar.
- **matugen templates**, Niri backdrop and the Z13 template, see below.

## The mat-glass look

`dms/look.json` is a map of DMS setting keys to the values that reproduce the
previous Noctalia bar and panel look (see the `noctalia-final` tag's
`chezmoi/dot_config/noctalia/bar.toml` and `config.toml`) using DMS 1.6.2
settings only — no QML, no plugin.

### Why the apply script edits settings.json directly

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

### Applying it

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

### Iterating on feedback

Edit `dms/look.json`, re-run `--dry-run` to see the diff, then apply. To
revert everything from this look:

```fish
cp ~/.config/DankMaterialShell/settings.json.before-look ~/.config/DankMaterialShell/settings.json
systemctl --user restart dms.service
```

### What each key does

| Key | Effect |
| --- | --- |
| `cornerRadius` | Global corner radius (`16`, matching Noctalia's `bar.radius`); DMS bar pills and popups use it unless a bar overrides its own corners. |
| `niriLayoutGapsOverride`, `niriLayoutRadiusOverride` | Niri window gap and corner radius, already set live (`-2`, `20`); included so the file is a complete description of the look. |
| `currentThemeName`, `currentThemeCategory` | `"dynamic"`: theme colors are generated from the wallpaper instead of a fixed palette. |
| `matugenSmartMode` | Lets matugen pick light/dark and contrast from the wallpaper automatically. |
| `runUserMatugenTemplates`, `runDmsMatugenTemplates` | Regenerate both the user's and DMS's own matugen templates when the theme changes, so terminals and GTK/Qt apps stay in sync with the wallpaper too. `runUserMatugenTemplates` is also what makes DMS process `~/.config/matugen/config.toml`; see "matugen templates: Niri backdrop and the Z13 rear-window color" below. |
| `popupTransparency`, `foregroundLayerTransparency` | `0.85`: Control Center, Dashboard, and other popups read as translucent glass over the wallpaper rather than flat opaque panels. |
| `blurEnabled`, `blurForegroundLayers`, `blurBorderEnabled`, `blurredWallpaperLayer` | DMS blur through Niri's `ext-background-effect` protocol: on, on, on, off. It blurs only behind translucent pixels of DMS's own surfaces. `blurredWallpaperLayer` stays off: it draws a blurred wallpaper copy for the overview and needs a `place-within-backdrop` rule that is not included, so it made the whole wallpaper look blurred. A Niri `layer-rule` blur is not an option: it covers the whole layer surface, which is larger than the visible bar or popup. |
| `blurBorderEnabled` | `false`: no outline around the blurred glass, for a cleaner edge. |
| `barElevationEnabled` | `false`: removes the bar's drop shadow; Noctalia's bar had `shadow = false`. |
| `audioVisualizerEnabled` | Enables the cava-driven visualizer bars inside the `music` bar widget. |
| `trayAutoOverflow`, `trayMaxVisibleItems` | `true`, `1` — one tray icon in the bar, the rest behind the expand button. |
| `niriLayoutBorderSize` | `1` — DMS writes `dms/layout.kdl` with this border and focus-ring width; the managed `config.kdl` includes that file and `dms/colors.kdl`, so the Niri focus ring follows the DMS primary color on every theme change. |
| `acLockTimeout`, `acSuspendTimeout`, `batteryLockTimeout`, `batterySuspendTimeout` | Idle behaviour, see "Idle, lock, and suspend" below. |
| `updaterCheckOnStart` | Checks for pacman, AUR and Flatpak updates right after the shell starts; the interval check (30 minutes by default) continues afterwards. |
| `showWorkspaceApps`, `showOccupiedWorkspacesOnly` | The workspace switcher shows per-app icons grouped in each workspace pill, and hides empty workspaces — this is what gives the left group its "workspace pills with running app icons" look without a separate running-apps widget. |
| `barConfigs[id=default].leftWidgets` | `dotfilesLauncher`, `dotfilesWorkspaces`, `dotfilesApps` — the repository launcher button, workspace pills, and app icons with focus highlight and notification dot. |
| `barConfigs[id=default].centerWidgets` | `weather`, `clock`, `battery`. |
| `barConfigs[id=default].rightWidgets` | `music` (with `mediaSize` 2, where `audioVisualizerEnabled` draws its bars), `systemTray`, `dotfilesDashboard`, `systemUpdate` (with `hideWhenIdle`), `notificationButton`, `powerMenuButton`. The dashboard plugin's button shows the Wi-Fi, Bluetooth and audio state and opens the dashboard; DMS 1.6.2 has no separate toggle widgets. |
| `barConfigs[id=default].spacing`, `.widgetPadding`, `.barLengthPadding`, `.bottomGap`, `.innerPadding` | `6`, `10`, `12`, `4`, `4` — spacing between widgets, padding inside each capsule, and the margins from the screen edges, close to Noctalia's `widget_spacing = 6`, capsule `padding = 8-10`, and `margin_ends = 12`. |
| `barConfigs[id=default].transparency`, `.widgetTransparency`, `.noBackground` | `0.6`, `0.75`, `false` — a translucent, blurred bar strip with a capsule per widget. In DMS `noBackground` removes the widget capsules, not the bar surface, so it stays off. |
| `barConfigs[id=default].squareCorners`, `.gothCornersEnabled`, `.borderEnabled`, `.widgetOutlineEnabled`, `.shadowIntensity` | `false`, `false`, `false`, `false`, `0` — rounded corners (via the global `cornerRadius`), no borders or outlines, no shadow. |

### Spec keys that do not exist in DMS 1.6.2

- No standalone bar widget for the audio visualizer: it is a mode of the
  `music` widget, gated by `audioVisualizerEnabled` and `cava` being
  installed (`packages/pacman.txt` already lists `cava` per
  `docs/desktop-migration.md` phase 2). There is no `audioVisualizer` widget
  id in `barConfigs`.
- No individual bar widgets for volume, brightness, bluetooth, wifi, or
  power-profile the way Noctalia's `bar.dotfiles` capsule groups had them;
  see the `rightWidgets` row above.

## matugen templates: Niri backdrop and the Z13 rear-window color

DMS drives [matugen](https://github.com/InioX/matugen) from the active
wallpaper. With `runUserMatugenTemplates` on (it is, see the table above),
DMS also merges in the user's own `~/.config/matugen/config.toml`, extracting
its `[config]` section and everything from `[templates]` onward and appending
them to the config it builds for the real (non-dry-run) matugen invocation.

`chezmoi/dot_config/matugen/config.toml` declares two user templates,
`niri_backdrop` and `z13_window`.

### Niri backdrop

Niri draws its backdrop, a plain grey by default, wherever the layout
background is transparent, and `background-color "transparent"` is what both
`chezmoi/dot_config/niri/cfg/layout.kdl` and the DMS-written
`~/.config/niri/dms/colors.kdl` set. That grey is visible for a moment at
login before the DMS wallpaper layer appears. The `niri_backdrop` template
renders the Material surface color into a Niri `overview { backdrop-color }`
include, so the backdrop follows the wallpaper theme instead:

```toml
[templates.niri_backdrop]
input_path = "~/.config/matugen/templates/niri-backdrop"
output_path = "~/.config/niri/matugen/backdrop.kdl"
```

The input, `chezmoi/dot_config/matugen/templates/niri-backdrop`, is:

```
overview {
    backdrop-color "{{colors.surface.default.hex}}"
}
```

`chezmoi/dot_config/niri/config.kdl` includes the rendered output as
`include optional=true "matugen/backdrop.kdl"`, after the two `dms/`
includes. It is optional so `niri validate` and a fresh machine (before the
first matugen render) both work without the file. The output directory,
`~/.config/niri/matugen/`, is created by chezmoi from a `.keep` placeholder in
the source tree (`chezmoi/dot_config/niri/matugen/.keep`, ignored via
`chezmoi/.chezmoiignore` like `dot_config/niri/.keep`); chezmoi still creates
the directory even though the placeholder itself is not deployed.
`backdrop.kdl` itself is not chezmoi-managed — it is generated by matugen.

Because the file is written to disk before Niri starts, the first frame
already shows the theme color instead of the default grey, and Niri reloads
the include live on every theme change, same as the `dms/` includes above.

### Z13 rear-window color

`chezmoi/dot_config/matugen/config.toml` also declares `z13_window`:

```toml
[config]

[templates]

[templates.z13_window]
input_path = "~/.config/matugen/templates/z13-window-color"
output_path = "~/.cache/matugen/z13-window-color"
post_hook = "~/.local/bin/sync-z13-window-color '{{ colors.primary.default.hex_stripped }}'"
```

The input,
`chezmoi/dot_config/matugen/templates/z13-window-color`, is a single line,
`{{colors.primary.default.hex_stripped}}`; matugen renders it to the cache
path above and then runs the post hook with the rendered value, calling
`~/.local/bin/sync-z13-window-color` (`chezmoi/dot_local/bin/executable_sync-z13-window-color`)
with the stripped hex color. The helper checks the Z13 DMI identifiers itself
and is a no-op on other hardware; see (the former) ADR-0004, now superseded
by ADR-0013, decision 4. This replaces the Noctalia `niri` and
`z13_window` user templates from `templates.toml`, preserved in the
`noctalia-final` tag.

### Triggering a re-render

Both templates render together on every real matugen invocation. Any
wallpaper or theme change re-renders them. Trigger one explicitly with:

```fish
dms ipc call wallpaper set ~/Pictures/wallpaper.jpg
```

or by switching the DMS theme mode from the Control Center. Then verify the
output files:

```fish
cat ~/.config/niri/matugen/backdrop.kdl
cat ~/.cache/matugen/z13-window-color
```

On a detected 2025 Z13 the rear lightbar should update to that color within a
moment; on other hardware `sync-z13-window-color` exits without effect, and
the cache file still updates.

## Iterating on the look

Edit `dms/look.json`, run `./scripts/dms-apply-look.sh --dry-run` to review
the diff, then `./scripts/dms-apply-look.sh` to apply it — DMS restarts as
part of that script. See "The mat-glass look" above for the key-by-key
reference.

## Restarting the shell

```fish
dms-reset
```

The Fish function restarts `dms.service` and prints its status. Equivalent
to, but preferred over, `systemctl --user restart dms.service` directly.

## Reloading a plugin after editing

```fish
dms ipc call plugins reload dotfilesApps
```

Replace `dotfilesApps` with the plugin id (`dotfilesLauncher`,
`dotfilesWorkspaces`, `dotfilesApps`, or `dotfilesDashboard`). DMS
cache-busts only the manifest's `component` file on a reload. After editing
one of a plugin's other QML files (for example `AppIconDelegate.qml` or
`NotificationMatcher.qml`), the first reload still uses the cached helper and
can fail with a `component error` — run the same reload a second time.
`dotfilesDashboard`'s reload only re-reads its manifest component too; edits
to its other QML files need a full restart instead:

```fish
dms-reset
```

## Idle, lock, and suspend

`dms/look.json` sets DMS's own idle timeouts (milliseconds), split by power
source:

- On AC power: lock after 10 minutes (`acLockTimeout`, `600` seconds), never
  suspend (`acSuspendTimeout`, `0`).
- On battery: lock after 5 minutes (`batteryLockTimeout`, `300` seconds),
  suspend after 15 minutes (`batterySuspendTimeout`, `900` seconds).

These use DMS's built-in idle and lock handling. DMS's own lock screen stays;
a repository-owned locker was considered and dropped, see
[ADR-0015](adr/ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md).
The login screen, which shares DMS's look through `dms-greeter`, is documented
in [docs/greeter.md](greeter.md).

## Known limits

- The bar container's own look (surface shape beyond `cornerRadius`,
  built-in widget chrome) is DMS's; only plugins and the settings in
  `dms/look.json` are repository-owned.
- The lock screen is DMS's own built-in one, not a repository-owned
  Quickshell surface. That is a final decision, not a pending phase; see
  [ADR-0015](adr/ADR-0015-use-the-dms-greeter-under-greetd-and-keep-the-dms-lock-screen.md).
- Do not run `dms setup` or `dms sync`: both write into the live Niri
  configuration (`~/.config/niri/`), which conflicts with the
  chezmoi-managed source tree.
