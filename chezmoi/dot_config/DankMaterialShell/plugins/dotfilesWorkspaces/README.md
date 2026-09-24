# dotfilesWorkspaces

A DankMaterialShell bar widget that replaces the built-in `workspaceSwitcher` for
niri. It keeps the compact pill look of the built-in widget and adds one thing the
built-in cannot do: a workspace pill turns red when an application with a window on
that workspace has a notification waiting in the notification centre.

## What it does

- Rounded pills, one per niri workspace on the bar's own output, ordered by `idx`.
- The focused workspace gets the wide pill in the focused colour (`Theme.primary` by
  default), the others stay in the muted surface colour.
- A pill alerts when a window on that workspace belongs to an app that has a
  notification, or when niri marks a window on it urgent. An unfocused alerting pill
  is filled with the alert colour at 45% alpha, the focused one with the full alert
  colour, so it stays the widest and brightest pill in the strip. The alert colour is
  the shell's urgent workspace colour, `Theme.error` by default.
- Left click switches to the workspace, right click toggles the niri overview, and
  scrolling over the widget cycles through the workspaces (mouse wheel and touchpad,
  honouring `reverseScrolling`).
- A long press (press and hold, for example by touch) toggles the niri overview
  too. A long press never also switches workspace: Qt's `pressAndHold` suppresses
  the click on release. Holding the right button counts as a right click.
- No app icons inside the pills; this widget is deliberately compact.

## Settings honoured

From the shell's own settings (Settings -> DankBar -> Workspaces):

- `showOccupiedWorkspacesOnly`
- `showWorkspaceIndex` and `showWorkspaceName` (both off means empty pills)
- `workspaceColorMode`, `workspaceOccupiedColorMode`, `workspaceUnfocusedColorMode`,
  `workspaceUrgentColorMode` and their `custom` colour counterparts
- `reverseScrolling`

The plugin's own settings:

- `notificationHighlightEnabled` - the red notification pill (default on)
- `overviewOnRightClick` - toggle the niri overview on right click (default on)
- `overviewOnLongPress` - toggle the niri overview on a long press (default on).
  It is separate from `overviewOnRightClick` so a mouse user can turn off the
  right click without losing the touch gesture, and the other way round. With it
  off, a long press does nothing rather than switching workspace.

## Placing it in the bar

Replace `workspaceSwitcher` with `dotfilesWorkspaces` in the bar layout, for example
in `barConfigs[0].leftWidgets` of `~/.config/DankMaterialShell/settings.json`, or by
swapping the widgets in the DankBar settings UI.

## Services used

- `NiriService` - `allWorkspaces`, `windows`, `switchToWorkspace`, `toggleOverview`
- `CompositorService` - niri detection
- `NotificationService` - via `NotificationMatcher.qml`, which maps a notification
  group's key, app name and desktop entry onto a window's `app_id`
- `SettingsData` and `Theme` - the shared workspace settings and colours

`NotificationMatcher.qml` is a byte-identical copy of the one in `dotfilesApps` so it
can be pulled into a shared location later; do not edit one without the other.

## Translations

The settings strings go through `I18n.trFor("dotfilesWorkspaces", ...)`, and
`translations/nl.json` holds the Dutch catalogue. DMS reads the file that
matches `SessionData.locale` (Settings, Locale) and reloads it when the locale
changes; the English strings in the QML are the source and the fallback.

## Known limits

- niri only. On other compositors the widget hides itself.
- `workspaceFollowFocus`, workspace padding, drag reordering, workspace name icons
  and the separate unfocused-monitor appearance of the built-in widget are not
  implemented.
- Notification matching is name based: an app whose `app_id` does not resemble the
  notification's app name or desktop entry will not light up its workspace.
- Pill sizes follow the built-in formula with the app-icon size offset fixed at the
  default, so a non-default `workspaceAppIconSizeOffset` does not change them.

## Reloading during development

`dms ipc call plugins reload <id>` only re-reads the manifest component, so an edit
to any other file in this directory needs a shell restart:

```fish
systemctl --user restart dms.service
```

The `dms-reset` fish function does the same thing.
