import QtQuick
import Quickshell
import Quickshell.Wayland
import "components"
import "islands"
import "services"

ShellRoot {
    component IslandRegion: Region {
        required property Rectangle island

        x: island.x
        y: island.y
        width: island.width
        height: island.height
        radius: island.radius
    }

    Variants {
        model: Quickshell.screens

        Scope {
            id: screenScope

            required property ShellScreen modelData

            readonly property bool panelOpenHere: Shell.panelOpen && Shell.screenName === modelData.name
            readonly property bool osdHere: Shell.osdVisible && Shell.screenName === modelData.name
            // The orb's surface maps only after the bar window has: Niri stacks
            // the surfaces of a layer in mapping order, and the orb must lie over
            // the music bar.
            property bool barPresented: false
            // The orb surface's left edge: it covers every place the orb takes
            // outside a panel, so it never moves or resizes while music plays.
            readonly property int orbLeft: Math.floor(modelData.width / 2 + centre.orbTravelLeft)

            // Three surfaces per screen. Qt Quick presents a whole surface on every
            // frame, so whatever animates continuously lives in a small surface of
            // its own: the wave in a strip on the Bottom layer, the orb in a box
            // left of the centre island. The tall bar window then presents frames
            // only when something in it changes.
            PanelWindow {
                id: waveSurface

                screen: screenScope.modelData
                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: Theme.waveHeight
                visible: Theme.topWaveEnabled && Settings.waveEnabled && Cava.waveOpacity > 0
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Bottom
                WlrLayershell.namespace: "dotfiles-bar-wave"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                mask: Region {}

                TopWave {
                    id: wave

                    width: parent.width
                }

                FrameCounter {
                    item: wave
                    screen: screenScope.modelData.name
                    window: "wave"
                }
            }

            PanelWindow {
                id: orbSurface

                screen: screenScope.modelData
                anchors {
                    top: true
                    left: true
                }
                // PanelWindow's margins group is not in its type info.
                margins.left: screenScope.orbLeft // qmllint disable unqualified unresolved-type
                // Ends at the collapsed pill's left edge, clipping the bloom's faint
                // last 2 px: a frame of this box then damages nothing over the
                // blurred island, which Niri would otherwise redraw with it.
                implicitWidth: Math.floor(screenScope.modelData.width / 2 - centre.pillWidth / 2) - screenScope.orbLeft
                implicitHeight: Math.ceil(Theme.islandTop + (Theme.islandHeight + centre.orb.height) / 2)
                visible: Music.hasPlayer && screenScope.barPresented
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "dotfiles-bar-orb"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                mask: Region {
                    shape: RegionShape.Ellipse
                    x: centre.orb.x
                    y: centre.orb.y
                    width: centre.orb.visible ? centre.orb.width : 0
                    height: centre.orb.visible ? centre.orb.height : 0
                }

                Item {
                    id: orbLayer

                    anchors.fill: parent
                }

                FrameCounter {
                    item: orbLayer
                    screen: screenScope.modelData.name
                    window: "orb"
                }
            }

            // One window per screen, as tall as the screen: islands grow inside it instead
            // of opening popups. Not anchored to the bottom edge: with all four edges
            // anchored, layer-shell drops the exclusive zone. The window starts below
            // any other top exclusive zone and runs past the screen bottom by that much.
            // Only the islands take input and get blur; while a panel is open anywhere
            // the whole window takes input so a press outside the islands closes it.
            PanelWindow {
                id: bar

                screen: screenScope.modelData
                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: screenScope.modelData.height
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
                WlrLayershell.keyboardFocus: screenScope.panelOpenHere || right.menuOpen ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
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
                // blur regions share no Region object.
                Region {
                    id: inputRegion

                    IslandRegion {
                        island: left
                    }
                    IslandRegion {
                        island: centre
                    }
                    IslandRegion {
                        island: right
                    }
                }

                Region {
                    id: blurRegion

                    IslandRegion {
                        island: left
                    }
                    IslandRegion {
                        island: centre
                    }
                    IslandRegion {
                        island: right
                    }
                    Region {
                        x: centre.privacyPill.x
                        y: centre.privacyPill.y
                        width: centre.privacyPill.visible ? centre.privacyPill.width : 0
                        height: centre.privacyPill.visible ? centre.privacyPill.height : 0
                        radius: centre.privacyPill.radius
                    }
                }

                Item {
                    id: keyRoot

                    // How far the islands sit above their place: the hide toggle
                    // slides them out of the screen. The centre island comes back
                    // for the OSD while the bar is hidden.
                    property real hideShift: Shell.hidden ? Theme.hideDistance : 0
                    property real centreShift: Shell.hidden && !screenScope.osdHere ? Theme.hideDistance : 0

                    // Sliding away uses the shrink curve, coming back the grow curve.
                    Behavior on hideShift {
                        id: hideBehavior

                        IslandAnimation {
                            shrinking: hideBehavior.targetValue > 0
                        }
                    }
                    Behavior on centreShift {
                        id: centreBehavior

                        IslandAnimation {
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
                        if (backKey && Shell.settingsChildren.includes(Shell.centreState)) {
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
                        screen: screenScope.modelData.name
                        window: "bar"
                    }

                    Connections {
                        target: keyRoot.Window.window
                        enabled: !screenScope.barPresented

                        function onFrameSwapped() {
                            screenScope.barPresented = true;
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

                        screenName: screenScope.modelData.name
                        x: Theme.gap
                        y: Theme.islandTop - keyRoot.hideShift
                    }

                    RightIsland {
                        id: right

                        screenName: screenScope.modelData.name
                        x: parent.width - width - Theme.gap
                        y: Theme.islandTop - keyRoot.hideShift
                    }

                    // Above the right island: an open panel is never covered by it.
                    CentreIsland {
                        id: centre

                        screenName: screenScope.modelData.name
                        x: (parent.width - width) / 2
                        y: Theme.islandTop - keyRoot.centreShift
                        z: 1
                        orbParent: orbLayer
                        orbOrigin: screenScope.orbLeft
                    }
                }
            }
        }
    }
}
