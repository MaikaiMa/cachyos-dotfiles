pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../panels"
import "../services"

// The dynamic island. The owner centres it horizontally on the screen and fixes
// its top, so it grows symmetrically sideways and downward and the clock stays put.
Island {
    id: island

    required property string screenName

    readonly property string centreState: Shell.stateOn(screenName)
    readonly property bool panelOpen: Shell.panelStates.includes(centreState)
    readonly property bool detail: centreState === "detail"
    readonly property bool osd: Shell.osdVisible && Shell.screenName === screenName
    readonly property bool showsPill: (centreState === "collapsed" || detail) && !osd

    readonly property int pillWidth: pill.implicitWidth + 2 * Theme.paddingHorizontal

    width: panelOpen ? Theme.panelWidths[centreState] : centreState === "musicbar" ? Theme.musicBarWidth : osd ? Theme.osdWidth : pillWidth
    height: panelOpen ? Theme.placeholderPanelHeight : detail ? Theme.islandDetailHeight : Theme.islandHeight
    expanded: panelOpen || detail
    shrinking: centreState === "collapsed"

    // Weather icon | clock | battery icon. Both side columns share one width so the
    // clock sits on the island's centre line in every state.
    Item {
        id: pill

        readonly property int sideWidth: Math.max(Theme.iconSize, island.detail ? Math.max(weatherLabel.implicitWidth, batteryLabel.implicitWidth) : 0)
        readonly property int clockWidth: Math.max(clock.implicitWidth, island.detail ? dateLabel.implicitWidth : 0)

        anchors.horizontalCenter: parent.horizontalCenter
        y: 0
        implicitWidth: 2 * sideWidth + clockWidth + 4 * Theme.gap + 2 * Theme.hairlineWidth
        height: Theme.islandDetailHeight
        opacity: island.showsPill ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        Row {
            spacing: Theme.gap

            Item {
                width: pill.sideWidth
                height: Theme.islandHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.iconSize
                    height: Theme.iconSize
                    radius: width / 2
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.onSurface
                }
            }

            Hairline {
                anchors.verticalCenter: parent.verticalCenter
                opacity: island.detail ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.crossfadeDuration
                        easing.type: Motion.crossfadeEasing
                    }
                }
            }

            Item {
                width: pill.clockWidth
                height: Theme.islandHeight

                Clock {
                    id: clock

                    anchors.centerIn: parent
                }
            }

            Hairline {
                anchors.verticalCenter: parent.verticalCenter
                opacity: island.detail ? 0 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.crossfadeDuration
                        easing.type: Motion.crossfadeEasing
                    }
                }
            }

            Item {
                width: pill.sideWidth
                height: Theme.islandHeight

                Rectangle {
                    anchors.centerIn: parent
                    width: Theme.iconSize
                    height: Theme.iconSize * 0.6
                    radius: 3
                    color: "transparent"
                    border.width: 2
                    border.color: Colors.onSurface
                }
            }
        }

        // Detail labels, one under each icon, in the second row of the 48 px island.
        Item {
            y: Theme.islandHeight - Theme.paddingVertical / 2
            width: pill.implicitWidth
            height: Theme.islandDetailHeight - y
            opacity: island.detail ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }

            DetailLabel {
                id: weatherLabel

                x: (pill.sideWidth - width) / 2
                text: "18°"
            }

            Clock {
                id: dateLabel

                x: (pill.implicitWidth - width) / 2
                format: "ddd dd-MM"
                color: Colors.onSurfaceVariant
                font.pixelSize: Theme.secondaryFontSize
            }

            DetailLabel {
                id: batteryLabel

                x: pill.implicitWidth - pill.sideWidth + (pill.sideWidth - width) / 2
                text: "82%"
            }
        }
    }

    // Stand-in for the OSD slider pill shown over the collapsed pill.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingHorizontal
        height: Theme.paddingVertical
        radius: height / 2
        color: Colors.surfaceContainerHigh
        opacity: island.osd ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: island.osd ? Motion.osdInDuration : Motion.osdOutDuration
                easing.type: island.osd ? Easing.OutCubic : Easing.InCubic
            }
        }

        Rectangle {
            width: parent.width * 0.6
            height: parent.height
            radius: parent.radius
            color: Colors.primary
        }
    }

    Repeater {
        model: Shell.panelStates.concat(["musicbar"])

        PlaceholderPanel {
            required property string modelData

            anchors.fill: parent
            name: modelData
            shown: island.centreState === modelData
        }
    }

    component DetailLabel: Text {
        color: Colors.onSurfaceVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.secondaryFontSize
        font.weight: Theme.fontWeight
    }

    HoverHandler {
        id: hover

        onHoveredChanged: {
            if (hovered) {
                restTimer.restart();
            } else {
                restTimer.stop();
                if (island.detail)
                    Shell.close();
            }
        }
    }

    Timer {
        id: restTimer

        interval: Motion.hoverRestDelay
        onTriggered: {
            if (Shell.centreState === "collapsed" && !island.osd)
                Shell.open("detail", island.screenName);
        }
    }

    TapHandler {
        enabled: island.showsPill
        onTapped: Shell.toggle("home", island.screenName)
    }
}
