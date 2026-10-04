pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import ".."

// The active MPRIS player (the first one playing, else the first one) and the
// colours of its album art.
Singleton {
    id: root

    readonly property var players: Mpris.players.values
    readonly property MprisPlayer player: players.find(candidate => candidate.isPlaying) ?? players[0] ?? null
    readonly property bool hasPlayer: player !== null

    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string artUrl: player ? player.trackArtUrl : ""
    readonly property bool playing: player ? player.isPlaying : false
    // Seconds.
    readonly property real position: player ? player.position : 0
    readonly property real length: player && player.lengthSupported ? player.length : 0

    // Quantised art colours (file:// and http(s):// both load through Qt);
    // artColor is the first, Colors.primaryContainer without art.
    readonly property var artColors: artUrl !== "" ? quantizer.colors : []
    readonly property color artColor: artColors.length > 0 ? artColors[0] : Colors.primaryContainer

    function play() {
        if (player && player.canPlay)
            player.play();
    }

    function pause() {
        if (player && player.canPause)
            player.pause();
    }

    function togglePlaying() {
        if (player && player.canTogglePlaying)
            player.togglePlaying();
    }

    function next() {
        if (player && player.canGoNext)
            player.next();
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }

    ColorQuantizer {
        id: quantizer

        source: root.artUrl
        depth: 4
        rescaleSize: 64
    }

    // MPRIS does not stream the position; ask for it while something plays.
    Timer {
        interval: 1000
        repeat: true
        running: root.playing
        onTriggered: root.player.positionChanged()
    }
}
