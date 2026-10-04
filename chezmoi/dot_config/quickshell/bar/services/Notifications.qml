pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The notification list, read from the history file DMS keeps; DMS owns the
// notification daemon. DMS's IPC cannot remove history entries (its `dismiss`
// closes the newest popup, `clearAll` clears active notifications), so what the
// bar dismissed is remembered in its own state file and filtered out here.
Singleton {
    id: root

    readonly property string historyPath: (Quickshell.env("XDG_CACHE_HOME") || Quickshell.env("HOME") + "/.cache") + "/DankMaterialShell/notification_history.json"
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/dotfiles-bar"

    // Newest first: {id, appName, summary, body, timestamp (ms), appIcon, image, urgency, desktopEntry}.
    property var history: []
    property var dismissedIds: []
    // Entries at or before this time (ms) were cleared with clearAll().
    property real clearedBefore: 0
    readonly property var items: history.filter(item => item.timestamp > clearedBefore && !dismissedIds.includes(item.id))
    readonly property int count: items.length

    // Name keys of the apps with a notification younger than recentWindow, for the
    // workspace pills; `now` ticks so entries age out without a new notification.
    readonly property real recentWindow: 10 * 60 * 1000
    property real now: Date.now()
    readonly property var recentAppKeys: {
        const keys = new Set();
        for (const item of items) {
            if (item.timestamp < now - recentWindow)
                continue;
            for (const key of appKeys(item.appName).concat(appKeys(item.desktopEntry)))
                keys.add(key);
        }
        return keys;
    }

    // Ported from the DMS plugins' NotificationMatcher: notifications name an app
    // ("Claude", "com.anthropic.Claude.desktop") and windows an app_id
    // ("com.anthropic.Claude"), so both reduce to the whole name and its last
    // dotted part, lower case, letters and digits only.
    function appKeys(value: string): var {
        let name = value.toLowerCase().trim();
        if (name.endsWith(".desktop"))
            name = name.slice(0, -8);
        const full = name.replace(/[^a-z0-9]/g, "");
        const tail = name.slice(name.lastIndexOf(".") + 1).replace(/[^a-z0-9]/g, "");
        const keys = full ? [full] : [];
        if (tail && tail !== full)
            keys.push(tail);
        return keys;
    }

    function hasRecentFor(appId: string): bool {
        const keys = recentAppKeys;
        return appKeys(appId).some(key => keys.has(key));
    }

    function dismiss(id: string) {
        if (dismissedIds.includes(id))
            return;
        dismissedIds = dismissedIds.concat([id]);
        saveState();
    }

    function clearAll() {
        clearedBefore = history.reduce((latest, item) => Math.max(latest, item.timestamp), Date.now());
        dismissedIds = [];
        saveState();
        Quickshell.execDetached(["dms", "ipc", "call", "notifications", "clearAll"]);
    }

    function parseHistory(text: string) {
        let file;
        try {
            file = JSON.parse(text);
        } catch (error) {
            console.warn("Notifications: cannot parse " + historyPath + ": " + error);
            history = [];
            return;
        }
        const list = Array.isArray(file.notifications) ? file.notifications : [];
        history = list.filter(entry => entry && entry.id !== undefined).map(entry => ({
                    id: String(entry.id),
                    appName: entry.appName ?? "",
                    summary: entry.summary ?? "",
                    body: entry.body ?? "",
                    timestamp: Number(entry.timestamp) || 0,
                    appIcon: entry.appIcon ?? "",
                    image: entry.image ?? "",
                    urgency: Number(entry.urgency) || 0,
                    desktopEntry: entry.desktopEntry ?? ""
                })).sort((a, b) => b.timestamp - a.timestamp);
        // Forget dismissals of entries DMS has pruned.
        const known = history.map(item => item.id);
        const kept = dismissedIds.filter(id => known.includes(id));
        if (kept.length !== dismissedIds.length) {
            dismissedIds = kept;
            saveState();
        }
    }

    function parseState(text: string) {
        try {
            const state = JSON.parse(text);
            dismissedIds = Array.isArray(state.dismissedIds) ? state.dismissedIds.map(String) : [];
            clearedBefore = Number(state.clearedBefore) || 0;
        } catch (error) {
            console.warn("Notifications: ignoring unreadable " + stateFile.path + ": " + error);
        }
    }

    function saveState() {
        stateFile.setText(JSON.stringify({
            dismissedIds: dismissedIds,
            clearedBefore: clearedBefore
        }) + "\n");
    }

    FileView {
        id: historyFile

        path: root.historyPath
        watchChanges: true
        printErrors: false
        onLoaded: root.parseHistory(text())
        onFileChanged: reload()
        // A missing file is an empty list; the watch needs the file, so look again later.
        onLoadFailed: {
            root.history = [];
            retry.restart();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: true
        onTriggered: root.now = Date.now()
    }

    Timer {
        id: retry

        interval: 5000
        onTriggered: historyFile.reload()
    }

    FileView {
        id: stateFile

        path: root.stateDir + "/notifications.json"
        printErrors: false
        onLoaded: root.parseState(text())
    }

    Process {
        command: ["mkdir", "-p", root.stateDir]
        running: true
    }
}
