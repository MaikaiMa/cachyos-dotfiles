pragma Singleton

import QtQuick
import Quickshell
import ".."

// The Power panel's actions. The panel closes first and the action runs once the
// island has shrunk, so the lock screen or the shutdown never shows it half open.
Singleton {
    id: root

    readonly property var actions: ["lock", "suspend", "logout", "reboot", "poweroff"]
    readonly property var commands: ({
            lock: ["dms", "ipc", "call", "lock", "lock"],
            suspend: ["systemctl", "suspend"],
            logout: ["niri", "msg", "action", "quit", "--skip-confirmation"],
            reboot: ["systemctl", "reboot"],
            poweroff: ["systemctl", "poweroff"]
        })

    property string pending: ""

    function perform(action: string) {
        if (!commands[action]) {
            console.warn("Session: unknown action " + action);
            return;
        }
        pending = action;
        Shell.close();
        delay.restart();
    }

    Timer {
        id: delay

        interval: Math.max(1, Motion.shrinkDuration)
        onTriggered: {
            Quickshell.execDetached(root.commands[root.pending]);
            root.pending = "";
        }
    }
}
