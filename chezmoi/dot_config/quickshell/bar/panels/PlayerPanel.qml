pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Pipewire
import ".."
import "../components"
import "../services"

// The Player state of the centre island: cover beside title, artist and album,
// a thin seekable progress track with times, previous / play / next, and the
// audio outputs as chips when there is more than one.
Panel {
    id: panel

    name: "player"

    readonly property bool showsOutputs: Audio.sinks.length > 1
    readonly property real progressY: Theme.panelPadding + Theme.playerCoverSize + Theme.playerProgressGap
    readonly property real timesY: progressY + Theme.playerTrackHeight + Theme.playerTimesGap
    readonly property real controlsY: timesY + Theme.playerTimesHeight + Theme.playerControlsGap
    readonly property real outputsY: controlsY + Theme.playerPlaySize + Theme.outputsGap

    // A drag on the track previews its position until the release seeks.
    property bool seeking: false
    property real seekFraction: 0
    // Read only while the panel shows: the position changes every second while
    // playing, and a hidden item that changes still makes the window present a frame.
    readonly property real position: visible ? Music.position : 0
    readonly property real fraction: seeking ? seekFraction : Music.length > 0 ? Math.max(0, Math.min(1, position / Music.length)) : 0

    implicitHeight: (showsOutputs ? outputsY + Theme.outputChipHeight : controlsY + Theme.playerPlaySize) + Theme.panelPadding

    // The cover leads to the app that plays: raised, then the panel closes.
    function openSource() {
        if (Music.raise())
            Shell.close();
    }

    // The overlay is its focus mark.
    Pressable {
        id: cover

        objectName: "cover"
        x: panel.contentX
        y: Theme.panelPadding
        width: Theme.playerCoverSize
        height: Theme.playerCoverSize
        accessibleName: "Open the player"
        onActivated: panel.openSource()

        Rectangle {
            anchors.fill: parent
            radius: Theme.playerCoverRadius
            color: Colors.surfaceContainerHigh

            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: Theme.playerCoverPlaceholderSize
                color: Colors.foregroundVariant
            }
        }

        RoundedImage {
            anchors.fill: parent
            radius: Theme.playerCoverRadius
            source: Music.artUrl
        }

        Rectangle {
            objectName: "coverOverlay"
            anchors.fill: parent
            radius: Theme.playerCoverRadius
            color: Qt.alpha(Colors.surface, Theme.playerCoverOverlayOpacity)
            opacity: cover.hovered || cover.activeFocus ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                Crossfade {}
            }

            Icon {
                anchors.centerIn: parent
                name: "open_in_new"
                size: Theme.playerCoverIconSize
                color: Colors.foreground
            }
        }
    }

    Column {
        x: cover.x + cover.width + Theme.playerCoverGap
        anchors.verticalCenter: cover.verticalCenter
        width: panel.width - x - Theme.panelPadding
        spacing: Theme.playerTextGap

        Label {
            objectName: "playerTitle"
            width: parent.width
            text: Music.title || "Nothing playing"
            strong: true
            font.pixelSize: Theme.playerTitleFontSize
        }

        Label {
            width: parent.width
            text: Music.artist
            visible: text !== ""
            secondary: true
        }

        Label {
            width: parent.width
            text: Music.album
            visible: text !== ""
            secondary: true
        }
    }

    // The hit area is taller than the visible track.
    Item {
        id: progress

        objectName: "progress"
        x: panel.contentX
        y: panel.progressY + (Theme.playerTrackHeight - height) / 2
        width: panel.contentWidth
        height: Theme.playerTrackHitHeight
        activeFocusOnTab: Music.canSeek

        Accessible.role: Accessible.Slider
        Accessible.name: "Position"
        Accessible.description: Music.formatTime(panel.position)

        Keys.onLeftPressed: Music.seek(Music.position - Theme.playerSeekStep)
        Keys.onRightPressed: Music.seek(Music.position + Theme.playerSeekStep)

        Rectangle {
            id: track

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: Theme.playerTrackHeight
            radius: height / 2
            color: Colors.surfaceContainerHigh

            Rectangle {
                width: track.width * panel.fraction
                height: parent.height
                radius: parent.radius
                color: Colors.primary
            }

            FocusRing {
                visible: progress.activeFocus
            }
        }

        MouseArea {
            anchors.fill: parent
            enabled: Music.canSeek
            cursorShape: Music.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
            preventStealing: true

            function fractionAt(pointX: real): real {
                return Math.max(0, Math.min(1, pointX / width));
            }

            onPressed: mouse => {
                panel.seekFraction = fractionAt(mouse.x);
                panel.seeking = true;
            }
            onPositionChanged: mouse => {
                if (pressed)
                    panel.seekFraction = fractionAt(mouse.x);
            }
            onReleased: {
                Music.seek(panel.seekFraction * Music.length);
                panel.seeking = false;
            }
            onCanceled: panel.seeking = false
        }
    }

    Item {
        x: panel.contentX
        y: panel.timesY
        width: panel.contentWidth
        height: Theme.playerTimesHeight

        Label {
            text: Music.formatTime(panel.fraction * Music.length)
            secondary: true
            numeric: true
        }

        Label {
            anchors.right: parent.right
            text: Music.length > 0 ? Music.formatTime(Music.length) : "–"
            secondary: true
            numeric: true
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.controlsY
        height: Theme.playerPlaySize
        spacing: Theme.playerControlSpacing

        IconButton {
            objectName: "playerPrevious"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.playerControlSize
            iconSize: Theme.playerControlIconSize
            iconFill: 1
            accent: true
            iconName: "skip_previous"
            accessibleName: "Previous"
            onActivated: Music.previous()
        }

        IconButton {
            objectName: "playerToggle"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.playerPlaySize
            iconSize: Theme.playerPlayIconSize
            iconFill: 1
            filled: true
            iconName: Music.playing ? "pause" : "play_arrow"
            accessibleName: Music.playing ? "Pause" : "Play"
            onActivated: Music.togglePlaying()
        }

        IconButton {
            objectName: "playerNext"
            anchors.verticalCenter: parent.verticalCenter
            size: Theme.playerControlSize
            iconSize: Theme.playerControlIconSize
            iconFill: 1
            accent: true
            iconName: "skip_next"
            accessibleName: "Next"
            onActivated: Music.next()
        }
    }

    Flickable {
        objectName: "outputs"
        x: panel.contentX
        y: panel.outputsY
        width: panel.contentWidth
        height: Theme.outputChipHeight
        visible: panel.showsOutputs
        contentWidth: chips.width
        contentHeight: height
        flickableDirection: Flickable.HorizontalFlick
        boundsBehavior: Flickable.StopAtBounds
        clip: true

        Row {
            id: chips

            x: Math.max(0, (parent.width - width) / 2)
            spacing: Theme.outputChipGap

            Repeater {
                model: Audio.sinks

                PillButton {
                    id: chip

                    required property PwNode modelData

                    height: Theme.outputChipHeight
                    text: Audio.nodeLabel(chip.modelData)
                    checked: chip.modelData === Audio.sink
                    textColor: chip.checked ? Colors.foreground : Colors.foregroundVariant
                    fontSize: Theme.secondaryFontSize
                    horizontalPadding: Theme.outputChipPadding
                    maxWidth: Theme.outputChipMaxWidth
                    onActivated: Audio.setDefaultSink(chip.modelData)

                    Accessible.role: Accessible.RadioButton
                    Accessible.checked: chip.checked
                }
            }
        }
    }
}
