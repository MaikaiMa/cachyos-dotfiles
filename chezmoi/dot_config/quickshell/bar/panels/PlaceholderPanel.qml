import QtQuick
import ".."

// Stands in for a real panel body until its step lands; shows the state name.
Item {
    id: panel

    required property string name
    property bool shown: false

    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.paddingVertical

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: panel.name
            color: Colors.onSurface
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Theme.fontWeight
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "placeholder"
            color: Colors.onSurfaceVariant
            font.family: Theme.fontFamily
            font.pixelSize: Theme.secondaryFontSize
        }
    }
}
