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
    readonly property bool chevronShown: hasPanel && wide
    // The toggle's part of the tile; the chevron zone takes the rest.
    readonly property real mainWidth: width - (chevronShown ? Theme.tileChevronZone : 0)
    readonly property bool overChevron: chevronShown && pointer.mouseX >= mainWidth
    readonly property bool hovered: pointer.containsMouse
    readonly property color contentColor: active ? Colors.primaryForeground : Colors.foreground
    readonly property color restColor: active ? Colors.primary : Colors.surfaceContainerHigh
    readonly property color hoverColor: Colors.hovered(restColor, active)

    implicitHeight: Theme.settingsTileHeight
    activeFocusOnTab: true

    Behavior on wideBlend {
        MorphAnimation {}
    }

    Accessible.role: Accessible.Button
    Accessible.name: title
    Accessible.description: stateText
    Accessible.checkable: checkable
    Accessible.checked: active
    Accessible.onPressAction: tile.activated()

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier))
            return;
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
            ColorCrossfade {}
        }

        Behavior on scale {
            Crossfade {}
        }

        // Hover tints only the zone under the pointer: the toggle's part here,
        // the chevron zone's in ChevronZone, each from a clipped copy of the tile.
        Item {
            width: tile.mainWidth
            height: parent.height
            clip: true
            opacity: tile.hovered && !tile.overChevron ? 1 : 0

            Behavior on opacity {
                Crossfade {}
            }

            Rectangle {
                width: tile.width
                height: parent.height
                radius: Theme.tileRadius
                color: tile.hoverColor
            }
        }

        ChevronZone {
            x: tile.mainWidth
            width: tile.width - tile.mainWidth
            height: parent.height
            shapeWidth: tile.width
            shapeRadius: Theme.tileRadius
            tint: tile.hoverColor
            lit: tile.hovered && tile.overChevron
            reveal: tile.chevronShown ? tile.wideBlend : 0
            hairlineColor: Qt.alpha(tile.active ? Colors.primaryForeground : Colors.foregroundVariant, Theme.tileChevronHairlineOpacity)
            iconColor: tile.contentColor
        }

        Rectangle {
            id: disc

            visible: opacity > 0
            opacity: tile.wideBlend
            x: Theme.tileContentInset + (1 - tile.wideBlend) * (surface.width / 2 - Theme.tileContentInset - width / 2)
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.tileIconDisc
            height: width
            radius: width / 2
            color: tile.active ? Qt.alpha(Colors.primaryForeground, Theme.tileDiscOnAccentOpacity) : Colors.subtleFill
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
            anchors.leftMargin: Theme.tileTextGap
            anchors.right: parent.right
            anchors.rightMargin: Theme.tileContentInset + tile.width - tile.mainWidth
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: tile.title
                strong: true
                color: tile.contentColor
            }

            Label {
                width: parent.width
                text: tile.stateText
                secondary: true
                color: tile.active ? Qt.alpha(Colors.primaryForeground, Theme.tileStateOnAccentOpacity) : Colors.foregroundVariant
            }
        }

        FocusRing {
            radius: Theme.tileRadius + inset
            visible: tile.activeFocus
        }
    }

    MouseArea {
        id: pointer

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        pressAndHoldInterval: Motion.longPressInterval
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
}
