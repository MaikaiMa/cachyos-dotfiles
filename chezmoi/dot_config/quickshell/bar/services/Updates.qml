pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Pending packages from the repository helper `system-update --pending`
// (read-only), every 30 minutes and on refresh(). Never polls DMS's updater:
// its status call starts a check.
Singleton {
    id: root

    readonly property int checkInterval: 30 * 60 * 1000
    readonly property string helper: Paths.localBin + "/system-update"
    readonly property string reportPath: Paths.state + "/system-update/last-report.md"
    property bool reportAvailable: false
    readonly property bool upgrading: upgrade.running

    // Fragile first: {source (repo, aur, flatpak), name, oldVersion, newVersion, fragile}.
    property var items: []
    readonly property int count: items.length
    readonly property int fragileCount: items.filter(item => item.fragile).length
    readonly property bool checking: pending.running
    property bool ready: false
    property date lastChecked
    // Why the last check failed; empty after a successful one.
    property string error: ""

    // "checked 3 min ago", against now, which the caller ticks while it shows.
    function checkedText(now: real): string {
        const minutes = Math.floor((now - lastChecked.getTime()) / 60000);
        if (minutes < 1)
            return "checked just now";
        if (minutes < 60)
            return "checked " + minutes + " min ago";
        const hours = Math.floor(minutes / 60);
        return "checked " + (hours < 24 ? hours + " h ago" : Math.floor(hours / 24) + " d ago");
    }

    function refresh() {
        pending.run();
        report.reload();
    }

    // Runs the full helper with its fragile prompt in a terminal. Like DMS's
    // own updater the window waits for Enter, so the summary stays readable.
    // Checks again once the terminal is closed.
    function upgradeAll() {
        upgrade.run();
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
        interval: root.checkInterval
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.refresh()
    }

    FileView {
        id: report

        path: root.reportPath
        printErrors: false
        onLoaded: root.reportAvailable = true
        onLoadFailed: root.reportAvailable = false
    }

    Command {
        id: upgrade

        command: Session.terminalCommand(["sh", "-c", "\"$1\"; printf '\\nPress Enter to close. '; read -r _", "sh", root.helper])
        onFinished: code => {
            if (code !== 0)
                console.warn("Updates: the update terminal exited with " + code);
            root.refresh();
        }
    }

    Command {
        id: pending

        command: [root.helper, "--pending"]
        onFinished: (code, output) => {
            if (code === 0) {
                root.parse(output);
                root.lastChecked = new Date();
                root.ready = true;
                root.error = "";
            } else {
                console.warn("Updates: system-update --pending exited with " + code);
                root.error = code < 0 ? "Check failed: system-update not found" : "Check failed (exit " + code + ")";
            }
        }
    }
}
