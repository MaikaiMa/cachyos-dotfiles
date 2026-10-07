import QtQuick
import ".."
import "../services"

// The top row of the panels opened from Settings: back to Settings, the on/off
// switch with a short state (Sound has no switch, only the state), and on the
// right a button that leaves the bar for a fuller tool (the DMS settings
// window), with an optional second one left of it (a terminal).
Item {
    id: row

    // False: no switch, the state follows the back button.
    property bool hasSwitch: true
    property string switchName: ""
    property bool checked: false
    property bool switchEnabled: true
    property string stateText: ""
    property string actionIcon: "open_in_new"
    property string actionLabel: ""

    // Empty: no second button.
    property string extraIcon: ""
    property string extraLabel: ""

    signal toggled
    // The buttons on the right; the panel decides where they go and closes itself.
    signal actionTriggered
    signal extraClicked

    implicitHeight: Theme.controlRowHeight

    ControlButton {
        id: backButton

        objectName: "backButton"
        anchors.verticalCenter: parent.verticalCenter
        iconName: "arrow_back"
        label: "Back to Settings"
        onActivated: Shell.back()
    }

    Item {
        id: toggle

        objectName: "switch"
        anchors.left: backButton.right
        anchors.leftMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        width: row.hasSwitch ? Theme.switchWidth : 0
        height: Theme.switchHeight
        visible: row.hasSwitch
        enabled: row.switchEnabled
        opacity: enabled ? 1 : 0.5
        activeFocusOnTab: true

        Accessible.role: Accessible.CheckBox
        Accessible.name: row.switchName
        Accessible.checkable: true
        Accessible.checked: row.checked
        Accessible.onToggleAction: row.toggled()
        Accessible.onPressAction: row.toggled()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                row.toggled();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: row.checked ? Colors.primary : Colors.surfaceContainerHigh

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }

            Rectangle {
                readonly property real inset: (parent.height - height) / 2

                x: row.checked ? parent.width - width - inset : inset
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.switchKnob
                height: width
                radius: width / 2
                color: row.checked ? Colors.primaryForeground : Colors.foregroundVariant

                Behavior on x {
                    NumberAnimation {
                        duration: Motion.crossfadeDuration
                        easing.type: Motion.crossfadeEasing
                    }
                }

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.crossfadeDuration
                        easing.type: Motion.crossfadeEasing
                    }
                }
            }

            FocusRing {
                visible: toggle.activeFocus
            }
        }

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
    }

    Text {
        id: stateLabel

        objectName: "stateLabel"
        anchors.left: row.hasSwitch ? toggle.right : backButton.right
        anchors.leftMargin: row.hasSwitch ? Theme.controlLabelGap : Theme.gap
        anchors.right: extraButton.visible ? extraButton.left : settingsButton.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        text: row.stateText
        elide: Text.ElideRight
        color: Colors.foregroundVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSize
        font.weight: Theme.fontWeight
    }

    // Declared before the settings button: Tab reaches it first.
    ControlButton {
        id: extraButton

        objectName: "extraButton"
        anchors.right: settingsButton.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        visible: row.extraIcon !== ""
        iconName: row.extraIcon
        label: row.extraLabel
        onActivated: row.extraClicked()
    }

    ControlButton {
        id: settingsButton

        objectName: "settingsButton"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconName: row.actionIcon
        label: row.actionLabel
        onActivated: row.actionTriggered()
    }

    component FocusRing: Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Colors.primary
    }

    component ControlButton: Item {
        id: button

        property string iconName: ""
        property string label: ""

        signal activated

        width: Theme.controlButtonSize
        height: Theme.controlButtonSize
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: button.activated()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                button.activated();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: pointer.containsMouse ? Qt.alpha(Colors.foreground, 0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                }
            }

            FocusRing {
                visible: button.activeFocus
            }
        }

        Icon {
            anchors.centerIn: parent
            name: button.iconName
            size: Theme.toggleIconSize
            color: Colors.foreground
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }
}
