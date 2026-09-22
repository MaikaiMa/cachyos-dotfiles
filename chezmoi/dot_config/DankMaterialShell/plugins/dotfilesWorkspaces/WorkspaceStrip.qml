import QtQuick
import Quickshell
import qs.Common

Item {
    id: strip

    property var controller: null
    property bool vertical: false
    property int hoveredIndex: -1

    // Scroll accumulation mirrors DMS's built-in WorkspaceSwitcher so both widgets feel alike.
    readonly property real touchpadThreshold: 500
    readonly property real mouseThreshold: 120
    readonly property int scrollCooldownMs: 100

    property real touchpadAccumulator: 0
    property real mouseAccumulator: 0
    property bool scrollInProgress: false

    implicitWidth: pillFlow.implicitWidth
    implicitHeight: pillFlow.implicitHeight

    function pillIndexNear(x, y) {
        const local = strip.mapToItem(pillFlow, x, y);
        const position = strip.vertical ? local.y : local.x;

        let bestIndex = -1;
        let bestDistance = Infinity;
        for (let i = 0; i < pillRepeater.count; i++) {
            const item = pillRepeater.itemAt(i);
            if (!item)
                continue;
            const center = strip.vertical ? (item.y + item.height / 2) : (item.x + item.width / 2);
            const distance = Math.abs(position - center);
            if (distance < bestDistance) {
                bestDistance = distance;
                bestIndex = i;
            }
        }
        return bestIndex;
    }

    function scrollBy(delta, isTouchpad) {
        if (strip.scrollInProgress)
            return;

        const reverse = SettingsData.reverseScrolling ? -1 : 1;
        if (isTouchpad) {
            strip.touchpadAccumulator += delta;
            if (Math.abs(strip.touchpadAccumulator) < strip.touchpadThreshold)
                return;
            strip.controller?.cycleWorkspace(strip.touchpadAccumulator * reverse < 0 ? 1 : -1);
            strip.touchpadAccumulator = 0;
        } else {
            strip.mouseAccumulator += delta;
            if (Math.abs(strip.mouseAccumulator) < strip.mouseThreshold)
                return;
            strip.controller?.cycleWorkspace(strip.mouseAccumulator * reverse < 0 ? 1 : -1);
            strip.mouseAccumulator = 0;
        }

        strip.scrollInProgress = true;
        scrollCooldown.restart();
    }

    Timer {
        id: scrollCooldown

        interval: strip.scrollCooldownMs
        onTriggered: strip.scrollInProgress = false
    }

    Flow {
        id: pillFlow

        anchors.centerIn: parent
        spacing: Theme.spacingS
        flow: strip.vertical ? Flow.TopToBottom : Flow.LeftToRight

        Repeater {
            id: pillRepeater

            model: ScriptModel {
                values: strip.controller?.workspaceList ?? []
                objectProp: "id"
            }

            delegate: WorkspacePill {
                required property var modelData
                required property int index

                controller: strip.controller
                vertical: strip.vertical
                workspace: modelData
                label: strip.controller?.labelFor(modelData, strip.vertical) ?? ""
                isActive: modelData?.is_active ?? false
                isOccupied: strip.controller?.occupiedWorkspaceIds.has(modelData?.id) ?? false
                isUrgent: strip.controller?.urgentWorkspaceIds.has(modelData?.id) ?? false
                hasNotification: strip.controller?.notifiedWorkspaceIds.has(modelData?.id) ?? false
                isHovered: strip.hoveredIndex === index
            }
        }
    }

    MouseArea {
        id: interaction

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton

        onPositionChanged: mouse => strip.hoveredIndex = strip.pillIndexNear(mouse.x, mouse.y)
        onExited: strip.hoveredIndex = -1

        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                strip.controller?.toggleOverview();
                return;
            }

            const index = strip.pillIndexNear(mouse.x, mouse.y);
            const list = strip.controller?.workspaceList ?? [];
            if (index >= 0 && index < list.length)
                strip.controller.activateWorkspace(list[index]);
        }

        onWheel: wheel => {
            if (Math.abs(wheel.angleDelta.x) > Math.abs(wheel.angleDelta.y)) {
                wheel.accepted = false;
                return;
            }
            strip.scrollBy(wheel.angleDelta.y, wheel.pixelDelta && wheel.pixelDelta.y !== 0);
        }
    }
}
