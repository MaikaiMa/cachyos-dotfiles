import QtQuick
import ".."
import "../services"

// The top row of the panels opened from Settings: back to Settings, the on/off
// switch with a short state (Sound has no switch, only the state), and on the
// right a button that opens settingsTab in the DMS settings window and closes
// the panel, with an optional second one left of it (a terminal).
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
    // The DMS settings tab the right button opens.
    property string settingsTab: ""

    // Empty: no second button.
    property string extraIcon: ""
    property string extraLabel: ""

    signal toggled
    // The second button; the panel decides where it goes and closes itself.
    signal extraClicked

    // The settings window needs the keyboard, which the open panel holds.
    function openSettings() {
        Dms.openSettingsTab(settingsTab);
        Shell.close();
    }

    implicitHeight: Theme.controlRowHeight

    IconButton {
        id: backButton

        objectName: "backButton"
        anchors.verticalCenter: parent.verticalCenter
        iconName: "arrow_back"
        accessibleName: "Back to Settings"
        onActivated: Shell.back()
    }

    Pressable {
        id: toggle

        objectName: "switch"
        anchors.left: backButton.right
        anchors.leftMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        width: row.hasSwitch ? Theme.switchWidth : 0
        height: Theme.switchHeight
        visible: row.hasSwitch
        enabled: row.switchEnabled
        opacity: enabled ? 1 : Theme.disabledOpacity
        accessibleName: row.switchName
        onActivated: row.toggled()

        Accessible.role: Accessible.CheckBox
        Accessible.checkable: true
        Accessible.checked: row.checked
        Accessible.onToggleAction: row.toggled()

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: row.checked ? Colors.primary : Colors.surfaceContainerHigh

            Behavior on color {
                ColorCrossfade {}
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
                    Crossfade {}
                }

                Behavior on color {
                    ColorCrossfade {}
                }
            }

            FocusRing {
                visible: toggle.activeFocus
            }
        }

        // A larger target than the switch itself.
        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.switchHitExtension
            cursorShape: Qt.PointingHandCursor
            onClicked: row.toggled()
        }
    }

    Label {
        id: stateLabel

        objectName: "stateLabel"
        anchors.left: row.hasSwitch ? toggle.right : backButton.right
        anchors.leftMargin: row.hasSwitch ? Theme.controlLabelGap : Theme.gap
        anchors.right: extraButton.visible ? extraButton.left : settingsButton.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        text: row.stateText
        color: Colors.foregroundVariant
    }

    // Declared before the settings button: Tab reaches it first.
    IconButton {
        id: extraButton

        objectName: "extraButton"
        anchors.right: settingsButton.left
        anchors.rightMargin: Theme.gap
        anchors.verticalCenter: parent.verticalCenter
        visible: row.extraIcon !== ""
        iconName: row.extraIcon
        accessibleName: row.extraLabel
        onActivated: row.extraClicked()
    }

    IconButton {
        id: settingsButton

        objectName: "settingsButton"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        iconName: row.actionIcon
        accessibleName: row.actionLabel
        onActivated: row.openSettings()
    }
}
