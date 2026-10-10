import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../components"
import "../islands"
import "../services"

// The music orb in a small box of its own left of the centre island, so its
// 30 Hz rim does not make the bar window present frames. The box covers
// every place the orb takes outside a panel (centre.orbTravelLeft to
// orbTravelRight from the island's centre line), so it never moves or
// resizes while music plays. Its input region is the orb's hit area.
PanelWindow {
    id: surface

    required property ShellScreen shellScreen
    required property CentreIsland centre
    // Niri stacks the surfaces of a layer in mapping order, and the orb must
    // lie over the music bar: this box maps only after the bar window has
    // presented its first frame.
    property bool barPresented: false
    readonly property bool orbHovered: orbHover.hovered
    // The box's left edge in the bar window's coordinates, which share its origin.
    readonly property int boxLeft: Math.floor(shellScreen.width / 2 + centre.orbTravelLeft)

    screen: shellScreen
    anchors {
        top: true
        left: true
    }
    // PanelWindow's margins group is not in its type info.
    margins.left: surface.boxLeft // qmllint disable unqualified unresolved-type
    // Ends at the collapsed pill's left edge, clipping the bloom's faint last
    // 2 px: a frame of this box then damages nothing over the blurred island,
    // which Niri would otherwise redraw with it.
    implicitWidth: Math.floor(shellScreen.width / 2 - centre.pillWidth / 2) - boxLeft
    implicitHeight: Math.ceil(Theme.islandTop + (Theme.islandHeight + orb.height) / 2)
    visible: Music.hasPlayer && barPresented
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dotfiles-bar-orb"
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    mask: Region {
        shape: RegionShape.Ellipse
        x: orb.x
        y: orb.y
        width: orb.visible ? orb.width : 0
        height: orb.visible ? orb.height : 0
    }

    Item {
        id: orbLayer

        anchors.fill: parent

        // Rests beside the island, held inside the box while a panel's island
        // carries it farther out and it fades.
        Orb {
            id: orb

            readonly property real restX: surface.centre.x + surface.centre.orbOffset
            readonly property real leftmostX: surface.centre.centreLine + surface.centre.orbTravelLeft
            readonly property real rightmostX: surface.centre.centreLine + surface.centre.orbTravelRight - width

            objectName: "orb"
            x: Math.max(leftmostX, Math.min(rightmostX, restX)) - surface.boxLeft
            y: surface.centre.y + (Theme.islandHeight - height) / 2
            opacity: Music.hasPlayer && !surface.centre.panelOpen ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Crossfade {}
            }

            HoverHandler {
                id: orbHover
            }

            TapHandler {
                onTapped: surface.centre.orbTapped()
            }
        }
    }

    FrameCounter {
        item: orbLayer
        screen: surface.shellScreen.name
        window: "orb"
    }
}
