import QtQuick
import ".."

// A Settings grid toggle. Wide tiles show an icon disc, a title and a one-line
// state; small tiles only the icon. Active tiles take the accent. A tile with a
// panel of its own gets a chevron zone on its right while wide; the zone, a long
// press, a right click, Right or the menu key open the panel.
Item {
    id: tile

    property string title: ""
    property string stateText: ""
    property string iconName: ""
    property bool active: false
    property bool wide: false
    // False for a tile that only opens something.
    property bool checkable: true
    // Has a panel: the chevron zone while wide, and the secondary action.
    property bool hasPanel: false

    signal activated
    // The chevron zone, right click, long press, Right or the menu key; only tiles
    // with a panel have one.
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

    readonly property bool chevronShown: hasPanel && wide
    // The toggle's part of the tile; the chevron zone takes the rest.
    readonly property real mainWidth: width - (chevronShown ? Theme.tileChevronZone : 0)
    readonly property bool overChevron: chevronShown && pointer.mouseX >= mainWidth
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
        } else if (tile.hasPanel && (event.key === Qt.Key_Menu || event.key === Qt.Key_Right)) {
            event.accepted = true;
            tile.secondaryAction();
        }
    }

    Rectangle {
        id: surface

        anchors.fill: parent
        radius: Theme.tileRadius
        color: tile.restColor
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

        // Hover tints only the zone under the pointer: each zone clips a copy of
        // the whole rounded tile, so the outer corners stay round and the inner
        // edges stay straight.
        HoverZone {
            x: 0
            width: tile.mainWidth
            height: parent.height
            tileWidth: tile.width
            tint: tile.hoverColor
            lit: tile.hovered && !tile.overChevron
        }

        HoverZone {
            x: tile.mainWidth
            width: tile.width - tile.mainWidth
            height: parent.height
            tileWidth: tile.width
            tint: tile.hoverColor
            lit: tile.hovered && tile.overChevron
        }

        Rectangle {
            visible: opacity > 0
            opacity: tile.chevronShown ? tile.wideBlend : 0
            x: tile.mainWidth
            width: 1
            height: parent.height
            color: tile.active ? Qt.alpha(Colors.primaryForeground, Theme.tileChevronHairlineOpacity) : Qt.alpha(Colors.foregroundVariant, Theme.tileChevronHairlineOpacity)
        }

        Icon {
            visible: opacity > 0
            opacity: tile.chevronShown ? tile.wideBlend : 0
            x: tile.mainWidth + (Theme.tileChevronZone - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            name: "chevron_right"
            size: Theme.toggleIconSize
            color: tile.contentColor
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
            anchors.rightMargin: 12 + tile.width - tile.mainWidth
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
        onPressAndHold: {
            if (tile.hasPanel)
                tile.secondaryAction();
        }
        onClicked: mouse => {
            if (!tile.hasPanel && mouse.button === Qt.RightButton)
                return;
            if (mouse.button === Qt.RightButton || (tile.chevronShown && mouse.x >= tile.mainWidth))
                tile.secondaryAction();
            else
                tile.activated();
        }
    }

    component HoverZone: Item {
        id: zone

        property bool lit: false
        property real tileWidth: 0
        property color tint: "transparent"

        clip: true
        opacity: lit ? 1 : 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        Rectangle {
            x: -zone.x
            width: zone.tileWidth
            height: zone.height
            radius: Theme.tileRadius
            color: zone.tint
        }
    }
}
