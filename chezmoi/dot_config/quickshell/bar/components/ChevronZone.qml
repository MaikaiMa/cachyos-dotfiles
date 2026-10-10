import QtQuick
import ".."

// The zone at the right end of a tile or capsule that opens its panel: a
// hairline at its left edge and a chevron. The hover tint clips a copy of the
// owner's whole rounded shape, so the outer corners stay round and the inner
// edge straight. reveal fades the hairline and the chevron, not the tint.
Item {
    id: zone

    property real shapeWidth: 0
    property real shapeRadius: 0
    property color tint: Colors.hoverSurface
    property bool lit: false
    property color hairlineColor: Qt.alpha(Colors.foregroundVariant, Theme.tileChevronHairlineOpacity)
    property color iconColor: Colors.foreground
    property real reveal: 1

    width: Theme.tileChevronZone

    Item {
        anchors.fill: parent
        clip: true
        opacity: zone.lit ? 1 : 0

        Behavior on opacity {
            Crossfade {}
        }

        Rectangle {
            x: -zone.x
            width: zone.shapeWidth
            height: zone.height
            radius: zone.shapeRadius
            color: zone.tint
        }
    }

    Rectangle {
        objectName: "chevronHairline"
        visible: opacity > 0
        opacity: zone.reveal
        width: Theme.hairlineWidth
        height: parent.height
        color: zone.hairlineColor
    }

    Icon {
        objectName: "chevron"
        visible: opacity > 0
        opacity: zone.reveal
        anchors.centerIn: parent
        name: "chevron_right"
        size: Theme.toggleIconSize
        color: zone.iconColor
    }
}
