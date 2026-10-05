pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The notification list, read from the history file DMS keeps; DMS owns the
// notification daemon. DMS's IPC cannot remove history entries (its `dismiss`
// closes the newest popup, `clearAll` clears active notifications), so what the
// bar dismissed is remembered in its own state file and filtered out here.
// A notification lights its app's workspace pill until it is ten minutes old,
// dismissed, or seen: its workspace kept focus for Motion.alertClearDelay.
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

    // Notifications younger than recentWindow and not yet seen, and the name keys
    // of their apps, for the workspace pills; `now` ticks so entries age out
    // without a new notification.
    readonly property real recentWindow: 10 * 60 * 1000
    property real now: Date.now()
    property var seenIds: []
    readonly property var alerts: items.filter(item => item.timestamp >= now - recentWindow && !seenIds.includes(item.id))
    readonly property var recentAppKeys: {
        const keys = new Set();
        for (const item of alerts)
            for (const key of itemKeys(item))
                keys.add(key);
        return keys;
    }

    // The alerts of the apps with a window on the focused workspace. The key is a
    // string, so a window change that leaves them alone does not restart the delay.
    readonly property var focusedAlertIds: {
        const workspace = Niri.focusedWorkspace;
        if (!workspace)
            return [];
        const keys = new Set();
        for (const window of Niri.windowsOn(workspace.id))
            for (const key of appKeys(window.appId))
                keys.add(key);
        return alerts.filter(item => itemKeys(item).some(key => keys.has(key))).map(item => item.id);
    }
    readonly property string focusedAlertKey: Niri.focusedWorkspace && focusedAlertIds.length > 0 ? Niri.focusedWorkspace.id + ":" + focusedAlertIds.join(",") : ""

    // Ported from the DMS apps plugin: a new focus or a new alert restarts the
    // delay, so passing through a workspace clears nothing.
    onFocusedAlertKeyChanged: {
        if (focusedAlertKey === "")
            alertClear.stop();
        else
            alertClear.restart();
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

    function itemKeys(item: var): var {
        return appKeys(item.appName).concat(appKeys(item.desktopEntry));
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

    function markSeen(ids: var) {
        const fresh = ids.filter(id => !seenIds.includes(id));
        if (fresh.length === 0)
            return;
        seenIds = seenIds.concat(fresh);
        saveState();
    }

    function clearAll() {
        clearedBefore = history.reduce((latest, item) => Math.max(latest, item.timestamp), Date.now());
        dismissedIds = [];
        seenIds = [];
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
        // Forget dismissals and seen marks of entries DMS has pruned.
        const known = history.map(item => item.id);
        const kept = dismissedIds.filter(id => known.includes(id));
        const keptSeen = seenIds.filter(id => known.includes(id));
        if (kept.length !== dismissedIds.length || keptSeen.length !== seenIds.length) {
            dismissedIds = kept;
            seenIds = keptSeen;
            saveState();
        }
    }

    function parseState(text: string) {
        try {
            const state = JSON.parse(text);
            dismissedIds = Array.isArray(state.dismissedIds) ? state.dismissedIds.map(String) : [];
            seenIds = Array.isArray(state.seenIds) ? state.seenIds.map(String) : [];
            clearedBefore = Number(state.clearedBefore) || 0;
        } catch (error) {
            console.warn("Notifications: ignoring unreadable " + stateFile.path + ": " + error);
        }
    }

    function saveState() {
        stateFile.setText(JSON.stringify({
            dismissedIds: dismissedIds,
            seenIds: seenIds,
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
        id: alertClear

        interval: Motion.alertClearDelay
        onTriggered: root.markSeen(root.focusedAlertIds)
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
