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
    readonly property string reportPath: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/system-update/last-report.md"
    property bool reportAvailable: false
    readonly property bool upgrading: upgrade.running

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
        report.reload();
    }

    function quoted(text: string): string {
        return "'" + text.replace(/'/g, "'\\''") + "'";
    }

    // Runs the full helper with its fragile prompt in a terminal: DMS's
    // terminalOverride, else xdg-terminal-exec, else Ghostty. Like DMS's own
    // updater the window waits for Enter, so the summary stays readable.
    // Checks again once the terminal is closed.
    function upgradeAll() {
        if (upgrade.running)
            return;
        const script = root.quoted(root.helper) + "; printf '\\nPress Enter to close. '; read -r _";
        upgrade.command = ["sh", "-c", "if [ -n \"$1\" ]; then exec \"$1\" -e sh -c \"$2\"; elif command -v xdg-terminal-exec >/dev/null 2>&1; then exec xdg-terminal-exec sh -c \"$2\"; else exec ghostty -e sh -c \"$2\"; fi", "sh", Dms.terminal, script];
        upgrade.running = true;
    }

    function openReport() {
        Quickshell.execDetached(["xdg-open", reportPath]);
    }

    // One line per package: source<TAB>name<TAB>old<TAB>new<TAB>fragile (0 or
    // 1)<TAB>reason ("-" unless fragile). An older helper prints no reason.
    function parse(text: string) {
        const parsed = [];
        for (const line of text.split("\n")) {
            const fields = line.split("\t");
            if (fields.length !== 5 && fields.length !== 6)
                continue;
            parsed.push({
                source: fields[0],
                name: fields[1],
                oldVersion: fields[2],
                newVersion: fields[3],
                fragile: fields[4] === "1",
                reason: fields.length === 6 && fields[5] !== "-" ? fields[5] : ""
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

    FileView {
        id: report

        path: root.reportPath
        printErrors: false
        onLoaded: root.reportAvailable = true
        onLoadFailed: root.reportAvailable = false
    }

    Process {
        id: upgrade

        // QProcess::ExitStatus is not exposed to qmllint.
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0)
                console.warn("Updates: the update terminal exited with " + code);
            root.refresh();
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
