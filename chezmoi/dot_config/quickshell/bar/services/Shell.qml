pragma Singleton

import QtQuick
import Quickshell
import qs

// The one state machine of the centre island, shared by every screen.
Singleton {
    id: root

    readonly property var panelStates: ["home", "settings", "player", "power", "theme", "wallpaper", "updates", "wifi", "bluetooth", "sound", "display"]
    // Panels opened from Settings; back() returns to it.
    readonly property var settingsChildren: ["wifi", "bluetooth", "sound", "display"]
    readonly property var pillStates: ["collapsed", "detail", "musicbar"]
    // Only open while an MPRIS player exists; they close when the last one goes.
    readonly property var musicStates: ["musicbar", "player"]

    property string centreState: "collapsed"
    // The screen whose centre island shows centreState and the OSD; the others stay collapsed.
    property string screenName: ""
    property bool osdVisible: false
    // volume, mic or brightness: what the OSD shows.
    property string osdKind: "volume"
    // The whole bar slid away and its exclusive zone at 0; only the OSD still shows.
    property bool hidden: false
    // The music bar is open by a now-playing peek, not by hover; its timer closes it.
    property bool peeking: false
    readonly property bool panelOpen: panelStates.includes(centreState)
    // Backspace, Alt+Left or a panel's back button returns to Settings.
    readonly property bool canGoBack: settingsChildren.includes(centreState)
    // Niri's focus when the open panel opened or morphed: a move away from it
    // closes the panel.
    property int panelFocusWindow: -1
    property int panelFocusWorkspace: -1

    // Recorded on every open and morph, so a morph keeps the panel open.
    // panelOpen may not have followed centreState yet here.
    onCentreStateChanged: {
        // Logged so journal timings of theme switches can be read against the panel.
        console.info("Shell: centre " + centreState);
        if (panelStates.includes(centreState)) {
            panelFocusWindow = Niri.focusedWindowId;
            panelFocusWorkspace = Niri.focusedWorkspace ? Niri.focusedWorkspace.id : -1;
        }
    }

    function stateOn(name: string): string {
        return name === screenName ? centreState : "collapsed";
    }

    function panelOpenOn(name: string): bool {
        return panelOpen && name === screenName;
    }

    function osdOn(name: string): bool {
        return osdVisible && name === screenName;
    }

    function resolveScreen(name: string): string {
        if (name !== "")
            return name;
        if (screenName !== "")
            return screenName;
        return Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
    }

    function open(state: string, screen: string) {
        if (!panelStates.includes(state) && !pillStates.includes(state)) {
            console.warn("Shell: unknown centre state " + state);
            return;
        }
        if (state === "collapsed") {
            close();
            return;
        }
        if (musicStates.includes(state) && !Music.hasPlayer)
            return;
        if (panelStates.includes(state)) {
            osdVisible = false;
            hidden = false;
        }
        peeking = false;
        screenName = resolveScreen(screen);
        centreState = state;
    }

    function close() {
        peeking = false;
        centreState = "collapsed";
    }

    // Backspace, Alt+Left or the back button in a panel opened from Settings.
    function back() {
        if (canGoBack)
            open("settings", screenName);
    }

    // Shows the music bar for a moment on the focused screen after a track change.
    function peek() {
        if (peeking && centreState === "musicbar") {
            peekTimer.restart();
            return;
        }
        if (!Settings.nowPlayingPeek || Motion.reduceMotion || hidden || osdVisible || centreState !== "collapsed")
            return;
        open("musicbar", ipcScreen());
        if (centreState !== "musicbar")
            return;
        peeking = true;
        peekTimer.restart();
    }

    // The pointer reached the orb or the bar: the hover's leave grace closes it now.
    function endPeek() {
        peeking = false;
        peekTimer.stop();
    }

    function toggle(state: string, screen: string) {
        if (centreState === state && resolveScreen(screen) === screenName)
            close();
        else
            open(state, screen);
    }

    // The OSD has priority: it closes any panel and shows over the collapsed pill.
    function showOsd(screen: string, kind: string) {
        close();
        screenName = resolveScreen(screen);
        osdKind = kind;
        osdVisible = true;
        osdTimer.restart();
    }

    function setHidden(value: bool) {
        if (value)
            close();
        hidden = value;
    }

    // Shortcuts act on the screen with keyboard focus, not on the last one used.
    function ipcScreen(): string {
        return Niri.focusedOutput;
    }

    // A screen that goes away takes its island along: whatever it showed closes,
    // so the services made active below (scanner, discovery, sampling) stop
    // with it.
    function dropMissingScreen() {
        if (centreState !== "collapsed" && screenName !== "" && !Quickshell.screens.some(screen => screen.name === screenName))
            close();
    }

    Connections {
        target: Quickshell

        function onScreensChanged() {
            root.dropMissingScreen();
        }
    }

    // An open panel closes when Niri moves focus to another window or workspace
    // (a shortcut, a new window, the focused window closing). "No window" is
    // ignored: with the panel's Exclusive keyboard focus Niri may report it for
    // the layer's own grab.
    Connections {
        target: Niri

        function onFocusedWindowIdChanged() {
            const id = Niri.focusedWindowId;
            if (root.panelOpen && id >= 0 && id !== root.panelFocusWindow)
                root.close();
        }

        function onFocusedWorkspaceChanged() {
            const workspace = Niri.focusedWorkspace;
            if (root.panelOpen && workspace && workspace.id !== root.panelFocusWorkspace)
                root.close();
        }
    }

    // Every service whose work only a panel shows has `active`, and this is
    // its one owner: every screen has the panels, but only one state is open
    // at a time, and the services never read centreState themselves.
    Binding {
        target: System
        property: "active"
        value: root.centreState === "home"
    }

    Binding {
        target: Brightness
        property: "active"
        value: root.centreState === "settings" || root.centreState === "display"
    }

    Binding {
        target: Audio
        property: "active"
        value: root.centreState === "sound"
    }

    Binding {
        target: Display
        property: "active"
        value: root.centreState === "display"
    }

    Binding {
        target: Network
        property: "active"
        value: root.centreState === "wifi"
    }

    Binding {
        target: Bluetooth
        property: "active"
        value: root.centreState === "bluetooth"
    }

    Binding {
        target: Music
        property: "active"
        value: root.centreState === "player"
    }

    Connections {
        target: Music

        function onHasPlayerChanged() {
            if (!Music.hasPlayer && root.musicStates.includes(root.centreState))
                root.close();
        }

        function onNowPlayingChanged() {
            root.peek();
        }
    }

    Timer {
        id: peekTimer

        interval: Motion.nowPlayingPeekHold
        onTriggered: {
            if (root.peeking && root.centreState === "musicbar")
                root.close();
            root.peeking = false;
        }
    }

    Timer {
        id: osdTimer

        interval: Motion.osdHold
        onTriggered: root.osdVisible = false
    }
}
