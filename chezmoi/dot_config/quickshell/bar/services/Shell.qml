pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The one state machine of the centre island, shared by every screen.
Singleton {
    id: root

    readonly property var panelStates: ["home", "settings", "player", "power", "theme", "wallpaper", "updates"]
    readonly property var pillStates: ["collapsed", "detail", "musicbar"]
    // Only open while an MPRIS player exists; they close when the last one goes.
    readonly property var musicStates: ["musicbar", "player"]

    property string centreState: "collapsed"
    // The screen whose centre island shows centreState and the OSD; the others stay collapsed.
    property string screenName: ""
    property bool osdVisible: false
    readonly property bool panelOpen: panelStates.includes(centreState)

    function stateOn(name: string): string {
        return name === screenName ? centreState : "collapsed";
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
        if (panelStates.includes(state))
            osdVisible = false;
        screenName = resolveScreen(screen);
        centreState = state;
    }

    function close() {
        centreState = "collapsed";
    }

    function toggle(state: string, screen: string) {
        if (centreState === state && resolveScreen(screen) === screenName)
            close();
        else
            open(state, screen);
    }

    // The OSD has priority: it closes any panel and shows over the collapsed pill.
    function showOsd(screen: string) {
        close();
        screenName = resolveScreen(screen);
        osdVisible = true;
        osdTimer.restart();
    }

    // One owner for the sampling switch: every screen has a Home panel, but only
    // one state is open at a time.
    Binding {
        target: System
        property: "active"
        value: root.centreState === "home"
    }

    Connections {
        target: Music

        function onHasPlayerChanged() {
            if (!Music.hasPlayer && root.musicStates.includes(root.centreState))
                root.close();
        }
    }

    Timer {
        id: osdTimer

        interval: 1500
        onTriggered: root.osdVisible = false
    }

    // Lets panels open without a pointer, as the Niri shortcuts will:
    // quickshell ipc -c bar call bar toggle home
    IpcHandler {
        target: "bar"

        function open(state: string): void {
            root.open(state, "");
        }

        function toggle(state: string): void {
            root.toggle(state, "");
        }

        function close(): void {
            root.close();
        }

        function osd(): void {
            root.showOsd("");
        }

        function state(): string {
            return root.centreState + " on " + root.screenName;
        }
    }
}
