# dotfilesApps

A DankMaterialShell bar widget that shows the applications on the current workspace as
icons, like the built-in `runningApps` widget, plus two indicators:

- a small dot in the theme primary colour, centred under the icon, when the app
  has at least one open window (full opacity when the app is focused, dimmed
  otherwise);
- a small dot in the theme error colour (red) at the top right of the icon when
  the notification centre holds at least one notification from that app.

Apps are grouped per application id. Pinned apps that are not running are shown
dimmed and without the window dot.

## Interaction

| Input | Action |
| --- | --- |
| Left click, no windows | Launch the app from its desktop entry |
| Left click, one window | Focus, or minimise when already focused |
| Left click, multiple windows | Cycle to the next window of that app |
| Middle click | Close the active window of that app |
| Right click | Context menu: Minimise/Restore, Close, Pin/Unpin |
| Hover | Tooltip with app name, window title or window count |

## Adding it to the bar

The plugin directory must be reachable as
`~/.config/DankMaterialShell/plugins/dotfilesApps`, then:

```fish
dms ipc call plugins enable dotfilesApps
```

The widget id is `dotfilesApps`. Add it to a bar section in
Settings → DankBar → Widgets, or add the string `"dotfilesApps"` to
`barConfigs[<n>].leftWidgets` in `~/.config/DankMaterialShell/settings.json`.
The `settings set` IPC call refuses arrays, so the widget list cannot be
changed from the command line.

## Reloading during development

```fish
dms ipc call plugins reload dotfilesApps
```

DMS cache-busts only the manifest's `component` file. After editing one of the
helper files (`AppIconDelegate.qml`, `StatusDot.qml`, `NotificationMatcher.qml`,
`AppContextMenu.qml`) the first reload still uses the cached helper and can fail
with a `component error`; run the reload a second time.

## Settings

Settings → Plugins → Dotfiles Apps:

- **Show pinned apps** — also show `SessionData.pinnedApps` entries that are not
  running (default on).
- **Notification badge** — show the red dot (default on).
- **Current workspace only** / **Current monitor only** — filter the window list
  the same way the built-in widget does (both default off).

## Notification matching

`NotificationMatcher.qml` reads `NotificationService.groupedNotifications`, the
notification-centre list, not the popup list. For every group it collects the
desktop entry, the group key and the app name; for every icon it collects the
app id and the resolved app name. Every value produces two lookup keys: the
whole value lowercased with non-alphanumerics removed, and the same treatment
applied to the part after the last dot, so `org.gnome.Nautilus` also matches
`nautilus`. A `.desktop` suffix is stripped first. An icon is badged when any of
its keys matches any notification key.

## DMS dependencies

- `CompositorService` — `sortedToplevels`, workspace/monitor filters,
  `activateToplevel`, `toggleToplevel`, `canMinimize`, `supportsMinimize`
- `NotificationService` — `groupedNotifications`
- `SessionData` — `pinnedApps`, `setPinnedApps`
- `SessionService` — `launchDesktopEntry`
- `AppUsageHistoryData` — `addAppUsage`
- `Paths` — `moddedAppId`, `getAppIcon`, `getAppName`, `isSteamApp`
- `SettingsData` — `appIdSubstitutionsChanged`
- `Theme`, `BlurService`, `I18n`, `DankIcon`, `DankTooltip`, `StyledText`
- Quickshell `DesktopEntries`, `IconImage`, `ScriptModel`, `PanelWindow`

Requires DMS >= 1.6.0 for the plugin API used here.

## Known limits

- The window count is not drawn on the icon; the built-in widget's numeric
  badge is replaced by the single window dot. The count is in the tooltip.
- Pin/Unpin writes the same `SessionData.pinnedApps` list the dock uses, so
  pinning here also changes the dock.
- The context menu acts on the active window of an app, not on every window of
  the group.
- Notification matching is name based. Two apps whose ids collapse to the same
  key (for example after stripping a reverse-DNS prefix) share a badge.
- The red dot tracks the notification centre, so it stays until the
  notification is dismissed or cleared there, not when its popup times out.
