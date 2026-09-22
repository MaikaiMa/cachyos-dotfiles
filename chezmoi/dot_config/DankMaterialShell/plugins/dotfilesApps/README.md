# dotfilesApps

A DankMaterialShell bar widget that shows the applications on the current workspace as
icons, like the built-in `runningApps` widget. The focused app is drawn at full
opacity on a primary-colour background, the others at 0.6. A small dot in the
theme error colour (red) sits at the top right of an icon while the notification
centre holds at least one notification from that app, and disappears again once
the app has been focused for a moment.

Apps are grouped per application id.

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

`dms ipc call plugins reload <id>` only re-reads the manifest component, so an edit
to any other file in this directory needs a shell restart:

```fish
systemctl --user restart dms.service
```

The `dms-reset` fish function does the same thing.

## Settings

Settings → Plugins → Dotfiles Apps:

- **Show pinned apps** — also show `SessionData.pinnedApps` entries that are not
  running (default on).
- **Notification badge** — show the red dot (default on).
- **Clear notifications on focus** — dismiss an app's notifications to the
  history after it stays focused for 1.5 seconds (default on).
- **Current workspace only** / **Current monitor only** — filter the window list
  the same way the built-in widget does.

## Notification matching

`NotificationMatcher.qml` reads `NotificationService.groupedNotifications`, the
notification-centre list, not the popup list. For every group it collects the
desktop entry, the group key and the app name; for every icon it collects the
app id and the resolved app name. Every value produces two lookup keys: the
whole value lowercased with non-alphanumerics removed, and the same treatment
applied to the part after the last dot, so `org.gnome.Nautilus` also matches
`nautilus`. A `.desktop` suffix is stripped first. An icon is badged when any of
its keys matches any notification key.

`NotificationMatcher.qml` is shared verbatim with the sibling plugin
`dotfilesWorkspaces`, which colours its workspace pill from the same data. The
two copies must stay identical; change this one and copy it over.

## Clearing notifications on focus

While **Clear notifications on focus** is on, `DotfilesApps.qml` restarts a
single-shot 1.5 s timer on two events: the focused app changes, and the set of
notified apps changes. Restarting is the whole debounce, so alt-tabbing past an app
clears nothing, and a notification that arrives while its app is already focused
still gets its own 1.5 s before it is cleared.

When the timer fires, `NotificationMatcher.groupKeysForApp()` resolves the app that
is focused at that moment to notification group keys, with the same normalisation
used for the badge, and each key goes to `NotificationService.dismissGroup()`.
Clicking an app's icon is covered by the same watcher, because the click changes the
focus.

`dismissGroup()` calls `dismiss()` on each notification in the group. DMS writes
a notification to the history the moment it arrives, and dropping a wrapper does
not call `removeFromHistory`, so a dismissed notification only leaves the
notification centre's active list — it stays in the centre's history tab.
Nothing is deleted.

## DMS dependencies

- `CompositorService` — `sortedToplevels`, workspace/monitor filters,
  `activateToplevel`, `toggleToplevel`, `canMinimize`, `supportsMinimize`
- `NotificationService` — `groupedNotifications`, `dismissGroup`
- `SessionData` — `pinnedApps`, `setPinnedApps`
- `SessionService` — `launchDesktopEntry`
- `AppUsageHistoryData` — `addAppUsage`
- `Paths` — `moddedAppId`, `getAppIcon`, `getAppName`, `isSteamApp`; `moddedAppId`
  reads `SettingsData.appIdSubstitutions`, so the icon list follows that setting
  without a watcher of its own
- `Theme`, `BlurService`, `I18n`, `DankIcon`, `DankTooltip`, `StyledText`
- Quickshell `DesktopEntries`, `IconImage`, `ScriptModel`, `PanelWindow`

Requires DMS >= 1.6.0 for the plugin API used here.

## Known limits

- The window count is not drawn on the icon; it is in the tooltip only.
- Clearing on focus is per bar instance, so on a multi-monitor setup every
  instance runs its own timer. `dismissGroup` on an already empty group is a
  no-op, so the repeats are harmless.
- Pin/Unpin writes the same `SessionData.pinnedApps` list the dock uses, so
  pinning here also changes the dock.
- The context menu acts on the active window of an app, not on every window of
  the group.
- Notification matching is name based. Two apps whose ids collapse to the same
  key (for example after stripping a reverse-DNS prefix) share a badge.
- The red dot tracks the notification centre, so it stays until the
  notification is dismissed or cleared there, not when its popup times out.
