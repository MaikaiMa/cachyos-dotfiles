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

            // One tall window per screen: islands grow inside it instead of opening
            // popups. Only the islands take input and get blur; the rest is click-through.
            PanelWindow {
                id: bar

                screen: screenScope.modelData
                anchors {
                    top: true
                    left: true
                    right: true
                }
                implicitHeight: Theme.windowHeight
                exclusionMode: ExclusionMode.Normal
                exclusiveZone: Theme.barHeight
                aboveWindows: true
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "dotfiles-bar"
                // Exclusive, not OnDemand: panels also open from shortcuts without a
                // click, and Niri only hands on-demand focus to a layer on a click.
                WlrLayershell.keyboardFocus: screenScope.panelOpenHere ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
                mask: islandRegion
                // The blur type lives in Quickshell core, which the BackgroundEffect
                // type info does not declare, so qmllint cannot resolve it.
                BackgroundEffect.blurRegion: islandRegion // qmllint disable missing-type

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

            // While a panel is open anywhere, a press outside the islands on any
            // screen closes it. The islands are cut out, so they keep their clicks
            // whichever of the two windows Niri stacks on top.
            PanelWindow {
                id: clickCatcher

                screen: screenScope.modelData
                visible: Shell.panelOpen
                anchors {
                    top: true
                    bottom: true
                    left: true
                    right: true
                }
                exclusionMode: ExclusionMode.Ignore
                color: "transparent"
                WlrLayershell.layer: WlrLayer.Top
                WlrLayershell.namespace: "dotfiles-click-catcher"
                WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
                mask: Region {
                    Region {
                        width: clickCatcher.width
                        height: clickCatcher.height
                    }
                    Region {
                        intersection: Intersection.Subtract
                        x: left.x
                        y: left.y
                        width: left.width
                        height: left.height
                    }
                    Region {
                        intersection: Intersection.Subtract
                        x: centre.x
                        y: centre.y
                        width: centre.width
                        height: centre.height
                    }
                    Region {
                        intersection: Intersection.Subtract
                        x: right.x
                        y: right.y
                        width: right.width
                        height: right.height
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    acceptedButtons: Qt.AllButtons
                    onPressed: Shell.close()
                }
            }
        }
    }
}
