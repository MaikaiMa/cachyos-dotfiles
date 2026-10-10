pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Power state of the centre island: one row of five square buttons. The
// first takes the keyboard on open, Left and Right move it, Enter or Space
// activate; the focused button is drawn in the accent.
Panel {
    id: panel

    name: "power"

    readonly property var buttons: [
        {
            action: "lock",
            icon: "lock",
            text: "Lock"
        },
        {
            action: "suspend",
            icon: "bedtime",
            text: "Suspend"
        },
        {
            action: "logout",
            icon: "logout",
            text: "Log out"
        },
        {
            action: "reboot",
            icon: "restart_alt",
            text: "Reboot"
        },
        {
            action: "poweroff",
            icon: "power_settings_new",
            text: "Power off"
        }
    ]
    property int focusIndex: 0

    implicitHeight: Theme.powerPanelHeight

    // After the window has taken the keys back on the state change.
    onOpened: {
        focusIndex = 0;
        Qt.callLater(panel.focusButton, 0);
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

            Pressable {
                id: button

                required property var modelData
                required property int index

                readonly property bool current: panel.focusIndex === index

                objectName: "power_" + modelData.action
                width: Theme.powerButtonSize
                height: Theme.powerButtonSize
                accessibleName: modelData.text

                onActiveFocusChanged: {
                    if (activeFocus)
                        panel.focusIndex = index;
                }
                onActivated: {
                    panel.focusIndex = button.index;
                    Session.perform(button.modelData.action);
                }

                Keys.onLeftPressed: event => button.step(event, -1)
                Keys.onRightPressed: event => button.step(event, 1)

                function step(event: var, direction: int) {
                    if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier)) {
                        event.accepted = false;
                        return;
                    }
                    panel.focusButton(button.index + direction);
                }

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.tileRadius
                    color: button.current ? Colors.primary : button.hovered ? Colors.hoverSurface : Colors.surfaceContainerHigh
                    scale: button.pressed ? Theme.pressedScale : 1

                    Behavior on color {
                        ColorCrossfade {}
                    }

                    Behavior on scale {
                        Crossfade {}
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

                        Label {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: button.modelData.text
                            secondary: true
                            color: button.current ? Colors.primaryForeground : Colors.foreground
                        }
                    }
                }
            }
        }
    }
}
