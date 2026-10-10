pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The dynamic island: the pill and Detail, the OSD, the music bar and the
// panels, one at a time. The owner centres it horizontally on the screen and
// fixes its top, so it grows symmetrically sideways and downward and the clock
// stays put. The orb, the music bar's glow and the privacy dock live beside
// it in the owner's windows, placed from the geometry below.
Island {
    id: island

    required property string screenName
    // The pointer is on the orb, in its own surface.
    property bool orbHovered: false

    readonly property string centreState: Shell.stateOn(screenName)
    readonly property bool panelOpen: Shell.panelOpenOn(screenName)
    readonly property bool osd: Shell.osdOn(screenName)
    readonly property bool detail: centreState === "detail"
    readonly property bool musicBar: centreState === "musicbar"
    readonly property bool player: centreState === "player"
    readonly property bool showsPill: (centreState === "collapsed" || detail) && !osd
    readonly property int pillWidth: pill.pillWidth

    // In the parent's coordinates.
    readonly property real centreLine: x + width / 2
    // Where the orb's hit area can be, from the centre line: left of the pill,
    // Detail or the OSD, or orbInset inside the music bar. The orb's surface
    // covers this span, so it never moves or resizes while music plays.
    readonly property real orbOutside: Theme.orbGap + Theme.orbSize + Theme.orbHitPadding
    readonly property real orbInsideBar: -Theme.musicBarWidth / 2 + Theme.orbInset - Theme.orbHitPadding
    readonly property real orbTravelLeft: Math.floor(Math.min(-Math.max(pill.pillWidth, pill.detailWidth, Theme.osdWidth) / 2 - orbOutside, orbInsideBar))
    readonly property real orbTravelRight: Math.ceil(Math.max(-Math.min(pill.pillWidth, pill.detailWidth, Theme.osdWidth) / 2 - orbOutside, orbInsideBar) + Theme.orbHitSize)
    // From the island's left edge to the orb's hit area: left of the pill, or the
    // bar's first element. It moves with the island's own curve and duration.
    property real orbOffset: musicBar ? Theme.orbInset - Theme.orbHitPadding : -orbOutside

    Behavior on orbOffset {
        MorphAnimation {
            shrinking: !island.musicBar
        }
    }

    targetWidth: panels.current ? panels.current.implicitWidth : musicBar ? Theme.musicBarWidth : osd ? Theme.osdWidth : detail ? pill.detailWidth : pill.pillWidth
    targetHeight: panels.current ? panels.current.implicitHeight : detail ? Theme.islandDetailHeight : Theme.islandHeight
    targetOpacity: panelOpen ? Theme.panelOpacity : Theme.islandOpacity
    targetBlend: detail ? 1 : 0
    expanded: panelOpen || detail

    // The orb's tap: the rest that would open the music bar is moot.
    function orbTapped() {
        orbRestTimer.stop();
        Shell.open("player", screenName);
    }

    // The music bar stays open while the pointer is on the orb or the island.
    function updateMusicHover() {
        if (orbHovered || islandHover.hovered) {
            musicLeaveTimer.stop();
            if (musicBar && Shell.peeking)
                Shell.endPeek();
            if (orbHovered && !musicBar)
                orbRestTimer.restart();
        } else {
            orbRestTimer.stop();
            if (musicBar)
                musicLeaveTimer.restart();
        }
    }

    onOrbHoveredChanged: updateMusicHover()

    CentrePill {
        id: pill

        width: island.width
        screenName: island.screenName
        shown: island.showsPill
        detail: island.detail
        blend: island.blend
        originX: island.x
        hovered: pillHover.hovered
    }

    // Over the collapsed pill while a volume or brightness key was pressed.
    Osd {
        objectName: "osd"
        x: (island.width - width) / 2
        shown: island.osd
    }

    MusicBar {
        anchors.fill: parent
        screenName: island.screenName
        open: island.musicBar
        playerOpen: island.player
        radius: island.radius
    }

    // Under the panel bodies: a click on empty panel space stops here and does nothing.
    MouseArea {
        objectName: "panelGuard"
        anchors.fill: parent
        enabled: island.panelOpen
        acceptedButtons: Qt.AllButtons
    }

    CentrePanels {
        id: panels

        anchors.fill: parent
        centreState: island.centreState
    }

    // Above the panels: the pill's hover lives on a hit area that covers the
    // collapsed pill and the Detail island and does not resize while the
    // island animates, so the growing edge never toggles it.
    Item {
        x: (island.width - width) / 2
        width: pill.hoverWidth
        height: Theme.islandDetailHeight

        HoverHandler {
            id: pillHover
        }
    }

    HoverHandler {
        id: islandHover

        onHoveredChanged: island.updateMusicHover()
    }

    // A peek that opens under a resting pointer is a hover from the start.
    Connections {
        target: Shell

        function onPeekingChanged() {
            if (Shell.peeking && island.musicBar && (island.orbHovered || islandHover.hovered))
                Shell.endPeek();
        }
    }

    Timer {
        id: orbRestTimer

        interval: Motion.orbHoverDelay
        onTriggered: {
            if (island.showsPill && island.orbHovered)
                Shell.open("musicbar", island.screenName);
        }
    }

    Timer {
        id: musicLeaveTimer

        interval: Motion.hoverLeaveGrace
        onTriggered: {
            if (island.musicBar && !island.orbHovered && !islandHover.hovered)
                Shell.close();
        }
    }
}
