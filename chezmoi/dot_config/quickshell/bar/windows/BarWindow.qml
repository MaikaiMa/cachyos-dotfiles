pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.components
import qs.islands

// One window per screen, as tall as the screen: islands grow inside it instead
// of opening popups. Not anchored to the bottom edge: with all four edges
// anchored, layer-shell drops the exclusive zone. The window starts below
// any other top exclusive zone and runs past the screen bottom by that much.
// Only the islands take input and get blur; while a panel is open anywhere
// the whole window takes input so a press outside the islands closes it.
PanelWindow {
    id: bar

    required property ShellScreen shellScreen
    // The pointer is on the orb, in the orb's own surface.
    property bool orbHovered: false
    // Set once the window has presented its first frame.
    property bool presented: false
    readonly property alias centre: centre

    readonly property string screenName: shellScreen.name

    component IslandRegion: Region {
        required property Rectangle island

        x: island.x
        y: island.y
        width: island.width
        height: island.height
        radius: island.radius
    }

    // One disc blob slot under the right island (NotificationBlobs.area), empty
    // when nothing is there: the blobs, "+N" and clear-all.
    component BlobRegion: Region {
        required property int modelData
        readonly property rect area: blobs.area(modelData)

        shape: RegionShape.Ellipse
        x: area.x
        y: area.y
        width: area.width
        height: area.height
    }

    screen: shellScreen
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: shellScreen.height
    exclusionMode: ExclusionMode.Normal
    // Hidden, windows reflow into the bar's strip.
    exclusiveZone: Shell.hidden ? 0 : Theme.barHeight
    aboveWindows: true
    color: "transparent"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.namespace: "dotfiles-bar"
    // Exclusive, not OnDemand: panels also open from shortcuts without a
    // click, and Niri only hands on-demand focus to a layer on a click.
    // A tray menu is handled like a panel on its own screen: Escape and
    // a press outside close it.
    WlrLayershell.keyboardFocus: Shell.panelOpenOn(screenName) || right.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    mask: Shell.panelOpen || right.menuOpen ? fullRegion : inputRegion
    // The blur type lives in Quickshell core, which the BackgroundEffect
    // type info does not declare, so qmllint cannot resolve it.
    // The privacy pill of the hidden bar gets blur but no input.
    BackgroundEffect.blurRegion: blurRegion // qmllint disable missing-type

    Region {
        id: fullRegion

        width: bar.width
        height: bar.height
    }

    // Flat on purpose: each island is a direct child, and the input and
    // blur regions share no Region object, so each has its own islands and
    // its own Theme.notificationBlobMax + 2 blob slots.
    Region {
        id: inputRegion

        regions: [leftInput, centreInput, rightInput].concat(inputBlobs.instances)
    }

    Region {
        id: blurRegion

        regions: [leftBlur, centreBlur, rightBlur, privacyBlur].concat(blurBlobs.instances)
    }

    IslandRegion {
        id: leftInput

        island: left
    }
    IslandRegion {
        id: centreInput

        island: centre
    }
    IslandRegion {
        id: rightInput

        island: right
    }
    Variants {
        id: inputBlobs

        model: blobs.slots

        BlobRegion {}
    }

    IslandRegion {
        id: leftBlur

        island: left
    }
    IslandRegion {
        id: centreBlur

        island: centre
    }
    IslandRegion {
        id: rightBlur

        island: right
    }
    Variants {
        id: blurBlobs

        model: blobs.slots

        BlobRegion {}
    }
    Region {
        id: privacyBlur

        x: dock.pill.x
        y: dock.pill.y
        width: dock.pill.visible ? dock.pill.width : 0
        height: dock.pill.visible ? dock.pill.height : 0
        radius: dock.pill.radius
    }

    Item {
        id: keyRoot

        // How far the islands sit above their place: the hide toggle
        // slides them out of the screen. The centre island comes back
        // for the OSD while the bar is hidden.
        property real hideShift: Shell.hidden ? Theme.hideDistance : 0
        property real centreShift: Shell.hidden && !Shell.osdOn(bar.screenName) ? Theme.hideDistance : 0

        // Sliding away uses the shrink curve, coming back the grow curve.
        Behavior on hideShift {
            id: hideBehavior

            MorphAnimation {
                shrinking: hideBehavior.targetValue > 0
            }
        }
        Behavior on centreShift {
            id: centreBehavior

            MorphAnimation {
                shrinking: centreBehavior.targetValue > 0
            }
        }

        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: {
            right.closeMenu();
            Shell.close();
        }
        // Back from a panel opened from Settings; a focused text field
        // keeps Backspace for itself.
        Keys.onPressed: event => {
            const backKey = (event.key === Qt.Key_Backspace && event.modifiers === Qt.NoModifier) || (event.key === Qt.Key_Left && event.modifiers === Qt.AltModifier);
            if (backKey && Shell.canGoBack) {
                event.accepted = true;
                Shell.back();
            }
        }

        // Every state change hands the keys back here: a panel opens with
        // nothing focused, and a control focused with Tab in a closed panel
        // cannot keep Escape away from this item.
        Connections {
            target: Shell

            function onCentreStateChanged() {
                keyRoot.forceActiveFocus();
            }

            function onHiddenChanged() {
                if (Shell.hidden)
                    right.closeMenu();
            }
        }

        FrameCounter {
            item: keyRoot
            screen: bar.screenName
            window: "bar"
        }

        Connections {
            target: keyRoot.Window.window
            enabled: !bar.presented

            function onFrameSwapped() {
                bar.presented = true;
            }
        }

        // Below the islands, so they keep their input; the centre island's
        // panel guard keeps presses inside an open panel from reaching it.
        MouseArea {
            anchors.fill: parent
            enabled: Shell.panelOpen || right.menuOpen
            acceptedButtons: Qt.AllButtons
            onPressed: {
                right.closeMenu();
                Shell.close();
            }
        }

        LeftIsland {
            id: left

            screenName: bar.screenName
            x: Theme.gap
            y: Theme.islandTop - keyRoot.hideShift
        }

        RightIsland {
            id: right

            screenName: bar.screenName
            x: parent.width - width - Theme.gap
            y: Theme.islandTop - keyRoot.hideShift
            peekMaxWidth: parent.width - Theme.gap - (centre.x + centre.width) - Theme.notificationPeekCentreClearance
        }

        // Over the right island, so a blob crosses its bottom edge in sight.
        NotificationBlobs {
            id: blobs

            screenName: bar.screenName
            x: right.x + right.width - width
            y: right.y
            islandWidth: right.width
            islandBottom: right.height
            bellX: width - right.bellCentreOffset
            riseX: width - right.riseOffset
            clearShown: right.peekOpen
            discOrigin: id => {
                const disc = right.discFor(id);
                return disc ? disc.mapToItem(blobs, disc.width / 2, disc.height / 2) : null;
            }
        }

        // Under the centre island, outside its clipped edge.
        MusicGlow {
            x: centre.x
            y: centre.y
            z: centre.z - 0.5
            width: centre.width
            height: centre.height
            radius: centre.radius
            open: centre.musicBar
        }

        // Above the right island: an open panel is never covered by it.
        CentreIsland {
            id: centre

            screenName: bar.screenName
            orbHovered: bar.orbHovered
            x: (parent.width - width) / 2
            y: Theme.islandTop - keyRoot.centreShift
            z: 1
        }

        PrivacyDock {
            id: dock

            z: centre.z + 0.5
            centreLine: centre.centreLine
            islandRight: centre.x + centre.width
            islandY: centre.y
            osd: centre.osd
        }
    }
}
