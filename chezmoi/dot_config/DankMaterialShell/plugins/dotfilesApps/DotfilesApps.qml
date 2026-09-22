import QtQuick
import Quickshell
import qs.Common
import qs.Modules.Plugins
import qs.Services
import qs.Widgets

PluginComponent {
    id: root

    readonly property bool showPinnedApps: pluginData.showPinnedApps ?? false
    readonly property bool currentWorkspaceOnly: pluginData.currentWorkspaceOnly ?? true
    readonly property bool currentMonitorOnly: pluginData.currentMonitorOnly ?? false
    readonly property bool notificationBadgeEnabled: pluginData.notificationBadgeEnabled ?? true
    readonly property bool dismissOnFocus: pluginData.dismissOnFocus ?? true
    readonly property int dismissOnFocusDelayMs: 1500

    // CompositorService keeps the same sortedToplevels array when the new contents are
    // equivalent, so a window title or focus change never invalidates a binding on it;
    // this counter is what makes the list below follow those changes.
    property int toplevelsRevision: 0

    property int desktopEntriesRevision: 0

    readonly property real cellWidth: iconSize + Theme.spacingS
    readonly property real cellHeight: Math.min(cellWidth, widgetThickness)

    readonly property var visibleToplevels: {
        root.toplevelsRevision;
        let toplevels = CompositorService.sortedToplevels;
        if (!toplevels || toplevels.length === 0)
            return [];
        if (root.currentWorkspaceOnly)
            toplevels = CompositorService.filterCurrentWorkspace(toplevels, root.parentScreen?.name) || [];
        if (root.currentMonitorOnly)
            toplevels = CompositorService.filterCurrentDisplay(toplevels, root.parentScreen?.name) || [];
        return toplevels;
    }

    readonly property var appEntries: {
        const entries = new Map();

        if (root.showPinnedApps) {
            for (const rawAppId of (SessionData.pinnedApps || [])) {
                const appId = Paths.moddedAppId(rawAppId);
                if (!appId || entries.has(appId))
                    continue;
                entries.set(appId, {
                    "appId": appId,
                    "pinned": true,
                    "windows": []
                });
            }
        }

        for (const toplevel of root.visibleToplevels) {
            if (!toplevel)
                continue;
            const appId = Paths.moddedAppId(toplevel.appId || "unknown");
            if (!entries.has(appId)) {
                entries.set(appId, {
                    "appId": appId,
                    "pinned": false,
                    "windows": []
                });
            }
            entries.get(appId).windows.push(toplevel);
        }

        return Array.from(entries.values());
    }

    readonly property string focusedAppId: {
        for (const toplevel of root.visibleToplevels) {
            if (toplevel?.activated)
                return Paths.moddedAppId(toplevel.appId || "");
        }
        return "";
    }

    function dismissNotificationsForFocusedApp() {
        if (!root.dismissOnFocus || root.focusedAppId === "")
            return;

        const desktopEntry = DesktopEntries.heuristicLookup(root.focusedAppId);
        const appName = Paths.getAppName(root.focusedAppId, desktopEntry);
        for (const groupKey of matcher.groupKeysForApp(root.focusedAppId, appName))
            NotificationService.dismissGroup(groupKey);
    }

    function activateEntry(entry) {
        const windows = entry?.windows ?? [];
        if (windows.length === 0) {
            launchEntry(entry);
            return;
        }
        if (windows.length === 1) {
            CompositorService.toggleToplevel(windows[0]);
            return;
        }

        let activeIndex = -1;
        for (let i = 0; i < windows.length; i++) {
            if (windows[i]?.activated) {
                activeIndex = i;
                break;
            }
        }
        CompositorService.activateToplevel(windows[(activeIndex + 1) % windows.length]);
    }

    function launchEntry(entry) {
        const desktopEntry = entry?.appId ? DesktopEntries.heuristicLookup(entry.appId) : null;
        if (!desktopEntry)
            return;

        AppUsageHistoryData.addAppUsage({
            "id": entry.appId,
            "name": desktopEntry.name || entry.appId,
            "icon": desktopEntry.icon ? String(desktopEntry.icon) : "",
            "exec": desktopEntry.execString || "",
            "comment": desktopEntry.comment || ""
        });
        SessionService.launchDesktopEntry(desktopEntry);
    }

    function closeEntry(entry) {
        const windows = entry?.windows ?? [];
        for (const toplevel of windows) {
            if (toplevel?.activated) {
                toplevel.close();
                return;
            }
        }
        if (windows.length > 0)
            windows[0].close();
    }

    function showContextMenu(entry, anchorX, anchorY) {
        hideTooltip();
        contextMenuLoader.active = true;
        if (!contextMenuLoader.item)
            return;

        contextMenuLoader.item.entry = entry;
        contextMenuLoader.item.barEdge = root.axis?.edge ?? "top";
        contextMenuLoader.item.barThickness = root.barThickness;
        contextMenuLoader.item.barSpacing = root.barSpacing;
        contextMenuLoader.item.showAt(root.parentScreen, anchorX, anchorY);
    }

    function showTooltip(text, anchorX, anchorY) {
        if (!tooltipLoader.item)
            return;

        const edge = root.axis?.edge ?? "top";
        const offset = root.barThickness + root.barSpacing + Theme.spacingXS;
        if (root.isVertical) {
            const isLeftBar = edge === "left";
            const tooltipX = isLeftBar ? offset : ((root.parentScreen?.width ?? Screen.width) - offset);
            tooltipLoader.item.show(text, tooltipX, anchorY, root.parentScreen, isLeftBar, !isLeftBar);
            return;
        }

        const screenHeight = root.parentScreen?.height ?? Screen.height;
        const tooltipY = edge === "bottom" ? (screenHeight - offset - 35) : offset;
        tooltipLoader.item.show(text, anchorX, tooltipY, root.parentScreen, false, false);
    }

    function hideTooltip() {
        tooltipLoader.item?.hide();
    }

    visible: appEntries.length > 0

    function scheduleDismissForFocusedApp() {
        dismissOnFocusTimer.stop();
        if (dismissOnFocus && focusedAppId !== "")
            dismissOnFocusTimer.start();
    }

    onFocusedAppIdChanged: scheduleDismissForFocusedApp()

    Timer {
        id: dismissOnFocusTimer

        interval: root.dismissOnFocusDelayMs
        repeat: false
        onTriggered: root.dismissNotificationsForFocusedApp()
    }

    Connections {
        target: CompositorService

        function onToplevelsChanged() {
            root.toplevelsRevision++;
        }
    }

    Connections {
        target: DesktopEntries

        function onApplicationsChanged() {
            root.desktopEntriesRevision++;
        }
    }

    NotificationMatcher {
        id: matcher

        onNotifiedKeysChanged: root.scheduleDismissForFocusedApp()
    }

    Component {
        id: appIconDelegate

        AppIconDelegate {
            id: iconDelegate

            required property var modelData

            entry: modelData
            notificationMatcher: matcher
            notificationBadgeEnabled: root.notificationBadgeEnabled
            focused: root.focusedAppId !== "" && root.focusedAppId === modelData.appId
            iconPixelSize: root.iconSize
            cellWidth: root.cellWidth
            cellHeight: root.cellHeight
            desktopEntriesRevision: root.desktopEntriesRevision

            onActivated: root.activateEntry(modelData)
            onCloseRequested: root.closeEntry(modelData)
            onContextMenuRequested: (anchorX, anchorY) => root.showContextMenu(modelData, anchorX, anchorY)
            onHoverStarted: {
                const anchor = iconDelegate.mapToItem(null, iconDelegate.width / 2, iconDelegate.height / 2);
                root.showTooltip(iconDelegate.tooltipText, anchor.x, anchor.y);
            }
            onHoverEnded: root.hideTooltip()
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingXS

            Repeater {
                model: ScriptModel {
                    values: root.appEntries
                    objectProp: "appId"
                }
                delegate: appIconDelegate
            }
        }
    }

    verticalBarPill: Component {
        Column {
            spacing: Theme.spacingXS

            Repeater {
                model: ScriptModel {
                    values: root.appEntries
                    objectProp: "appId"
                }
                delegate: appIconDelegate
            }
        }
    }

    Loader {
        id: tooltipLoader

        active: true
        sourceComponent: tooltipComponent
    }

    Component {
        id: tooltipComponent

        DankTooltip {}
    }

    Loader {
        id: contextMenuLoader

        active: false
        sourceComponent: contextMenuComponent
    }

    Component {
        id: contextMenuComponent

        AppContextMenu {
            onMenuClosed: contextMenuLoader.active = false
        }
    }
}
