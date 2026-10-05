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
                exclusiveZone: Theme.barHeight
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
                // The orb takes input but gets no blur: it floats on the wallpaper.
                BackgroundEffect.blurRegion: blurRegion // qmllint disable missing-type

                Region {
                    id: fullRegion

                    width: bar.width
                    height: bar.height
                }

                // Flat on purpose: each island and the orb is a direct child, and the
                // input and blur regions share no Region object.
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
                    Region {
                        shape: RegionShape.Ellipse
                        x: centre.orb.x
                        y: centre.orb.y
                        width: centre.orb.visible ? centre.orb.width : 0
                        height: centre.orb.visible ? centre.orb.height : 0
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
                }

                Item {
                    id: keyRoot

                    anchors.fill: parent
                    focus: true
                    Keys.onEscapePressed: {
                        right.closeMenu();
                        Shell.close();
                    }

                    // Every state change hands the keys back here: a panel opens with
                    // nothing focused, and a control focused with Tab in a closed panel
                    // cannot keep Escape away from this item.
                    Connections {
                        target: Shell

                        function onCentreStateChanged() {
                            keyRoot.forceActiveFocus();
                        }
                    }

                    // Behind the islands and outside the mask and the blur region.
                    TopWave {
                        width: parent.width
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
                        y: Theme.islandTop
                    }

                    RightIsland {
                        id: right

                        screenName: screenScope.modelData.name
                        x: parent.width - width - Theme.gap
                        y: Theme.islandTop
                    }

                    // Above the right island: an open panel is never covered by it.
                    CentreIsland {
                        id: centre

                        screenName: screenScope.modelData.name
                        x: (parent.width - width) / 2
                        y: Theme.islandTop
                        z: 1
                    }
                }
            }
        }
    }
}
