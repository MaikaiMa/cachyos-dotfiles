pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services

// The music bar rim's soft outer glow: rings outside the island's edge,
// fainter the farther out. The island clips its children, so the owner
// places this under the centre island with the island's geometry. It reads
// the audio clock only while it shows.
Item {
    id: glow

    property bool open: false
    property real radius: 0

    opacity: open ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        MusicFade {
            opening: glow.open
        }
    }

    Repeater {
        model: Theme.musicBarGlowRings

        RimLight {
            id: glowRing

            required property var modelData

            x: -modelData[0]
            y: -modelData[0]
            width: glow.width + 2 * modelData[0]
            height: glow.height + 2 * modelData[0]
            radius: glow.radius + modelData[0]
            thickness: Theme.musicBarGlowRingWidth
            angle: glow.visible ? -Cava.barRimAngle : 0
            lift: Theme.musicBarRimLift
            level: glow.visible ? Cava.level : 0
            opacity: glowRing.modelData[1] * glowRing.levelOpacity
        }
    }
}
