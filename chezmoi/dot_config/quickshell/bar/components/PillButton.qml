import QtQuick
import qs

// A text pill, optionally with a leading icon that spins while busy. filled
// is the accent pill of a main action; tone colours a plain pill's text,
// "accent" for a default action and "danger" for a destructive one; checked
// marks the selected one of a group of chips.
Pressable {
    id: button

    property string text: ""
    property string iconName: ""
    property bool filled: false
    property string tone: "neutral"
    property bool checked: false
    property bool spinning: false
    property color baseColor: Colors.surfaceContainerHigh
    property color hoverColor: Colors.hovered(baseColor, false)
    property color textColor: filled ? Colors.primaryForeground : tone === "accent" ? Colors.primary : tone === "danger" ? Colors.error : Colors.foreground
    property int fontSize: Theme.fontSize
    property bool strong: false
    property real horizontalPadding: Theme.pillPadding
    property real maxWidth: Number.POSITIVE_INFINITY

    readonly property alias label: labelText
    readonly property real iconWidth: glyph.visible ? glyph.width + content.spacing : 0

    implicitWidth: Math.min(maxWidth, Math.ceil(labelText.implicitWidth) + iconWidth + 2 * horizontalPadding)
    implicitHeight: Theme.pillHeight
    accessibleName: text
    opacity: enabled ? 1 : Theme.disabledOpacity

    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: {
            if (button.filled)
                return button.hovered ? Colors.hovered(Colors.primary, true) : Colors.primary;
            if (button.checked)
                return Colors.selectedSurface;
            return button.hovered ? button.hoverColor : button.baseColor;
        }

        Behavior on color {
            ColorCrossfade {}
        }

        FocusRing {
            visible: button.activeFocus
        }
    }

    Row {
        id: content

        anchors.centerIn: parent
        spacing: Theme.gap

        Icon {
            id: glyph

            anchors.verticalCenter: parent.verticalCenter
            visible: button.iconName !== ""
            name: button.iconName
            color: button.textColor

            RotationAnimator on rotation {
                // Only while it shows: a spin in a hidden panel still makes the
                // bar window present frames.
                running: button.spinning && glyph.visible && Motion.refreshSpinDuration > 0
                from: 0
                to: 360
                duration: Motion.refreshSpinDuration
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running)
                        glyph.rotation = 0;
                }
            }
        }

        Label {
            id: labelText

            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, button.width - 2 * button.horizontalPadding - button.iconWidth)
            text: button.text
            color: button.textColor
            font.pixelSize: button.fontSize
            strong: button.strong
        }
    }
}
