import QtQuick
import Quickshell.Services.Mpris
import qs.Common
import qs.Services
import qs.Widgets

DashboardCard {
    id: media

    readonly property MprisPlayer activePlayer: MprisController.activePlayer
    readonly property bool hasPlayer: activePlayer !== null
    readonly property bool isPlaying: activePlayer?.playbackState === MprisPlaybackState.Playing
    readonly property real trackLength: MprisController.activePlayerStableLength

    property bool isSeeking: false

    function formatTime(seconds) {
        const total = Math.max(0, Math.floor(seconds || 0));
        const minutes = Math.floor(total / 60);
        const rest = total % 60;
        return minutes + ":" + (rest < 10 ? "0" : "") + rest;
    }

    spacing: Theme.spacingS

    Item {
        width: parent.width
        height: 66

        Rectangle {
            id: artwork

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            width: 66
            height: 66
            radius: Theme.cornerRadius
            color: Theme.primaryBackground
            clip: true

            DankIcon {
                anchors.centerIn: parent
                name: "music_note"
                size: Theme.iconSizeLarge - 4
                color: Theme.primary
                visible: artImage.status !== Image.Ready
            }

            Image {
                id: artImage

                anchors.fill: parent
                source: TrackArtService.resolvedArtUrl
                fillMode: Image.PreserveAspectCrop
                asynchronous: true
                sourceSize.width: 132
                sourceSize.height: 132
                visible: status === Image.Ready
            }
        }

        Column {
            anchors.left: artwork.right
            anchors.leftMargin: Theme.spacingM
            anchors.right: controls.left
            anchors.rightMargin: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXXS

            StyledText {
                width: parent.width
                text: media.hasPlayer ? (MprisController.stableTitle || I18n.trFor("dotfilesDashboard", "Unknown track")) : I18n.trFor("dotfilesDashboard", "Nothing playing")
                font.pixelSize: Theme.fontSizeLarge
                font.weight: Font.Bold
                color: Theme.surfaceText
                elide: Text.ElideRight
                maximumLineCount: 1
            }

            StyledText {
                width: parent.width
                text: media.hasPlayer ? (MprisController.stableArtist || I18n.trFor("dotfilesDashboard", "Unknown artist")) : I18n.trFor("dotfilesDashboard", "Start playback to use these controls")
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
                elide: Text.ElideRight
                maximumLineCount: 1
            }
        }

        Row {
            id: controls

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingXS

            DankActionButton {
                circular: false
                iconName: "skip_previous"
                enabled: media.activePlayer?.canGoPrevious ?? false
                opacity: enabled ? 1 : 0.4
                backgroundColor: Theme.ccPillInactiveBg
                onClicked: MprisController.previousOrRewind()
            }

            DankActionButton {
                circular: false
                iconName: media.isPlaying ? "pause" : "play_arrow"
                enabled: media.hasPlayer
                opacity: enabled ? 1 : 0.4
                backgroundColor: Theme.ccPillInactiveBg
                onClicked: media.activePlayer?.togglePlaying()
            }

            DankActionButton {
                circular: false
                iconName: "skip_next"
                enabled: media.activePlayer?.canGoNext ?? false
                opacity: enabled ? 1 : 0.4
                backgroundColor: Theme.ccPillInactiveBg
                onClicked: MprisController.next()
            }
        }
    }

    Item {
        width: parent.width
        height: 20

        StyledText {
            id: elapsed

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            text: media.formatTime(media.hasPlayer && media.trackLength > 0 ? (media.activePlayer.position || 0) % Math.max(1, media.trackLength) : 0)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        StyledText {
            id: total

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: media.formatTime(media.trackLength)
            font.pixelSize: Theme.fontSizeSmall
            color: Theme.surfaceVariantText
        }

        DankSeekbar {
            anchors.left: elapsed.right
            anchors.right: total.left
            anchors.leftMargin: Theme.spacingS
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            height: 20
            activePlayer: media.activePlayer
            stableLength: media.trackLength
            accentColor: MediaAccentService.accent
            accentTrackColor: MediaAccentService.accentTrack
            accentSubtleColor: MediaAccentService.accentSubtle
            isSeeking: media.isSeeking
            onIsSeekingChanged: media.isSeeking = isSeeking
        }
    }

    Timer {
        interval: 500
        repeat: true
        running: media.isPlaying && !media.isSeeking
        onTriggered: media.activePlayer?.positionSupported && media.activePlayer.positionChanged()
    }
}
