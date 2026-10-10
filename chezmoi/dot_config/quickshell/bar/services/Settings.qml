pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The bar's own runtime switches, kept across restarts in
// $XDG_STATE_HOME/dotfiles-bar/settings.json. A missing file leaves the
// defaults; a hand edit is picked up while the bar runs.
Singleton {
    id: root

    // The top-edge wave.
    readonly property bool waveEnabled: stored.waveEnabled
    // Every duration 0 and no continuous animation (Motion).
    readonly property bool reduceMotion: stored.reduceMotion
    // Notifications peek in the right island.
    readonly property bool notificationPeek: stored.notificationPeek
    // The music bar opens for a moment when the playing track changes.
    readonly property bool nowPlayingPeek: stored.nowPlayingPeek
    // Light and Dark end in one screen-wide crossfade (Appearance).
    readonly property bool crossfade: stored.crossfade
    // Weather's location when geoclue has never answered, or always with
    // weatherFixedLocation: geoclue locates by the ISP's address, which can
    // be a city away. The default is a placeholder (Amsterdam); set your own
    // in the file.
    readonly property real weatherLatitude: stored.weatherLatitude
    readonly property real weatherLongitude: stored.weatherLongitude
    readonly property bool weatherFixedLocation: stored.weatherFixedLocation

    function setWaveEnabled(enabled: bool) {
        stored.waveEnabled = enabled;
    }

    function setReduceMotion(enabled: bool) {
        stored.reduceMotion = enabled;
    }

    function setNotificationPeek(enabled: bool) {
        stored.notificationPeek = enabled;
    }

    function setNowPlayingPeek(enabled: bool) {
        stored.nowPlayingPeek = enabled;
    }

    function setCrossfade(enabled: bool) {
        stored.crossfade = enabled;
    }

    JsonAdapter {
        id: stored

        property bool waveEnabled: true
        property bool reduceMotion: false
        property bool notificationPeek: true
        property bool nowPlayingPeek: true
        property bool crossfade: true
        property real weatherLatitude: 52.37
        property real weatherLongitude: 4.90
        property bool weatherFixedLocation: false
    }

    FileView {
        path: Paths.barState + "/settings.json"
        watchChanges: true
        printErrors: false
        // The property's type is not in the module's type info.
        adapter: stored // qmllint disable missing-type
        onFileChanged: reload()
        onAdapterUpdated: writeAdapter()
    }
}
