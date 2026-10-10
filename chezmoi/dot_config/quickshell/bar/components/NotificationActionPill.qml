import QtQuick
import ".."

// One action of a notification as a 24 px pill; the default action's label is
// tinted. Hover only tints the pill.
Rectangle {
    id: pill

    property string label: ""
    property bool primary: false
    property color baseColor: Colors.surfaceContainerHigh

    signal activated

    implicitWidth: Math.min(Theme.notificationActionMaxWidth, Math.ceil(labelText.implicitWidth) + 2 * Theme.notificationActionPadding)
    implicitHeight: Theme.notificationActionHeight
    radius: height / 2
    color: pointer.containsMouse ? Qt.tint(baseColor, Qt.alpha(Colors.primary, 0.16)) : baseColor
    activeFocusOnTab: true

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            pill.activated();
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    Text {
        id: labelText

        anchors.centerIn: parent
        width: Math.min(implicitWidth, pill.width - 2 * Theme.notificationActionPadding)
        text: pill.label
        elide: Text.ElideRight
        textFormat: Text.PlainText
        color: pill.primary ? Colors.primary : Colors.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.notificationActionFontSize
        font.weight: Theme.fontWeight
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Colors.primary
        visible: pill.activeFocus
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: pill.activated()
    }

    Accessible.role: Accessible.Button
    Accessible.name: pill.label
    Accessible.onPressAction: pill.activated()
}
