import QtQuick
import qs

// A round icon button. Plain, a subtle fill shows under the pointer; accent
// tints the fill and lights the icon; filled is the accent disc, the main
// control of a row; without background only the icon reacts.
Pressable {
    id: button

    property string iconName: ""
    property int size: Theme.controlButtonSize
    property int iconSize: Theme.toggleIconSize
    property real iconFill: 0
    property bool filled: false
    property bool accent: false
    property bool background: true
    property color iconColor: filled ? Colors.primaryForeground : accent && hovered ? Colors.primary : Colors.foreground

    readonly property color fillColor: {
        if (filled)
            return hovered ? Colors.hovered(Colors.primary, true) : Colors.primary;
        if (!background || !hovered)
            return "transparent";
        return accent ? Colors.hoverFill : Colors.subtleFill;
    }

    implicitWidth: size
    implicitHeight: size

    Rectangle {
        anchors.fill: parent
        radius: width / 2
        color: button.fillColor

        Behavior on color {
            ColorCrossfade {}
        }

        FocusRing {
            visible: button.activeFocus
        }
    }

    Icon {
        anchors.centerIn: parent
        name: button.iconName
        size: button.iconSize
        fill: button.iconFill
        color: button.iconColor

        Behavior on color {
            ColorCrossfade {}
        }
    }
}
