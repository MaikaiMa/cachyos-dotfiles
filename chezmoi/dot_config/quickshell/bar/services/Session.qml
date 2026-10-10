pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The Power panel's actions. The panel closes first and the action runs once the
// island has shrunk, so the lock screen or the shutdown never shows it half open.
// Also whether the session is locked, for the notification peek.
Singleton {
    id: root

    // logind's LockedHint on the user's display session, which DMS sets while its
    // lock screen is up. The session object is the user's Display, not
    // $XDG_SESSION_ID, which a user service need not have. busctl reads the
    // value once, then gdbus streams the session's PropertiesChanged signals:
    // no polling, one idle process.
    property bool locked: false
    readonly property string lockWatchScript: "session=$(busctl --system get-property org.freedesktop.login1 /org/freedesktop/login1/user/self org.freedesktop.login1.User Display | cut -d'\"' -f4) && [ -n \"$session\" ] && busctl --system get-property org.freedesktop.login1 \"$session\" org.freedesktop.login1.Session LockedHint && exec gdbus monitor --system --dest org.freedesktop.login1 --object-path \"$session\""

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

    // "b false" from busctl, then gdbus lines such as
    // ... PropertiesChanged ('org.freedesktop.login1.Session', {'LockedHint': <true>}, @as []).
    function readLockLine(line: string) {
        const match = /^b (true|false)$/.exec(line.trim()) ?? /'LockedHint': <(true|false)>/.exec(line);
        if (match)
            locked = match[1] === "true";
    }

    Process {
        id: lockWatch

        command: ["sh", "-c", root.lockWatchScript]
        running: true
        stdout: SplitParser {
            onRead: data => root.readLockLine(data)
        }
        onRunningChanged: {
            if (!running)
                lockRetry.start();
        }
    }

    // The monitor only exits when logind or the bus goes away; follow it again.
    Timer {
        id: lockRetry

        interval: 5000
        onTriggered: lockWatch.running = true
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
