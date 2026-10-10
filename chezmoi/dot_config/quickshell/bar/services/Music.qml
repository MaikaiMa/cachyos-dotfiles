pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import ".."

// The active MPRIS player (the first one playing, else the first one) and the
// colours of its album art.
Singleton {
    id: root

    // playerctld mirrors another player; listing it would count that player twice.
    readonly property var players: Mpris.players.values.filter(candidate => !candidate.dbusName.startsWith("org.mpris.MediaPlayer2.playerctld"))
    readonly property MprisPlayer player: players.find(candidate => candidate.isPlaying) ?? players[0] ?? null
    readonly property bool hasPlayer: player !== null
    // Set by Shell while the Player panel, the only reader of `position`, is open.
    property bool active: false

    readonly property string title: player ? player.trackTitle : ""
    readonly property string artist: player ? player.trackArtist : ""
    readonly property string album: player ? player.trackAlbum : ""
    readonly property string artUrl: player ? player.trackArtUrl : ""
    readonly property bool playing: player ? player.isPlaying : false
    // Seconds.
    readonly property real position: player ? player.position : 0
    readonly property real length: player && player.lengthSupported ? player.length : 0
    readonly property bool canSeek: player !== null && player.canSeek && player.positionSupported && length > 0

    // What is playing, for the now-playing peek. Firefox reports one constant
    // track id for every track, so the title and artist always take part too.
    readonly property string trackId: player ? String(player.metadata["mpris:trackid"] ?? "") : ""
    readonly property string trackIdentity: title !== "" || artist !== "" ? [trackId.endsWith("/NoTrack") ? "" : trackId, title, artist].join("\u0000") : ""
    readonly property string playerName: player ? player.dbusName : ""
    readonly property bool stopped: player ? player.playbackState === MprisPlaybackState.Stopped : true

    // The track shown last while playing; nowPlayingChanged fires when another one plays.
    property string shownIdentity: ""
    property string shownPlayer: ""
    // Date.now() when playback last paused; a resume after pauseForgetInterval peeks again.
    property real pausedAt: 0
    readonly property int pauseForgetInterval: 30000
    // The bar starting up with music already playing is not a change.
    property bool settled: false

    signal nowPlayingChanged()

    // Quantised art colours (file:// and http(s):// both load through Qt), one
    // per bucket, so a colour that covers more of the cover appears more often.
    readonly property var artColors: artUrl !== "" ? quantizer.colors : []
    // The most frequent bucket colour; Colors.primaryContainer without art.
    readonly property color artColorRaw: artColors.length > 0 ? dominant(artColors) : Colors.primaryContainer
    // Lifted to a minimum lightness, so a near-black cover still gives the orb,
    // its rim and the wave a colour that reads.
    readonly property color artColor: lifted(artColorRaw)
    // The rim light's other colours: a lighter and a warmer cut of artColor.
    readonly property color artLight: lifted(Qt.lighter(artColor, 1.35))
    readonly property color artWarm: lifted(warmer(artColor))
    readonly property real minimumArtLightness: 0.35

    function lifted(base: color): color {
        if (base.hslLightness >= minimumArtLightness)
            return base;
        return Qt.hsla(Math.max(0, base.hslHue), base.hslSaturation, minimumArtLightness, base.a);
    }

    function dominant(colors: var): color {
        const counts = {};
        let best = colors[0];
        for (const candidate of colors) {
            const key = String(candidate);
            counts[key] = (counts[key] || 0) + 1;
            if (counts[key] > counts[String(best)])
                best = candidate;
        }
        return best;
    }

    // Turns the hue a little toward orange; grey stays grey.
    function warmer(base: color): color {
        if (base.hslHue < 0)
            return Qt.lighter(base, 1.15);
        const towardOrange = ((0.08 - base.hslHue + 1.5) % 1) - 0.5;
        const hue = (base.hslHue + Math.max(-0.08, Math.min(0.08, towardOrange)) + 1) % 1;
        return Qt.hsla(hue, Math.min(1, base.hslSaturation * 1.1), Math.min(0.8, base.hslLightness * 1.05), 1);
    }

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

    // Brings the player's app to the front: MPRIS Raise when the player offers
    // it, else the Niri window that matches the player's desktop entry or
    // identity (Niri.windowForApp). Returns false when neither works.
    function raise(): bool {
        if (!player)
            return false;
        if (player.canRaise) {
            player.raise();
            return true;
        }
        const window = Niri.windowForApp([player.desktopEntry ?? "", player.identity ?? ""]);
        if (!window)
            return false;
        Niri.focusWindow(window.id);
        return true;
    }

    // "3:07", or "1:02:09" past an hour.
    function formatTime(seconds: real): string {
        const total = Math.max(0, Math.floor(seconds));
        const hours = Math.floor(total / 3600);
        const minutes = Math.floor(total % 3600 / 60);
        const rest = String(total % 60).padStart(2, "0");
        return hours > 0 ? hours + ":" + String(minutes).padStart(2, "0") + ":" + rest : minutes + ":" + rest;
    }

    // Absolute position in seconds.
    function seek(seconds: real) {
        if (canSeek)
            player.position = Math.max(0, Math.min(length, seconds));
    }

    function next() {
        if (player && player.canGoNext)
            player.next();
    }

    function previous() {
        if (player && player.canGoPrevious)
            player.previous();
    }

    onPlayingChanged: {
        if (playing) {
            if (pausedAt > 0 && Date.now() - pausedAt > pauseForgetInterval)
                shownIdentity = "";
            nowPlayingDebounce.restart();
        } else {
            nowPlayingDebounce.stop();
            pausedAt = Date.now();
        }
    }
    // isPlaying and playbackState change together; either may notify first.
    onStoppedChanged: {
        if (stopped)
            shownIdentity = "";
    }
    onTrackIdentityChanged: {
        if (playing)
            nowPlayingDebounce.restart();
    }
    onPlayerNameChanged: {
        if (playing)
            nowPlayingDebounce.restart();
    }

    // Metadata arrives in bursts (title, then artist); act once it holds still.
    Timer {
        id: nowPlayingDebounce

        interval: 500
        onTriggered: {
            if (!root.playing || root.trackIdentity === "" || !root.settled)
                return;
            if (root.trackIdentity === root.shownIdentity && root.playerName === root.shownPlayer)
                return;
            root.shownIdentity = root.trackIdentity;
            root.shownPlayer = root.playerName;
            root.nowPlayingChanged();
        }
    }

    Timer {
        interval: 1500
        running: true
        onTriggered: {
            if (root.playing) {
                root.shownIdentity = root.trackIdentity;
                root.shownPlayer = root.playerName;
            }
            root.settled = true;
        }
    }

    ColorQuantizer {
        id: quantizer

        source: root.artUrl
        depth: 4
        rescaleSize: 64
    }

    // MPRIS does not stream the position; ask for it while something plays and
    // active.
    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.playing && root.active
        onTriggered: root.player.positionChanged()
    }
}
