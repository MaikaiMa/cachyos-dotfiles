pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Power state of the centre island: one row of five square buttons. The
// first takes the keyboard on open, Left and Right move it, Enter or Space
// activate; the focused button is drawn in the accent.
Item {
    id: panel

    property bool shown: false

    readonly property var buttons: [
        {
            action: "lock",
            icon: "lock",
            label: "Lock"
        },
        {
            action: "suspend",
            icon: "bedtime",
            label: "Suspend"
        },
        {
            action: "logout",
            icon: "logout",
            label: "Log out"
        },
        {
            action: "reboot",
            icon: "restart_alt",
            label: "Reboot"
        },
        {
            action: "poweroff",
            icon: "power_settings_new",
            label: "Power off"
        }
    ]
    property int focusIndex: 0

    implicitWidth: Theme.panelWidths.power
    implicitHeight: Theme.powerPanelHeight

    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    // After the window has taken the keys back on the state change.
    onShownChanged: {
        if (shown) {
            focusIndex = 0;
            Qt.callLater(panel.focusButton, 0);
        }
    }

    function focusButton(index: int) {
        focusIndex = Math.max(0, Math.min(buttons.length - 1, index));
        const button = buttonRepeater.itemAt(focusIndex);
        if (button && panel.shown)
            button.forceActiveFocus();
    }

    Row {
        x: Theme.powerPanelPadding
        y: Theme.powerPanelPadding
        spacing: Theme.gap

        Repeater {
            id: buttonRepeater

            model: panel.buttons

            Item {
                id: button

                required property var modelData
                required property int index

                readonly property bool current: panel.focusIndex === index

                objectName: "power_" + modelData.action
                width: Theme.powerButtonSize
                height: Theme.powerButtonSize
                activeFocusOnTab: true

                Accessible.role: Accessible.Button
                Accessible.name: modelData.label
                Accessible.onPressAction: Session.perform(button.modelData.action)

                onActiveFocusChanged: {
                    if (activeFocus)
                        panel.focusIndex = index;
                }

                Keys.onPressed: event => {
                    if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier))
                        return;
                    if (event.key === Qt.Key_Left)
                        panel.focusButton(button.index - 1);
                    else if (event.key === Qt.Key_Right)
                        panel.focusButton(button.index + 1);
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)
                        Session.perform(button.modelData.action);
                    else
                        return;
                    event.accepted = true;
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.tileRadius
                    color: button.current ? Colors.primary : pointer.containsMouse ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.18)) : Colors.surfaceContainerHigh
                    scale: pointer.pressed ? 0.97 : 1

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.crossfadeDuration
                            easing.type: Motion.crossfadeEasing
                        }
                    }

                    Behavior on scale {
                        NumberAnimation {
                            duration: Motion.crossfadeDuration
                            easing.type: Motion.crossfadeEasing
                        }
                    }

                    Column {
                        anchors.centerIn: parent
                        spacing: Theme.powerButtonLabelGap

                        Icon {
                            anchors.horizontalCenter: parent.horizontalCenter
                            name: button.modelData.icon
                            size: Theme.powerButtonIconSize
                            color: button.current ? Colors.primaryForeground : Colors.foreground
                        }

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: button.modelData.label
                            color: button.current ? Colors.primaryForeground : Colors.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.secondaryFontSize
                            font.weight: Theme.fontWeight
                        }
                    }
                }

                MouseArea {
                    id: pointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        panel.focusIndex = button.index;
                        Session.perform(button.modelData.action);
                    }
                }
            }
        }
    }
}
