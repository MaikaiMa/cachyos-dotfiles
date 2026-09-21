# dotfilesLauncher

A DankMaterialShell bar widget: the built-in apps-grid launcher icon on a filled `Theme.primary` pill instead of the default neutral widget background, in `Theme.primaryText` with a `Theme.hoverTint` hover state.
Drop-in replacement for the built-in `launcherButton` widget id in `barConfigs[<n>].leftWidgets`; same left-click behaviour (opens the app drawer) and right-click behaviour (toggles the Niri overview).
Uses `PopoutService.toggleAppDrawer`, `CompositorService.isNiri` / `getScreenScale`, `NiriService.toggleOverview`, and `Theme` (`primary`, `primaryText`, `hoverTint`, `cornerRadius`, `barIconSize`, `snap`).
