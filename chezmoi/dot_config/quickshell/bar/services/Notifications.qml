pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."

// The bar is the notification daemon of the Niri session (ADR-0028). Quickshell's
// server holds the live notifications; the history, the seen marks and do not
// disturb live in the bar's own state file. A notification lights its app's
// workspace pill until it is ten minutes old, dismissed, or seen: its workspace
// kept focus for alertClearDelay. The peek stack lives here as well, one
// for all screens, shown on the screen that had focus when it started.
Singleton {
    id: root

    readonly property int historyLimit: 200
    readonly property real historyAge: 7 * 24 * 60 * 60 * 1000
    // The history is written at most this often.
    readonly property int saveInterval: 1000
    // A workspace's notification colour clears this long after it gains focus.
    readonly property int alertClearDelay: 3000

    // Newest first: {id, serverId, appName, summary, body, appIcon, image,
    // desktopEntry, urgency, timestamp (ms), seen}. Transient notifications are
    // never in it. Image paths only: raw image data does not outlive the process.
    property var entries: []
    property bool doNotDisturb: false
    // Until the state file has been read, a save would drop the history.
    property bool loaded: false

    // The server's id of every live notification to its entry id. Notification
    // ids start again at 1 with every bar process, so entries get their own.
    // Always replaced, never edited, so the bindings below follow it.
    property var keyByServerId: ({})
    readonly property var liveNotifications: server.trackedNotifications.values
    readonly property var liveIds: liveNotifications.map(notification => keyByServerId[notification.id] ?? "")

    // `live`: the sender's notification still exists, so its actions and reply work.
    readonly property var items: entries.map(entry => Object.assign({}, entry, {
                live: liveIds.includes(entry.id)
            }))
    readonly property int count: items.length
    // The bell counts what is neither peeking nor a blob: they join the count
    // when the stack morphs back into the bell.
    readonly property int bellCount: items.filter(item => !peekIds.includes(item.id) && !blobIds.includes(item.id)).length
    readonly property var seenIds: entries.filter(entry => entry.seen).map(entry => entry.id)

    // Notifications younger than recentWindow and not yet seen, and the name keys
    // of their apps, for the workspace pills; `now` ticks so entries age out
    // without a new notification.
    readonly property real recentWindow: 10 * 60 * 1000
    property real now: Date.now()
    readonly property var alerts: items.filter(item => item.timestamp >= now - recentWindow && !item.seen)
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

    // Peek rows, newest first; "backlog" is the combined row for what arrived
    // while the bar was hidden or the session locked.
    readonly property string backlogRow: "backlog"
    property var peekIds: []
    // Rows that left the stack while others stayed, newest first, drawn as disc
    // blobs under the island until the stack ends.
    property var blobIds: []
    property string peekScreen: ""
    property int backlogCount: 0
    property var backlogIds: []
    // Arrivals wait for the bar to come back, or go straight to the count.
    readonly property bool peekDeferred: Shell.hidden || Session.locked
    readonly property bool peekBlocked: Shell.panelOpen || Niri.focusedFullscreen

    // A sender updated a notification in place (replaces_id).
    signal replaced(string id)

    // Ported from the DMS apps plugin: a new focus or a new alert restarts the
    // delay, so passing through a workspace clears nothing.
    onFocusedAlertKeyChanged: {
        if (focusedAlertKey === "")
            alertClear.stop();
        else
            alertClear.restart();
    }

    onPeekDeferredChanged: {
        if (!peekDeferred)
            Qt.callLater(showBacklog);
    }

    // An open panel covers the right island; what was peeking is in the list.
    onPeekBlockedChanged: {
        if (peekBlocked)
            clearPeeks();
    }

    // Ported from the DMS plugins' NotificationMatcher: notifications name an app
    // ("Claude", "com.anthropic.Claude.desktop") and windows an app_id
    // ("com.anthropic.Claude"), so both reduce to the whole name and its last
    // dotted part, lower case, letters and digits only.
    // The stack's rows and blobs as one screen sees them, like Shell.stateOn.
    function peekIdsOn(screen: string): var {
        return peekScreen === screen ? peekIds : [];
    }

    function blobIdsOn(screen: string): var {
        return peekScreen === screen ? blobIds : [];
    }

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
        return appKeys(item.appName ?? "").concat(appKeys(item.desktopEntry ?? ""));
    }

    function hasRecentFor(appId: string): bool {
        const keys = recentAppKeys;
        return appKeys(appId).some(key => keys.has(key));
    }

    // The live Notification of an entry or a transient peek, or null.
    function liveObject(id: string): var {
        return liveNotifications.find(notification => keyByServerId[notification.id] === id) ?? null;
    }

    function entryFor(id: string): var {
        return entries.find(entry => entry.id === id) ?? null;
    }

    // Bodies may carry the basic markup of the notification spec and line breaks.
    function plainText(text: string): string {
        return text.replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&quot;/g, "\"").replace(/&apos;/g, "'").replace(/&amp;/g, "&");
    }

    function oneLine(text: string): string {
        return plainText(text).replace(/\s+/g, " ").trim();
    }

    // The app's own icon first; the notification image is often content (an
    // avatar, a screenshot) and only stands in when the app has none.
    function iconSource(appIcon: string, desktopEntry: string, image: string): string {
        for (const candidate of [appIcon, desktopEntry]) {
            if (candidate === "")
                continue;
            if (/^(\/|[a-z]+:)/.test(candidate))
                return candidate.startsWith("/") ? "file://" + candidate : candidate;
            const path = Quickshell.iconPath(candidate, true);
            if (path !== "")
                return path;
        }
        return image;
    }

    // Quickshell hands an image-path hint over as image://icon/<path or name>
    // and raw image data as a URL of its own provider, which dies with the
    // process; only the first is kept in the history.
    function storedImage(image: string): string {
        if (image.startsWith("image://icon/")) {
            const payload = image.slice("image://icon/".length);
            return payload.startsWith("/") ? "file://" + payload : image;
        }
        if (image.startsWith("/"))
            return "file://" + image;
        return image.startsWith("file://") ? image : "";
    }

    function entryFrom(notification: var, id: string): var {
        return {
            id: id,
            serverId: notification.id,
            appName: notification.appName ?? "",
            summary: notification.summary ?? "",
            body: notification.body ?? "",
            appIcon: notification.appIcon ?? "",
            image: storedImage(notification.image ?? ""),
            desktopEntry: notification.desktopEntry ?? "",
            urgency: Number(notification.urgency) || 0,
            timestamp: Date.now(),
            seen: false
        };
    }

    // The actions shown as pills: the default action first, under its own
    // label or "Open", then the others in the sender's order.
    function pillActions(notification: var): var {
        if (!notification)
            return [];
        const actions = notification.actions ?? [];
        const defaults = actions.filter(action => action.identifier === "default");
        const others = actions.filter(action => action.identifier !== "default");
        return defaults.map(action => ({
                    identifier: action.identifier,
                    text: action.text && action.text !== "default" ? action.text : "Open",
                    primary: true
                })).concat(others.map(action => ({
                    identifier: action.identifier,
                    text: action.text || action.identifier,
                    primary: false
                })));
    }

    function hasDefaultAction(id: string): bool {
        const notification = liveObject(id);
        return !!notification && (notification.actions ?? []).some(action => action.identifier === "default");
    }

    // How long a peek row holds, in ms; 0 holds until it is clicked or dismissed.
    function holdFor(id: string): int {
        const notification = id === backlogRow ? null : liveObject(id);
        if (!notification)
            return Motion.notificationHoldNormal;
        if (notification.urgency === NotificationUrgency.Critical)
            return 0;
        const timeout = Number(notification.expireTimeout);
        if (timeout > 0)
            return Math.max(Motion.notificationHoldMin, Math.min(Motion.notificationHoldMax, Math.round(timeout)));
        return notification.urgency === NotificationUrgency.Low ? Motion.notificationHoldLow : Motion.notificationHoldNormal;
    }

    function newKey(serverId: int): string {
        return Date.now().toString(36) + "-" + serverId;
    }

    function setKey(serverId: int, id: string) {
        const keys = Object.assign({}, keyByServerId);
        if (id === "")
            delete keys[serverId];
        else
            keys[serverId] = id;
        keyByServerId = keys;
    }

    function receive(notification: var) {
        if (keyByServerId[notification.id] !== undefined) {
            notification.tracked = true;
            scheduleRefresh(notification.id);
            return;
        }
        // The key first: tracking publishes the notification to liveIds.
        const id = newKey(notification.id);
        setKey(notification.id, id);
        notification.tracked = true;
        if (!notification.transient) {
            entries = [entryFrom(notification, id)].concat(entries);
            scheduleSave();
        }
        offerPeek(id, notification);
    }

    // A sender's replaces_id arrives as changed properties on the same object.
    // Only a new summary or urgency alerts again; progress senders rewrite the
    // body every second and keep their place, time and seen mark.
    function refresh(serverId: int) {
        const id = keyByServerId[serverId];
        const notification = id === undefined ? null : liveObject(id);
        if (!notification)
            return;
        const current = entryFor(id);
        if (current) {
            const next = entryFrom(notification, id);
            if (next.summary !== current.summary || next.urgency !== current.urgency) {
                entries = [next].concat(entries.filter(entry => entry.id !== id));
                scheduleSave();
            } else if (next.body !== current.body || next.appIcon !== current.appIcon || next.image !== current.image) {
                next.timestamp = current.timestamp;
                next.seen = current.seen;
                entries = entries.map(entry => entry.id === id ? next : entry);
                scheduleSave();
            }
        }
        replaced(id);
    }

    function scheduleRefresh(serverId: int) {
        if (!refreshTimer.pending.includes(serverId))
            refreshTimer.pending = refreshTimer.pending.concat([serverId]);
        refreshTimer.restart();
    }

    // The sender closed it, or the bar did: what is left is history.
    function liveGone(serverId: int) {
        const id = keyByServerId[serverId];
        if (id === undefined)
            return;
        setKey(serverId, "");
        removePeek(id);
    }

    // A transient that does not peek now never will, so it ends here; after
    // the server has taken it, not inside its own arrival.
    function offerPeek(id: string, notification: var) {
        const wanted = Settings.notificationPeek && (!doNotDisturb || notification.urgency === NotificationUrgency.Critical);
        if (wanted && !peekDeferred && !peekBlocked) {
            pushPeek(id);
            return;
        }
        if (notification.transient)
            Qt.callLater(() => root.retireTransient(id));
        else if (wanted && peekDeferred)
            backlogIds = backlogIds.concat([id]);
    }

    // A fourth row pushes the bottom one out early, as a blob.
    function pushPeek(id: string) {
        if (peekIds.length === 0)
            peekScreen = Niri.focusedOutput !== "" ? Niri.focusedOutput : Quickshell.screens.length > 0 ? Quickshell.screens[0].name : "";
        const next = [id].concat(peekIds.filter(row => row !== id));
        const dropped = next.slice(Theme.notificationPeekMaxRows);
        addBlobs(dropped);
        peekIds = next.slice(0, Theme.notificationPeekMaxRows);
        dropped.forEach(retireTransient);
    }

    // Before the rows change, so a leaving row already knows it becomes a blob.
    // Only list entries become blobs: not the combined row, not transients.
    function addBlobs(ids: var) {
        const fresh = ids.filter(id => id !== backlogRow && entryFor(id) !== null && !blobIds.includes(id));
        if (fresh.length > 0)
            blobIds = fresh.concat(blobIds);
    }

    // The last row leaving ends the stack, and its blobs with it.
    function removePeek(id: string) {
        if (!peekIds.includes(id))
            return;
        const rest = peekIds.filter(row => row !== id);
        if (rest.length === 0)
            blobIds = [];
        peekIds = rest;
    }

    // A peek row's hold ended: with other rows left it breaks out as a blob.
    function expirePeek(id: string) {
        if (peekIds.length > 1 && peekIds.includes(id))
            addBlobs([id]);
        endPeek(id);
    }

    // A peek row was clicked or dismissed: it leaves without a blob.
    function endPeek(id: string) {
        removePeek(id);
        retireTransient(id);
    }

    // A blob's click brings it back as the top row with a fresh hold. It leaves
    // the blobs only once its row is in, so the blob knows to rise into it, and
    // a row it pushes out becomes a blob as usual.
    function repeek(id: string) {
        if (!blobIds.includes(id) || peekIds.length === 0)
            return;
        pushPeek(id);
        blobIds = blobIds.filter(blob => blob !== id);
    }

    function clearPeeks() {
        const rows = peekIds;
        blobIds = [];
        peekIds = [];
        rows.forEach(retireTransient);
    }

    // A transient notification is over once its peek is.
    function retireTransient(id: string) {
        if (entryFor(id))
            return;
        const notification = liveObject(id);
        if (notification)
            notification.expire();
    }

    function showBacklog() {
        const waiting = backlogIds.filter(id => entryFor(id) !== null);
        backlogIds = [];
        if (waiting.length === 0 || peekDeferred || peekBlocked)
            return;
        backlogCount = waiting.length;
        pushPeek(backlogRow);
    }

    function dismiss(id: string) {
        const notification = liveObject(id);
        if (entryFor(id)) {
            entries = entries.filter(entry => entry.id !== id);
            scheduleSave();
        }
        blobIds = blobIds.filter(blob => blob !== id);
        removePeek(id);
        if (notification)
            notification.dismiss();
    }

    function markSeen(ids: var) {
        if (!entries.some(entry => !entry.seen && ids.includes(entry.id)))
            return;
        entries = entries.map(entry => !entry.seen && ids.includes(entry.id) ? Object.assign({}, entry, {
                seen: true
            }) : entry);
        scheduleSave();
    }

    // Everything: the list, the rows and the blobs, nothing left counted.
    function clearAll() {
        dismissWithStack(entries.map(entry => entry.id).concat(peekIds, blobIds));
    }

    // The stack's clear-all: its rows and blobs, the rest of the list stays.
    // The combined row only ends; what it stands for was never shown.
    function clearStack() {
        dismissWithStack(peekIds.concat(blobIds));
    }

    // Live ones close with reason "dismissed by user", historic ones leave the
    // history, and the stack ends.
    function dismissWithStack(ids: var) {
        const unique = Array.from(new Set(ids)).filter(id => id !== backlogRow);
        const live = unique.map(liveObject).filter(notification => notification !== null);
        entries = entries.filter(entry => !unique.includes(entry.id));
        blobIds = [];
        peekIds = [];
        scheduleSave();
        live.forEach(notification => notification.dismiss());
    }

    // Runs one of the sender's actions; the caller decides whether it closes.
    function invoke(id: string, identifier: string): bool {
        const notification = liveObject(id);
        const action = notification ? (notification.actions ?? []).find(candidate => candidate.identifier === identifier) : null;
        if (!action)
            return false;
        markSeen([id]);
        action.invoke();
        return true;
    }

    function isResident(id: string): bool {
        const notification = liveObject(id);
        return !!notification && notification.resident;
    }

    // The peek's verbs: an action, the reply or the row's text; each closes the
    // notification with reason "dismissed by user" unless the sender marked it resident.
    function activate(id: string, identifier: string) {
        const resident = isResident(id);
        invoke(id, identifier);
        endPeek(id);
        if (!resident)
            dismiss(id);
    }

    function reply(id: string, text: string): bool {
        const notification = liveObject(id);
        if (!notification || !notification.hasInlineReply || text === "")
            return false;
        markSeen([id]);
        notification.sendInlineReply(text);
        return true;
    }

    // Without a default action the row's text brings the app's window forward.
    function open(id: string) {
        if (hasDefaultAction(id)) {
            activate(id, "default");
            return;
        }
        const notification = liveObject(id);
        const item = entryFor(id) ?? (notification ? {
                appName: notification.appName,
                desktopEntry: notification.desktopEntry
            } : null);
        if (item) {
            const keys = itemKeys(item);
            const window = Niri.windows.find(candidate => appKeys(candidate.appId).some(key => keys.includes(key)));
            if (window)
                Niri.focusWindow(window.id);
        }
        markSeen([id]);
        const resident = isResident(id);
        endPeek(id);
        if (!resident)
            dismiss(id);
    }

    function setDoNotDisturb(enabled: bool) {
        if (doNotDisturb === enabled)
            return;
        doNotDisturb = enabled;
        scheduleSave();
    }

    function toggleDoNotDisturb() {
        setDoNotDisturb(!doNotDisturb);
    }

    // At most historyLimit entries and nothing older than historyAge; a live
    // notification that falls out expires.
    function prune() {
        const cutoff = Date.now() - historyAge;
        const kept = entries.filter(entry => entry.timestamp >= cutoff).slice(0, historyLimit);
        if (kept.length === entries.length)
            return;
        const dropped = entries.filter(entry => !kept.includes(entry));
        entries = kept;
        for (const entry of dropped) {
            const notification = liveObject(entry.id);
            if (notification)
                notification.expire();
        }
    }

    function normalise(entry: var): var {
        return {
            id: String(entry.id),
            serverId: Number(entry.serverId) || 0,
            appName: String(entry.appName ?? ""),
            summary: String(entry.summary ?? ""),
            body: String(entry.body ?? ""),
            appIcon: String(entry.appIcon ?? ""),
            image: String(entry.image ?? ""),
            desktopEntry: String(entry.desktopEntry ?? ""),
            urgency: Number(entry.urgency) || 0,
            timestamp: Number(entry.timestamp) || 0,
            seen: entry.seen === true
        };
    }

    // Notifications that arrived before the file was read stay in front.
    function parseState(text: string) {
        try {
            const state = JSON.parse(text);
            doNotDisturb = state.doNotDisturb === true;
            const stored = Array.isArray(state.notifications) ? state.notifications : [];
            const known = entries.map(entry => entry.id);
            const restored = stored.filter(entry => entry && entry.id !== undefined).map(normalise).filter(entry => !known.includes(entry.id));
            entries = entries.concat(restored).sort((a, b) => b.timestamp - a.timestamp);
        } catch (error) {
            console.warn("Notifications: ignoring unreadable " + stateFile.path + ": " + error);
        }
        finishLoading();
    }

    function finishLoading() {
        loaded = true;
        prune();
        relink();
    }

    // After a config reload the server keeps its notifications (keepOnReload)
    // without announcing them again; they get their entries back by id and text.
    function relink() {
        for (const notification of liveNotifications) {
            if (keyByServerId[notification.id] !== undefined)
                continue;
            const match = entries.find(entry => entry.serverId === notification.id && entry.summary === notification.summary && entry.appName === notification.appName);
            if (match) {
                setKey(notification.id, match.id);
            } else if (notification.transient) {
                notification.expire();
            } else {
                const id = newKey(notification.id);
                setKey(notification.id, id);
                entries = [entryFrom(notification, id)].concat(entries);
                scheduleSave();
            }
        }
    }

    function scheduleSave() {
        if (!saveTimer.running)
            saveTimer.start();
    }

    function writeState() {
        prune();
        stateFile.setText(JSON.stringify({
            doNotDisturb: doNotDisturb,
            notifications: entries
        }) + "\n");
    }

    Component.onDestruction: {
        if (saveTimer.running && loaded)
            writeState();
    }

    NotificationServer {
        id: server

        keepOnReload: true
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        inlineReplySupported: true
        persistenceSupported: true
        onNotification: notification => root.receive(notification)
    }

    Connections {
        target: server.trackedNotifications

        function onObjectRemovedPre(object: QtObject, index: int) {
            root.liveGone((object as Notification).id);
        }
    }

    // One watcher per live notification for in-place updates.
    Instantiator {
        model: server.trackedNotifications

        delegate: Connections {
            id: watcher

            required property var modelData

            target: modelData

            function onSummaryChanged() {
                root.scheduleRefresh(watcher.modelData.id);
            }

            function onBodyChanged() {
                root.scheduleRefresh(watcher.modelData.id);
            }

            function onAppIconChanged() {
                root.scheduleRefresh(watcher.modelData.id);
            }

            function onImageChanged() {
                root.scheduleRefresh(watcher.modelData.id);
            }

            function onUrgencyChanged() {
                root.scheduleRefresh(watcher.modelData.id);
            }

            function onActionsChanged() {
                root.scheduleRefresh(watcher.modelData.id);
            }
        }
    }

    // A replace changes several properties at once; they arrive as one refresh.
    Timer {
        id: refreshTimer

        property var pending: []

        interval: 0
        onTriggered: {
            const ids = pending;
            pending = [];
            ids.forEach(root.refresh);
        }
    }

    Timer {
        id: saveTimer

        interval: root.saveInterval
        onTriggered: {
            if (root.loaded)
                root.writeState();
            else
                restart();
        }
    }

    Timer {
        interval: 30000
        repeat: true
        running: root.alerts.length > 0
        onTriggered: root.now = Date.now()
    }

    Timer {
        id: alertClear

        interval: root.alertClearDelay
        onTriggered: root.markSeen(root.focusedAlertIds)
    }

    FileView {
        id: stateFile

        path: Paths.barState + "/notifications.json"
        printErrors: false
        onLoaded: root.parseState(text())
        onLoadFailed: root.finishLoading()
    }
}
