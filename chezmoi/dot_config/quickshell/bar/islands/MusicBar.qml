pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.components

// The music bar inside the centre island: title and artist as one run, then
// previous, play or pause, next, with the orb's travelling light around the
// island's edge; and the Player's quieter rim. The owner fills the island
// with it. The rims read the audio clock only while they show: a hidden item
// that changes still makes the window present a frame. The soft outer glow
// lies outside the island, which clips: MusicGlow, placed by the owner.
Item {
    id: bar

    required property string screenName
    property bool open: false
    property bool playerOpen: false
    property real radius: 0

    readonly property real level: barRim.visible ? Cava.level : 0
    readonly property real playerLevel: playerRim.visible ? Cava.level : 0

    Item {
        id: barRim

        anchors.fill: parent
        opacity: bar.open ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            MusicFade {
                opening: bar.open
            }
        }

        RimLight {
            id: barRimLight

            anchors.fill: parent
            radius: bar.radius
            thickness: Theme.musicBarRimWidth
            angle: barRim.visible ? -Cava.barRimAngle : 0
            lift: Theme.musicBarRimLift
            level: bar.level
            opacity: barRimLight.levelOpacity
        }
    }

    // The orb sits in the left padding. A click anywhere but a control opens
    // the Player.
    Item {
        x: (bar.width - width) / 2
        width: Theme.musicBarWidth
        height: Theme.islandHeight
        opacity: bar.open ? 1 : 0
        visible: opacity > 0
        enabled: bar.open

        Behavior on opacity {
            MusicFade {
                opening: bar.open
            }
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Shell.open("player", bar.screenName)
        }

        Marquee {
            x: Theme.orbInset + Theme.orbSize + Theme.gap
            width: controls.x - Theme.gap - x
            height: parent.height
            primaryText: Music.title
            secondaryText: Music.artist
            primaryPixelSize: Theme.musicTitleFontSize
            running: bar.open
        }

        Row {
            id: controls

            x: parent.width - width - Theme.musicBarPaddingRight
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gap

            MusicButton {
                iconName: "skip_previous"
                accessibleName: "Previous"
                onActivated: Music.previous()
            }

            MusicButton {
                iconName: Music.playing ? "pause" : "play_arrow"
                accessibleName: Music.playing ? "Pause" : "Play"
                onActivated: Music.togglePlaying()
            }

            MusicButton {
                iconName: "skip_next"
                accessibleName: "Next"
                onActivated: Music.next()
            }
        }
    }

    // The Player carries the rim light as a quiet continuation: thinner, slower,
    // no glow, fading with the panel body.
    Appear {
        id: playerRim

        anchors.fill: parent
        shown: bar.playerOpen

        RimLight {
            id: playerRimLight

            anchors.fill: parent
            radius: bar.radius
            thickness: Theme.playerRimWidth
            angle: playerRim.visible ? -Cava.playerRimAngle : 0
            lift: Theme.musicBarRimLift
            level: bar.playerLevel
            opacity: playerRimLight.levelOpacity
        }
    }

    // Pointer only: the music bar is a hover surface, outside the Tab order.
    component MusicButton: IconButton {
        size: Theme.musicControlSize
        iconSize: Theme.iconSize
        iconFill: 1
        accent: true
        background: false
        focusable: false
    }
}
