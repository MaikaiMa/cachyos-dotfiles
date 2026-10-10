pragma Singleton

import QtQuick
import Quickshell

// The XDG roots with their fallbacks and the directories the bar uses. The
// bar's own state and runtime directories are created once, here.
Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string state: Quickshell.env("XDG_STATE_HOME") || home + "/.local/state"
    readonly property string cache: Quickshell.env("XDG_CACHE_HOME") || home + "/.cache"
    readonly property string runtime: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"
    readonly property string localBin: home + "/.local/bin"
    readonly property string barState: state + "/dotfiles-bar"
    readonly property string barRuntime: runtime + "/dotfiles-bar"
    readonly property string dmsCache: cache + "/DankMaterialShell"
    readonly property string dmsState: state + "/DankMaterialShell"
    // Both bar directories exist.
    property bool ready: false

    Command {
        command: ["mkdir", "-p", "--", root.barState, root.barRuntime]
        onFinished: code => {
            root.ready = code === 0;
            if (code !== 0)
                console.warn("Paths: cannot create " + root.barState + " or " + root.barRuntime);
        }
        Component.onCompleted: run()
    }
}
