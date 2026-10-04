pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Widgets
import ".."
import "../components"
import "../services"

// Workspaces of this screen's output as dots, then the apps of its active
// workspace. The owner fixes the left edge; the island grows to the right.
Island {
    id: island

    required property string screenName

    readonly property var workspaces: Niri.workspaces.filter(workspace => workspace.output === screenName)
    readonly property var activeWorkspace: workspaces.find(workspace => workspace.isActive) ?? null
    readonly property int activeIndex: activeWorkspace ? workspaces.indexOf(activeWorkspace) : -1
    readonly property int activeWorkspaceId: activeWorkspace ? activeWorkspace.id : -1

    readonly property int slotWidth: Theme.workspaceDot + 2 * Theme.workspaceDotPadding
    readonly property int pillsWidth: workspaces.length * slotWidth + (activeIndex >= 0 ? Theme.workspaceActiveDot - Theme.workspaceDot : 0)
    // The pills' own padding completes the island padding at both ends.
    readonly property int edge: Theme.paddingHorizontal - Theme.workspaceDotPadding
    readonly property real appsWidth: appsLayers.shownLayer ? appsLayers.shownLayer.targetWidth : 0

    function attention(workspace: var): bool {
        if (workspace.isUrgent)
            return true;
        return Niri.windowsOn(workspace.id).some(window => window.isUrgent || Notifications.hasRecentFor(window.appId));
    }

    function step(direction: int) {
        const next = workspaces[activeIndex + direction];
        if (next)
            Niri.focusWorkspace(next.id);
    }

    targetWidth: workspaces.length > 0 ? 2 * edge + pillsWidth + appsWidth : 0
    targetHeight: Theme.islandHeight
    morphDuration: Motion.workspaceSlideDuration
    morphCurve: Motion.growCurve
    visible: workspaces.length > 0

    // Accumulates wheel and touchpad deltas into one step at a time, as DMS's
    // workspace switcher does, so a touchpad flick does not run through them all.
    property real wheelAccumulated: 0

    WheelHandler {
        onWheel: event => {
            if (cooldown.running || Math.abs(event.angleDelta.x) > Math.abs(event.angleDelta.y))
                return;
            const threshold = event.pixelDelta.y !== 0 ? 500 : 120;
            island.wheelAccumulated += event.angleDelta.y;
            if (Math.abs(island.wheelAccumulated) < threshold)
                return;
            island.step(island.wheelAccumulated < 0 ? 1 : -1);
            island.wheelAccumulated = 0;
            cooldown.restart();
        }
    }

    Timer {
        id: cooldown

        interval: 100
    }

    Row {
        id: pills

        objectName: "pills"
        x: island.edge
        height: Theme.islandHeight

        Repeater {
            model: island.workspaces

            Item {
                id: slot

                required property var modelData
                required property int index

                readonly property bool active: index === island.activeIndex
                readonly property bool occupied: Niri.windowsOn(modelData.id).length > 0
                readonly property bool alerting: island.attention(modelData)

                objectName: "workspacePill"
                width: (active ? Theme.workspaceActiveDot : Theme.workspaceDot) + 2 * Theme.workspaceDotPadding
                height: Theme.islandHeight

                Behavior on width {
                    NumberAnimation {
                        duration: Motion.workspaceSlideDuration
                        easing.type: Easing.BezierSpline
                        easing.bezierCurve: Motion.growCurve
                    }
                }

                Rectangle {
                    x: Theme.workspaceDotPadding
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 2 * Theme.workspaceDotPadding
                    height: Theme.workspaceDot
                    radius: height / 2
                    color: slot.alerting ? Colors.error : pointer.containsMouse ? Colors.foreground : slot.occupied ? Qt.alpha(Colors.foregroundVariant, 0.75) : Qt.alpha(Colors.outline, 0.45)

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.crossfadeDuration
                            easing.type: Motion.crossfadeEasing
                        }
                    }
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    pressAndHoldInterval: Motion.longPressInterval
                    onPressAndHold: Niri.toggleOverview()
                    onClicked: Niri.focusWorkspace(slot.modelData.id)
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Workspace " + modelData.idx
            }
        }
    }

    // The filled dot slides over the row to the active slot.
    Rectangle {
        objectName: "activePill"
        visible: island.activeIndex >= 0
        x: pills.x + Theme.workspaceDotPadding + Math.max(0, island.activeIndex) * island.slotWidth
        y: (Theme.islandHeight - height) / 2
        width: Theme.workspaceActiveDot
        height: Theme.workspaceDot
        radius: height / 2
        color: island.activeWorkspace && island.attention(island.activeWorkspace) ? Colors.error : Colors.primary

        Behavior on x {
            NumberAnimation {
                duration: Motion.workspaceSlideDuration
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Motion.growCurve
            }
        }
    }

    // Two layers take turns: a workspace switch fills the hidden one and
    // cross-fades, so the old icons fade out where they were.
    Item {
        id: appsLayers

        property AppsLayer shownLayer: first

        function show(workspaceId: int) {
            if (shownLayer.workspaceId === workspaceId)
                return;
            const next = shownLayer === first ? second : first;
            next.workspaceId = workspaceId;
            shownLayer = next;
        }

        x: pills.x + island.pillsWidth
        width: island.appsWidth
        height: Theme.islandHeight
        clip: true

        Component.onCompleted: show(island.activeWorkspaceId)

        Connections {
            target: island

            function onActiveWorkspaceIdChanged() {
                appsLayers.show(island.activeWorkspaceId);
            }
        }

        AppsLayer {
            id: first

            shown: appsLayers.shownLayer === first
        }

        AppsLayer {
            id: second

            shown: appsLayers.shownLayer === second
        }
    }

    component AppsLayer: Item {
        id: layer

        property int workspaceId: -1
        property bool shown: false
        readonly property var windows: workspaceId >= 0 ? Niri.windowsOn(workspaceId) : []
        // The workspace's active window is the focused one while it has focus,
        // and still the right one on a screen without focus.
        readonly property int activeWindowId: {
            const workspace = Niri.workspaces.find(candidate => candidate.id === workspaceId);
            return workspace ? workspace.activeWindowId : -1;
        }
        readonly property int activeIndex: windows.findIndex(window => window.id === activeWindowId)
        readonly property real targetWidth: windows.length > 0 ? icons.implicitWidth : 0

        objectName: "appsLayer"
        width: icons.implicitWidth
        height: Theme.islandHeight
        opacity: shown ? 1 : 0
        visible: opacity > 0 && windows.length > 0
        enabled: shown

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        Row {
            id: icons

            height: Theme.islandHeight
            leftPadding: Theme.gap
            rightPadding: Theme.workspaceDotPadding
            spacing: Theme.gap

            Icon {
                objectName: "appsSeparator"
                anchors.verticalCenter: parent.verticalCenter
                name: "chevron_right"
                size: Theme.workspaceSeparatorSize
                color: Colors.foregroundVariant
            }

            Repeater {
                model: layer.windows

                IconImage {
                    id: appIcon

                    required property var modelData

                    objectName: "appIcon"
                    anchors.verticalCenter: parent.verticalCenter
                    implicitSize: Theme.iconSize
                    source: Niri.iconFor(modelData.appId)
                    opacity: modelData.id === layer.activeWindowId ? 1 : 0.5

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        pressAndHoldInterval: Motion.longPressInterval
                        onPressAndHold: Niri.toggleOverview()
                        onClicked: Niri.focusWindow(appIcon.modelData.id)
                    }

                    Accessible.role: Accessible.Button
                    Accessible.name: modelData.title || modelData.appId
                }
            }
        }

        // Under the active icon; it slides on a focus change and jumps while
        // the row is still fading in after a workspace switch.
        Rectangle {
            objectName: "focusDot"
            visible: layer.activeIndex >= 0
            x: Theme.gap + Theme.workspaceSeparatorSize + Theme.gap + Math.max(0, layer.activeIndex) * (Theme.iconSize + Theme.gap) + (Theme.iconSize - width) / 2
            y: (Theme.islandHeight + Theme.iconSize) / 2 + Theme.focusDotGap
            width: Theme.focusDot
            height: width
            radius: width / 2
            color: Colors.primary

            Behavior on x {
                enabled: layer.opacity === 1
                NumberAnimation {
                    duration: Motion.workspaceSlideDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.growCurve
                }
            }
        }
    }
}
