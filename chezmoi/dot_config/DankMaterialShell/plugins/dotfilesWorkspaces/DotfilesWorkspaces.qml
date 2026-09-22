import QtQuick
import qs.Common
import qs.Modules.Plugins
import qs.Services

PluginComponent {
    id: root

    readonly property bool notificationHighlightEnabled: pluginData.notificationHighlightEnabled ?? true
    readonly property bool overviewOnRightClick: pluginData.overviewOnRightClick ?? true

    readonly property string outputName: parentScreen?.name ?? ""
    readonly property real pillIconSize: Theme.barIconSize(barThickness, -6, barConfig?.maximizeWidgetIcons, barConfig?.iconScale)
    readonly property real pillTextSize: Theme.barTextSize(barThickness, barConfig?.fontScale, barConfig?.maximizeWidgetText)

    readonly property var occupiedWorkspaceIds: {
        const ids = new Set();
        for (const window of (NiriService.windows || [])) {
            if (window?.workspace_id !== undefined)
                ids.add(window.workspace_id);
        }
        return ids;
    }

    readonly property var urgentWorkspaceIds: {
        const ids = new Set();
        for (const window of (NiriService.windows || [])) {
            if (window?.is_urgent && window.workspace_id !== undefined)
                ids.add(window.workspace_id);
        }
        return ids;
    }

    readonly property var notifiedWorkspaceIds: {
        const ids = new Set();
        if (!root.notificationHighlightEnabled)
            return ids;

        for (const window of (NiriService.windows || [])) {
            if (!window || window.workspace_id === undefined || ids.has(window.workspace_id))
                continue;
            if (notificationMatcher.matchesApp(window.app_id, ""))
                ids.add(window.workspace_id);
        }
        return ids;
    }

    readonly property var workspaceList: {
        const all = NiriService.allWorkspaces || [];
        if (all.length === 0)
            return [];

        const source = root.outputName ? all.filter(ws => ws.output === root.outputName) : all;
        const ordered = source.slice().sort((a, b) => a.idx - b.idx);

        if (!SettingsData.showOccupiedWorkspacesOnly)
            return ordered;

        return ordered.filter(ws => ws.is_active || root.occupiedWorkspaceIds.has(ws.id));
    }

    function colorFromMode(mode, fallbackColor, customColor, customFallbackColor) {
        switch (mode) {
        case "primary":
        case "pri":
            return Theme.primary;
        case "primaryContainer":
            return Theme.primaryContainer;
        case "secondary":
        case "sec":
            return Theme.secondary;
        case "secondaryContainer":
            return Theme.secondaryContainer;
        case "tertiary":
        case "ter":
            return Theme.tertiary;
        case "tertiaryContainer":
            return Theme.tertiaryContainer;
        case "surfaceText":
            return Theme.surfaceText;
        case "s":
            return Theme.surface;
        case "sc":
            return Theme.surfaceContainer;
        case "sch":
            return Theme.surfaceContainerHigh;
        case "schh":
            return Theme.surfaceContainerHighest;
        case "error":
        case "err":
            return Theme.error;
        case "custom":
            return Theme.safeColor(customColor, customFallbackColor);
        default:
            return fallbackColor;
        }
    }

    readonly property color idlePillColor: colorFromMode(SettingsData.workspaceUnfocusedColorMode, Theme.surfaceTextAlpha, SettingsData.workspaceUnfocusedCustomColor, Theme.surfaceTextAlpha)

    readonly property color focusedPillColor: {
        const mode = SettingsData.workspaceColorMode;
        if (mode === "none")
            return root.idlePillColor;
        return colorFromMode(mode, Theme.primary, SettingsData.workspaceFocusedCustomColor, Theme.primary);
    }

    readonly property color occupiedPillColor: {
        const mode = SettingsData.workspaceOccupiedColorMode;
        if (mode === "none")
            return root.idlePillColor;
        return colorFromMode(mode, root.idlePillColor, SettingsData.workspaceOccupiedCustomColor, Theme.secondary);
    }

    readonly property color alertPillColor: colorFromMode(SettingsData.workspaceUrgentColorMode, Theme.error, SettingsData.workspaceUrgentCustomColor, Theme.error)

    function labelFor(workspace, vertical) {
        let name = SettingsData.showWorkspaceName ? (workspace?.name ?? "") : "";
        if (name && vertical)
            name = name.charAt(0);

        const index = (workspace?.idx !== undefined && workspace.idx !== -1) ? workspace.idx : "";
        if (name)
            return (SettingsData.showWorkspaceIndex && index !== "") ? `${index}: ${name}` : name;
        return index;
    }

    function activateWorkspace(workspace) {
        if (workspace?.id !== undefined)
            NiriService.switchToWorkspace(workspace.id);
    }

    function cycleWorkspace(direction) {
        const list = root.workspaceList;
        if (list.length < 2)
            return;

        const activeIndex = list.findIndex(ws => ws.is_active);
        const fromIndex = activeIndex === -1 ? 0 : activeIndex;
        const toIndex = direction > 0 ? Math.min(fromIndex + 1, list.length - 1) : Math.max(fromIndex - 1, 0);
        if (toIndex !== fromIndex)
            root.activateWorkspace(list[toIndex]);
    }

    function toggleOverview() {
        if (root.overviewOnRightClick)
            NiriService.toggleOverview();
    }

    visible: CompositorService.isNiri && workspaceList.length > 0

    NotificationMatcher {
        id: notificationMatcher
    }

    horizontalBarPill: Component {
        WorkspaceStrip {
            controller: root
            vertical: false
        }
    }

    verticalBarPill: Component {
        WorkspaceStrip {
            controller: root
            vertical: true
        }
    }
}
