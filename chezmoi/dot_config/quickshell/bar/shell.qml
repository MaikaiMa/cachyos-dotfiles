import QtQuick
import Quickshell
import Quickshell.Wayland
import "islands"
import "services"

ShellRoot {
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
                WlrLayershell.keyboardFocus: screenScope.panelOpenHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                mask: Shell.panelOpen ? fullRegion : islandRegion
                // The blur type lives in Quickshell core, which the BackgroundEffect
                // type info does not declare, so qmllint cannot resolve it.
                BackgroundEffect.blurRegion: islandRegion // qmllint disable missing-type

                Region {
                    id: fullRegion

                    width: bar.width
                    height: bar.height
                }

                Region {
                    id: islandRegion

                    Region {
                        x: left.x
                        y: left.y
                        width: left.width
                        height: left.height
                        radius: left.radius
                    }
                    Region {
                        x: centre.x
                        y: centre.y
                        width: centre.width
                        height: centre.height
                        radius: centre.radius
                    }
                    Region {
                        x: right.x
                        y: right.y
                        width: right.width
                        height: right.height
                        radius: right.radius
                    }
                }

                Item {
                    id: keyRoot

                    anchors.fill: parent
                    focus: true
                    Keys.onEscapePressed: Shell.close()

                    // Every state change hands the keys back here: a panel opens with
                    // nothing focused, and a control focused with Tab in a closed panel
                    // cannot keep Escape away from this item.
                    Connections {
                        target: Shell

                        function onCentreStateChanged() {
                            keyRoot.forceActiveFocus();
                        }
                    }

                    // Below the islands, so they keep their input; the centre island's
                    // panel guard keeps presses inside an open panel from reaching it.
                    MouseArea {
                        anchors.fill: parent
                        enabled: Shell.panelOpen
                        acceptedButtons: Qt.AllButtons
                        onPressed: Shell.close()
                    }

                    LeftIsland {
                        id: left

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
