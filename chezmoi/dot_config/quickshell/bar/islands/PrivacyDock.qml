import QtQuick
import ".."
import "../components"
import "../services"

// The privacy dots right of the centre island, through Detail, the music bar
// and every panel: never hidden while something records. Hidden with
// something recording (and no OSD bringing the island back), they glide to
// the screen centre into a mini island of their own and stay at the islands'
// top row. The owner places this at its origin, over the centre island,
// leaves it out of the input mask and adds the pill to the blur region.
Item {
    id: dock

    // The centre island in this item's coordinates.
    property real centreLine: 0
    property real islandRight: 0
    property real islandY: 0
    // The OSD shows on this screen.
    property bool osd: false

    readonly property bool docked: Shell.hidden && !osd && Privacy.anyActive
    readonly property alias pill: pillItem
    // 0 at the island's right edge, 1 centred on the clock; the grow curve both ways.
    property real glide: docked ? 1 : 0
    property real pillOpacity: docked ? 1 : 0
    // The pill keeps its last width while it fades out with no dot left.
    property real pillWidth: Theme.privacyDotSize + 2 * Theme.privacyPillPadding

    Behavior on glide {
        MorphAnimation {}
    }

    Behavior on pillOpacity {
        id: pillFade

        MorphAnimation {
            shrinking: pillFade.targetValue < 1
        }
    }

    // A dot coming or going while docked resizes the pill around the clock's x.
    Behavior on pillWidth {
        id: pillResize

        enabled: dock.pillOpacity > 0

        MorphAnimation {
            shrinking: pillResize.targetValue < dock.pillWidth
        }
    }

    Binding on pillWidth {
        when: dots.implicitWidth > 0
        value: dots.implicitWidth + 2 * Theme.privacyPillPadding
        restoreMode: Binding.RestoreNone
    }

    Rectangle {
        id: pillItem

        objectName: "privacyPill"
        x: Math.round(dock.centreLine - width / 2)
        y: Theme.islandTop + (Theme.islandHeight - height) / 2
        width: dock.pillWidth
        height: Theme.privacyPillHeight
        radius: height / 2
        color: Colors.islandSurface
        opacity: dock.pillOpacity
        visible: opacity > 0
    }

    PrivacyDots {
        id: dots

        readonly property real edgeX: Math.round(dock.islandRight) + Theme.privacyDotOffset
        readonly property real centredX: pillItem.x + Theme.privacyPillPadding

        objectName: "privacyDots"
        x: edgeX + (centredX - edgeX) * dock.glide
        y: Math.round((Shell.hidden ? Theme.islandTop : dock.islandY) + (Theme.islandHeight - height) / 2)
    }
}
