import QtQuick
import ".."

// A Settings grid toggle. Wide tiles show an icon disc, a title and a one-line
// state; small tiles only the icon. Active tiles take the accent.
Item {
    id: tile

    property string title: ""
    property string stateText: ""
    property string iconName: ""
    property bool active: false
    property bool wide: false
    // False for a tile that only opens something.
    property bool checkable: true

    signal activated
    // Right click, long press or the menu key; only some tiles have one.
    signal secondaryAction

    // 1 wide, 0 small; it moves with the grid, so a tile that changes size
    // between the docked and the detached grid slides its icon along.
    property real wideBlend: wide ? 1 : 0

    Behavior on wideBlend {
        NumberAnimation {
            duration: Motion.growDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.growCurve
        }
    }

    readonly property bool hovered: pointer.containsMouse
    readonly property color contentColor: active ? Colors.primaryForeground : Colors.foreground
    readonly property color restColor: active ? Colors.primary : Colors.surfaceContainerHigh
    readonly property color hoverColor: active ? Qt.tint(Colors.primary, Qt.alpha(Colors.primaryForeground, 0.10)) : Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.16))

    implicitHeight: Theme.settingsTileHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: stateText
    Accessible.checkable: checkable
    Accessible.checked: active
    Accessible.onPressAction: tile.activated()

    Keys.onPressed: event => {
        if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
            event.accepted = true;
            tile.activated();
        } else if (event.key === Qt.Key_Menu) {
            event.accepted = true;
            tile.secondaryAction();
        }
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.tileRadius
        color: tile.hovered ? tile.hoverColor : tile.restColor
        scale: pointer.pressed ? 0.98 : 1

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

        Rectangle {
            id: disc

            visible: opacity > 0
            opacity: tile.wideBlend
            x: 12 + (1 - tile.wideBlend) * (surface.width / 2 - 12 - width / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.tileIconDisc
            height: width
            radius: width / 2
            color: tile.active ? Qt.alpha(Colors.primaryForeground, 0.14) : Qt.alpha(Colors.foreground, 0.07)
        }

        Icon {
            anchors.centerIn: disc
            name: tile.iconName
            size: Theme.toggleIconSize
            color: tile.contentColor
            fill: tile.active ? 1 : 0
        }

        Column {
            visible: opacity > 0
            opacity: tile.wideBlend
            anchors.left: disc.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 12
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: tile.title
                elide: Text.ElideRight
                color: tile.contentColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Font.DemiBold
            }

            Text {
                width: parent.width
                text: tile.stateText
                elide: Text.ElideRight
                color: tile.active ? Qt.alpha(Colors.primaryForeground, 0.72) : Colors.foregroundVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Theme.fontWeight
            }
        }

        // Keyboard focus only arrives through Tab, so the ring never shows on a click.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: Theme.tileRadius + 3
            color: "transparent"
            border.width: 2
            border.color: Colors.primary
            visible: tile.activeFocus
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        pressAndHoldInterval: 500
        // A long press suppresses the click that would follow it.
        onPressAndHold: tile.secondaryAction()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton)
                tile.secondaryAction();
            else
                tile.activated();
        }
    }
}
