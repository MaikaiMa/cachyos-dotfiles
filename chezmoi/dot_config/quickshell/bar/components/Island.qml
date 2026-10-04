pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import ".."

// The surface every island is drawn on; its owner sets width and height.
Rectangle {
    id: island

    property bool expanded: false
    property bool shrinking: false

    color: Qt.alpha(Colors.surface, Theme.islandOpacity)
    radius: expanded ? Theme.islandRadiusExpanded : Theme.islandRadius
    clip: true

    Behavior on width {
        IslandAnimation {
            shrinking: island.shrinking
        }
    }
    Behavior on height {
        IslandAnimation {
            shrinking: island.shrinking
        }
    }
    Behavior on radius {
        IslandAnimation {
            shrinking: island.shrinking
        }
    }

    property real shadowStrength: expanded ? 1 : 0

    Behavior on shadowStrength {
        IslandAnimation {
            shrinking: island.shrinking
        }
    }

    layer.enabled: true
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowColor: Qt.alpha(Colors.shadow, Theme.shadowOpacity)
        shadowOpacity: island.shadowStrength
        shadowVerticalOffset: Theme.shadowOffsetY
        blurMax: Theme.shadowBlur
        shadowBlur: 1
    }
}
