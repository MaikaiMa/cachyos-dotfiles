pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The bar's own runtime switches, kept across restarts in
// $XDG_STATE_HOME/dotfiles-bar/settings.json. A missing or unreadable file
// leaves the defaults.
Singleton {
    id: root

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/dotfiles-bar"

    property bool waveEnabled: true

    function setWaveEnabled(enabled: bool) {
        waveEnabled = enabled;
        save();
    }

    function parse(text: string) {
        try {
            const stored = JSON.parse(text);
            if (typeof stored.waveEnabled === "boolean")
                waveEnabled = stored.waveEnabled;
        } catch (error) {
            console.warn("Settings: ignoring unreadable " + file.path + ": " + error);
        }
    }

    function save() {
        file.setText(JSON.stringify({
            waveEnabled: waveEnabled
        }, null, 2) + "\n");
    }

    FileView {
        id: file

        path: root.stateDir + "/settings.json"
        printErrors: false
        onLoaded: root.parse(text())
    }

    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }
}
