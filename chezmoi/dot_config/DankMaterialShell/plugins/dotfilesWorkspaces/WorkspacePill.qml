import QtQuick
import qs.Common
import qs.Widgets

Item {
    id: pill

    property var controller: null
    property var workspace: null
    property bool vertical: false
    property bool isActive: false
    property bool isOccupied: false
    property bool isUrgent: false
    property bool hasNotification: false
    property bool isHovered: false
    property string label: ""

    readonly property real thickness: controller?.widgetThickness ?? 30
    readonly property real glyphSize: controller?.pillIconSize ?? 16
    readonly property bool alerting: isUrgent || hasNotification

    readonly property real crossExtent: thickness * 0.5
    readonly property real labelExtent: labelText.visible ? ((vertical ? labelText.implicitHeight : labelText.implicitWidth) + Theme.spacingS) : 0
    readonly property real mainExtent: Math.max(isActive ? Math.max(thickness * 1.05, glyphSize * 1.6) : Math.max(thickness * 0.7, glyphSize * 1.2), labelExtent)

    readonly property color fillColor: {
        if (isActive)
            return controller?.focusedPillColor ?? Theme.primary;
        if (alerting)
            return controller?.alertPillColor ?? Theme.error;
        if (isHovered)
            return Theme.withAlpha(controller?.idlePillColor ?? Theme.surfaceTextAlpha, 0.7);
        if (isOccupied)
            return controller?.occupiedPillColor ?? Theme.surfaceTextAlpha;
        return controller?.idlePillColor ?? Theme.surfaceTextAlpha;
    }

    width: vertical ? thickness : mainExtent
    height: vertical ? mainExtent : thickness

    Behavior on width {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }
    }

    Behavior on height {
        NumberAnimation {
            duration: Theme.mediumDuration
            easing.type: Theme.emphasizedEasing
        }
    }

    Rectangle {
        id: pillBody

        anchors.centerIn: parent
        width: pill.vertical ? pill.crossExtent : pill.mainExtent
        height: pill.vertical ? pill.mainExtent : pill.crossExtent
        radius: Theme.cornerRadius
        color: pill.fillColor
        border.width: pill.alerting ? 2 : 0
        border.color: pill.alerting ? (pill.controller?.alertPillColor ?? Theme.error) : Theme.withAlpha(Theme.error, 0)

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on width {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        Behavior on height {
            NumberAnimation {
                duration: Theme.mediumDuration
                easing.type: Theme.emphasizedEasing
            }
        }

        StyledText {
            id: labelText

            anchors.centerIn: parent
            visible: SettingsData.showWorkspaceIndex || SettingsData.showWorkspaceName
            text: pill.label
            color: (pill.isActive || pill.alerting) ? Theme.withAlpha(Theme.surfaceContainer, 0.95) : Theme.surfaceTextMedium
            font.pixelSize: pill.controller?.pillTextSize ?? Theme.fontSizeSmall
            font.weight: pill.isActive ? Math.max(Theme.fontWeight, Font.DemiBold) : Theme.fontWeight
        }
    }
}
