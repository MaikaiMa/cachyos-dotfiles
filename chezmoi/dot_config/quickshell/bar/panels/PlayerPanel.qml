pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Services.Pipewire
import ".."
import "../components"
import "../services"

// The Player state of the centre island: cover beside title, artist and album,
// a thin seekable progress track with times, previous / play / next, and the
// audio outputs as chips when there is more than one.
Item {
    id: panel

    property bool shown: false

    // Undefined for a moment while a reload brings Audio up.
    readonly property bool showsOutputs: (Audio.sinks ?? []).length > 1
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

    implicitWidth: Theme.panelWidths.player
    implicitHeight: (showsOutputs ? outputsY + Theme.outputChipHeight : controlsY + Theme.playerPlaySize) + Theme.panelPadding

    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    // The cover leads to the app that plays: raised, then the panel closes.
    function openSource() {
        if (Music.raise())
            Shell.close();
    }

    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        const rest = String(total % 60).padStart(2, "0");
        return hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") + ":" + rest : minutes + ":" + rest;
    }

    Item {
        id: cover

        objectName: "cover"
        x: Theme.panelPadding
        y: Theme.panelPadding
        width: Theme.playerCoverSize
        height: Theme.playerCoverSize
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: "Open the player"
        Accessible.onPressAction: panel.openSource()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                panel.openSource();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: Theme.playerCoverRadius
            color: Colors.surfaceContainerHigh

            Icon {
                anchors.centerIn: parent
                name: "music_note"
                size: 2 * Theme.iconSize
                color: Colors.foregroundVariant
            }
        }

        Image {
            id: art

            anchors.fill: parent
            source: Music.artUrl
            sourceSize.width: 2 * Theme.playerCoverSize
            sourceSize.height: 2 * Theme.playerCoverSize
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            visible: false
        }

        Rectangle {
            id: coverMask

            anchors.fill: parent
            radius: Theme.playerCoverRadius
            visible: false
            layer.enabled: true
        }

        MultiEffect {
            anchors.fill: parent
            source: art
            visible: art.status === Image.Ready
            maskEnabled: true
            maskSource: coverMask
            // A soft ramp over the mask's alpha keeps the antialiased corner; the
            // default thresholds cut it at a single alpha.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Rectangle {
            objectName: "coverOverlay"
            anchors.fill: parent
            radius: Theme.playerCoverRadius
            color: Qt.alpha(Colors.surface, Theme.playerCoverOverlayOpacity)
            opacity: coverPointer.containsMouse || cover.activeFocus ? 1 : 0
            visible: opacity > 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "open_in_new"
                size: Theme.playerCoverIconSize
                color: Colors.foreground
            }
        }

        MouseArea {
            id: coverPointer

            objectName: "coverPointer"
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: panel.openSource()
        }
    }

    Column {
        x: cover.x + cover.width + Theme.playerCoverGap
        anchors.verticalCenter: cover.verticalCenter
        width: panel.width - x - Theme.panelPadding
        spacing: Theme.playerTextGap

        Text {
            objectName: "playerTitle"
            width: parent.width
            text: Music.title || "Nothing playing"
            elide: Text.ElideRight
            color: Colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.playerTitleFontSize
            font.weight: Font.DemiBold
        }

        SecondaryText {
            width: parent.width
            text: Music.artist
            visible: text !== ""
        }

        SecondaryText {
            width: parent.width
            text: Music.album
            visible: text !== ""
        }
    }

    // The visible track is 4 px; the hit area around it is taller.
    Item {
        id: progress

        objectName: "progress"
        x: Theme.panelPadding
        y: panel.progressY + (Theme.playerTrackHeight - height) / 2
        width: panel.width - 2 * Theme.panelPadding
        height: Theme.playerTrackHitHeight
        activeFocusOnTab: Music.canSeek

        Accessible.role: Accessible.Slider
        Accessible.name: "Position"
        Accessible.description: panel.formatTime(panel.position)

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
        x: Theme.panelPadding
        y: panel.timesY
        width: panel.width - 2 * Theme.panelPadding
        height: Theme.playerTimesHeight

        SecondaryText {
            text: panel.formatTime(panel.fraction * Music.length)
            font.features: ({
                    tnum: 1
                })
        }

        SecondaryText {
            anchors.right: parent.right
            text: Music.length > 0 ? panel.formatTime(Music.length) : "–"
            font.features: ({
                    tnum: 1
                })
        }
    }

    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        y: panel.controlsY
        height: Theme.playerPlaySize
        spacing: Theme.playerControlSpacing

        ControlButton {
            objectName: "playerPrevious"
            anchors.verticalCenter: parent.verticalCenter
            iconName: "skip_previous"
            label: "Previous"
            onActivated: Music.previous()
        }

        ControlButton {
            objectName: "playerToggle"
            anchors.verticalCenter: parent.verticalCenter
            big: true
            iconName: Music.playing ? "pause" : "play_arrow"
            label: Music.playing ? "Pause" : "Play"
            onActivated: Music.togglePlaying()
        }

        ControlButton {
            objectName: "playerNext"
            anchors.verticalCenter: parent.verticalCenter
            iconName: "skip_next"
            label: "Next"
            onActivated: Music.next()
        }
    }

    // Centred when the chips fit, scrolls sideways when they do not.
    Flickable {
        objectName: "outputs"
        x: Theme.panelPadding
        y: panel.outputsY
        width: panel.width - 2 * Theme.panelPadding
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

                OutputChip {}
            }
        }
    }

    component SecondaryText: Text {
        elide: Text.ElideRight
        color: Colors.foregroundVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.secondaryFontSize
        font.weight: Theme.fontWeight
    }

    component FocusRing: Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: height / 2
        color: "transparent"
        border.width: 2
        border.color: Colors.primary
    }

    component ControlButton: Item {
        id: control

        property string iconName: ""
        property string label: ""
        property bool big: false

        signal activated

        width: big ? Theme.playerPlaySize : Theme.playerControlSize
        height: width
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: control.activated()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                control.activated();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: {
                if (control.big)
                    return controlPointer.containsMouse ? Qt.tint(Colors.primary, Qt.alpha(Colors.primaryForeground, 0.10)) : Colors.primary;
                return controlPointer.containsMouse ? Qt.alpha(Colors.primary, 0.12) : "transparent";
            }

            FocusRing {
                visible: control.activeFocus
            }
        }

        Icon {
            anchors.centerIn: parent
            name: control.iconName
            size: control.big ? Theme.playerPlayIconSize : Theme.playerControlIconSize
            fill: 1
            color: control.big ? Colors.primaryForeground : controlPointer.containsMouse ? Colors.primary : Colors.foreground
        }

        MouseArea {
            id: controlPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: control.activated()
        }
    }

    component OutputChip: Item {
        id: chip

        required property PwNode modelData
        readonly property bool current: modelData === Audio.sink

        width: Math.min(Theme.outputChipMaxWidth, chipText.implicitWidth + 2 * Theme.outputChipPadding)
        height: Theme.outputChipHeight
        activeFocusOnTab: true

        Accessible.role: Accessible.RadioButton
        Accessible.name: chipText.text
        Accessible.checked: current
        Accessible.onPressAction: Audio.setDefaultSink(chip.modelData)

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                Audio.setDefaultSink(chip.modelData);
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.current ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.22)) : chipPointer.containsMouse ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.12)) : Colors.surfaceContainerHigh

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }

            FocusRing {
                visible: chip.activeFocus
            }
        }

        Text {
            id: chipText

            anchors.centerIn: parent
            width: Math.min(implicitWidth, chip.width - 2 * Theme.outputChipPadding)
            text: Audio.sinkLabel(chip.modelData)
            elide: Text.ElideRight
            color: chip.current ? Colors.foreground : Colors.foregroundVariant
            font.family: Theme.fontFamily
            font.pixelSize: Theme.secondaryFontSize
            font.weight: Theme.fontWeight
        }

        MouseArea {
            id: chipPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: Audio.setDefaultSink(chip.modelData)
        }
    }
}
