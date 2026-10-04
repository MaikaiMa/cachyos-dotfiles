pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pending packages from the repository helper `system-update --pending`
// (read-only), every 30 minutes and on refresh(). Never polls DMS's updater:
// its status call starts a check.
Singleton {
    id: root

    readonly property string helper: Quickshell.env("HOME") + "/.local/bin/system-update"

    // Fragile first: {source (repo, aur, flatpak), name, oldVersion, newVersion, fragile}.
    property var items: []
    readonly property int count: items.length
    readonly property int fragileCount: items.filter(item => item.fragile).length
    readonly property bool checking: pending.running
    property bool ready: false
    property date lastChecked
    // Exit code and output arrive as separate signals in no guaranteed order.
    property var exitCode: null
    property var outputText: null

    function refresh() {
        pending.running = true;
    }

    // One line per package: source<TAB>name<TAB>old<TAB>new<TAB>fragile (0 or 1).
    function parse(text: string) {
        const parsed = [];
        for (const line of text.split("\n")) {
            const fields = line.split("\t");
            if (fields.length !== 5)
                continue;
            parsed.push({
                source: fields[0],
                name: fields[1],
                oldVersion: fields[2],
                newVersion: fields[3],
                fragile: fields[4] === "1"
            });
        }
        items = parsed.filter(item => item.fragile).concat(parsed.filter(item => !item.fragile));
    }

    Timer {
        interval: 30 * 60 * 1000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    function finish() {
        if (exitCode === null || outputText === null)
            return;
        if (exitCode === 0) {
            parse(outputText);
            lastChecked = new Date();
            ready = true;
        } else {
            console.warn("Updates: system-update --pending exited with " + exitCode);
        }
    }

    Process {
        id: pending

        command: [root.helper, "--pending"]
        onStarted: {
            root.exitCode = null;
            root.outputText = null;
        }
        stdout: StdioCollector {
            onStreamFinished: {
                root.outputText = text;
                root.finish();
            }
        }
        // QProcess::ExitStatus is not exposed to qmllint.
        onExited: code => { // qmllint disable signal-handler-parameters
            root.exitCode = code;
            root.finish();
        }
    }
}
