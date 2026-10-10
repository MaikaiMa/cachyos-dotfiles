pragma Singleton

import QtQuick
import Quickshell
import ".."

// The Power panel's actions. The panel closes first and the action runs once the
// island has shrunk, so the lock screen or the shutdown never shows it half open.
// Also whether the session is locked, for the notification peek, and the one
// way the bar opens a terminal.
Singleton {
    id: root

    // logind's LockedHint on the user's display session, which DMS sets while its
    // lock screen is up. The session object is the user's Display, not
    // $XDG_SESSION_ID, which a user service need not have. busctl reads the
    // value once, then gdbus streams the session's PropertiesChanged signals:
    // no polling, one idle process.
    property bool locked: false
    readonly property string lockWatchScript: "session=$(busctl --system get-property org.freedesktop.login1 /org/freedesktop/login1/user/self org.freedesktop.login1.User Display | cut -d'\"' -f4) && [ -n \"$session\" ] && busctl --system get-property org.freedesktop.login1 \"$session\" org.freedesktop.login1.Session LockedHint && exec gdbus monitor --system --dest org.freedesktop.login1 --object-path \"$session\""

    readonly property var commands: ({
            lock: ["dms", "ipc", "call", "lock", "lock"],
            suspend: ["systemctl", "suspend"],
            logout: ["niri", "msg", "action", "quit", "--skip-confirmation"],
            reboot: ["systemctl", "reboot"],
            poweroff: ["systemctl", "poweroff"]
        })

    property string pending: ""

    // DMS's terminalOverride, else xdg-terminal-exec, else Ghostty, running argv.
    function terminalCommand(argv: list<string>): list<string> {
        return ["sh", "-c", "terminal=$1; shift; if [ -n \"$terminal\" ]; then exec \"$terminal\" -e \"$@\"; elif command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec \"$@\"; else exec ghostty -e \"$@\"; fi", "sh", Dms.terminal].concat(argv);
    }

    function openInTerminal(argv: list<string>) {
        Quickshell.execDetached(terminalCommand(argv));
    }

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

    // Without a watcher nothing would ever clear `locked`, and a stale true
    // holds every peek back: a watcher that exits resets it. The monitor only
    // exits when logind or the bus goes away.
    LineWatcher {
        name: "Session"
        command: ["sh", "-c", root.lockWatchScript]
        active: true
        onLine: text => root.readLockLine(text)
        onStopped: root.locked = false
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
