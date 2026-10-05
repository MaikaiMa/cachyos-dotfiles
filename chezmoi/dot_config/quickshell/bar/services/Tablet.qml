pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The Z13 used as a tablet (docs/tablet.md): whether the keyboard cover is
// detached, whether squeekboard is on screen, and the rotation lock. The
// helpers in ~/.local/bin own the state; this only follows and calls them.
Singleton {
    id: root

    readonly property string binDir: Quickshell.env("HOME") + "/.local/bin"
    readonly property string lockFile: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/dotfiles/rotation-lock"

    property bool detached: false
    property bool keyboardVisible: false
    property bool rotationLocked: false

    function toggleKeyboard() {
        Quickshell.execDetached([binDir + "/osk", "toggle"]);
    }

    function toggleRotationLock() {
        lockToggle.running = true;
    }

    // The lock can also change from a terminal; the Settings panel re-reads it on open.
    function refresh() {
        lockState.reload();
    }

    // Re-attaching the cover hides the keyboard, as the old bar button did.
    onDetachedChanged: {
        if (!detached)
            Quickshell.execDetached([binDir + "/osk", "hide"]);
    }

    // "tablet" or "laptop", now and on every change.
    LineWatcher {
        command: [root.binDir + "/tablet-mode", "watch"]
        active: true
        onLine: text => root.detached = text === "tablet"
    }

    // "visible" or "hidden"; only needed while the keyboard button shows.
    LineWatcher {
        command: [root.binDir + "/osk", "watch"]
        active: root.detached
        onLine: text => root.keyboardVisible = text === "visible"
        onActiveChanged: {
            if (!active)
                root.keyboardVisible = false;
        }
    }

    Process {
        id: lockToggle

        command: [root.binDir + "/auto-rotate", "lock", "toggle"]
        onRunningChanged: {
            if (!running)
                lockState.reload();
        }
    }

    // "locked" or "unlocked"; a missing file is unlocked.
    FileView {
        id: lockState

        path: root.lockFile
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.rotationLocked = text().trim() === "locked"
        onLoadFailed: root.rotationLocked = false
    }

    // A long-running helper that prints one state per line. The watchers only
    // exit when their monitor fails; retry instead of freezing the state.
    component LineWatcher: Scope {
        id: watcher

        property var command: []
        property bool active: false

        signal line(string text)

        Process {
            id: process

            command: watcher.command
            running: watcher.active
            stdout: SplitParser {
                onRead: data => watcher.line(data.trim())
            }
            onRunningChanged: {
                if (!running && watcher.active)
                    restart.start();
            }
        }

        Timer {
            id: restart

            interval: 5000
            onTriggered: process.running = watcher.active
        }
    }
}
