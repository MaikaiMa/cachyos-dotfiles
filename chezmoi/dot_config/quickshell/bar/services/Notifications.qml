pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The bar is the notification daemon of the Niri session (ADR-0028). Quickshell's
// server holds the live notifications; the history, the seen marks and do not
// disturb live in the bar's own state file. A notification lights its app's
// workspace pill until it is ten minutes old, dismissed, or seen: its workspace
// kept focus for alertClearDelay. The peek stack is NotificationStack's; it
// follows arrived, gone, removed and cleared.
Singleton {
    id: root

    readonly property int historyLimit: 200
    readonly property real historyAge: 7 * 24 * 60 * 60 * 1000
    // The history is written at most this often.
    readonly property int saveInterval: 1000
    // A workspace's notification colour clears this long after it gains focus.
    readonly property int alertClearDelay: 3000

    property bool doNotDisturb: false

    readonly property var liveIds: internal.liveNotifications.map(notification => internal.keyByServerId[notification.id] ?? "")

    // Newest first: {id, serverId, appName, summary, body, appIcon, image,
    // desktopEntry, urgency, timestamp (ms), seen, live}. `live`: the sender's
    // notification still exists, so its actions and reply work.
    readonly property var items: internal.entries.map(entry => Object.assign({}, entry, {
                live: liveIds.includes(entry.id)
            }))

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
            for (const key of Niri.appKeys(window.appId))
                keys.add(key);
        return alerts.filter(item => itemKeys(item).some(key => keys.has(key))).map(item => item.id);
    }
    readonly property string focusedAlertKey: Niri.focusedWorkspace && focusedAlertIds.length > 0 ? Niri.focusedWorkspace.id + ":" + focusedAlertIds.join(",") : ""

    // A new notification, transient ones included, once the server tracks it.
    signal arrived(string id, var notification)
    // The sender's notification closed, whoever closed it; an entry stays as history.
    signal gone(string id)
    // Dismissed by the user: the entries are gone from the history.
    signal removed(var ids)
    // clearAll: nothing is left to show.
    signal cleared
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

    function itemKeys(item: var): var {
        return Niri.appKeys(item.appName ?? "").concat(Niri.appKeys(item.desktopEntry ?? ""));
    }

    function hasRecentFor(appId: string): bool {
        const keys = recentAppKeys;
        return Niri.appKeys(appId).some(key => keys.has(key));
    }

    // The live Notification of an entry or a transient peek, or null.
    function liveObject(id: string): var {
        return internal.liveNotifications.find(notification => internal.keyByServerId[notification.id] === id) ?? null;
    }

    function entryFor(id: string): var {
        return internal.entries.find(entry => entry.id === id) ?? null;
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

    // The image of a notification: the live one first, raw data included,
    // else the path its entry kept.
    function imageFor(id: string): string {
        const notification = liveObject(id);
        if (notification) {
            const image = notification.image ?? "";
            return storedImage(image) || image;
        }
        const entry = entryFor(id);
        return entry ? entry.image : "";
    }

    // The icon of a notification, live or kept, for the rows, the peek and the blobs.
    function iconFor(id: string): string {
        const source = liveObject(id) ?? entryFor(id);
        return source ? iconSource(source.appIcon ?? "", source.desktopEntry ?? "", imageFor(id)) : "";
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

    // The actions shown as pills, as { id, text, tone }: the default action
    // first, under its own label or "Open", then the others in the sender's order.
    function pillActions(notification: var): var {
        if (!notification)
            return [];
        const actions = notification.actions ?? [];
        const defaults = actions.filter(action => action.identifier === "default");
        const others = actions.filter(action => action.identifier !== "default");
        return defaults.map(action => ({
                    id: action.identifier,
                    text: action.text && action.text !== "default" ? action.text : "Open",
                    tone: "accent"
                })).concat(others.map(action => ({
                    id: action.identifier,
                    text: action.text || action.identifier,
                    tone: "neutral"
                })));
    }

    function hasDefaultAction(id: string): bool {
        const notification = liveObject(id);
        return !!notification && (notification.actions ?? []).some(action => action.identifier === "default");
    }

    function newKey(serverId: int): string {
        return Date.now().toString(36) + "-" + serverId;
    }

    function setKey(serverId: int, id: string) {
        const keys = Object.assign({}, internal.keyByServerId);
        if (id === "")
            delete keys[serverId];
        else
            keys[serverId] = id;
        internal.keyByServerId = keys;
        persisted.keys = JSON.stringify(keys);
    }

    function receive(notification: var) {
        if (internal.keyByServerId[notification.id] !== undefined) {
            notification.tracked = true;
            scheduleUpdate(notification.id);
            return;
        }
        // The key first: tracking publishes the notification to liveIds.
        const id = newKey(notification.id);
        setKey(notification.id, id);
        notification.tracked = true;
        if (!notification.transient) {
            internal.entries = [entryFrom(notification, id)].concat(internal.entries);
            scheduleSave();
        }
        arrived(id, notification);
    }

    // A sender's replaces_id arrives as changed properties on the same object.
    // Only a new summary or urgency alerts again; progress senders rewrite the
    // body every second and keep their place, time and seen mark.
    function updateEntry(serverId: int) {
        const id = internal.keyByServerId[serverId];
        const notification = id === undefined ? null : liveObject(id);
        if (!notification)
            return;
        const current = entryFor(id);
        if (current) {
            const next = entryFrom(notification, id);
            if (next.summary !== current.summary || next.urgency !== current.urgency) {
                internal.entries = [next].concat(internal.entries.filter(entry => entry.id !== id));
                scheduleSave();
            } else if (next.body !== current.body || next.appIcon !== current.appIcon || next.image !== current.image) {
                next.timestamp = current.timestamp;
                next.seen = current.seen;
                internal.entries = internal.entries.map(entry => entry.id === id ? next : entry);
                scheduleSave();
            }
        }
        replaced(id);
    }

    function scheduleUpdate(serverId: int) {
        if (!updateTimer.pending.includes(serverId))
            updateTimer.pending = updateTimer.pending.concat([serverId]);
        updateTimer.restart();
    }

    // The sender closed it, or the bar did: what is left is history.
    function liveGone(serverId: int) {
        const id = internal.keyByServerId[serverId];
        if (id === undefined)
            return;
        setKey(serverId, "");
        gone(id);
    }

    // A transient notification is over once its peek is; an entry stays.
    function expireTransient(id: string) {
        if (entryFor(id))
            return;
        const notification = liveObject(id);
        if (notification)
            notification.expire();
    }

    function dismiss(id: string) {
        dismissAll([id]);
    }

    // Live ones close with reason "dismissed by user", historic ones leave the
    // history; ids that are neither are ignored.
    function dismissAll(ids: var) {
        const unique = Array.from(new Set(ids));
        const live = unique.map(liveObject).filter(notification => notification !== null);
        internal.entries = internal.entries.filter(entry => !unique.includes(entry.id));
        scheduleSave();
        removed(unique);
        live.forEach(notification => notification.dismiss());
    }

    // Everything: the list, the stack and every live notification, nothing left counted.
    function clearAll() {
        const ids = internal.entries.map(entry => entry.id).concat(liveIds.filter(id => id !== ""));
        cleared();
        dismissAll(ids);
    }

    function markSeen(ids: var) {
        if (!internal.entries.some(entry => !entry.seen && ids.includes(entry.id)))
            return;
        internal.entries = internal.entries.map(entry => !entry.seen && ids.includes(entry.id) ? Object.assign({}, entry, {
                seen: true
            }) : entry);
        scheduleSave();
    }

    // Runs one of the sender's actions; invoke() itself closes a notification
    // that is not resident, with reason "dismissed by user".
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

    // After an action or the row's text: the entry goes unless the sender
    // marked the notification resident, and a live one still open closes.
    function finish(id: string) {
        if (!isResident(id))
            dismiss(id);
    }

    function activate(id: string, identifier: string) {
        invoke(id, identifier);
        finish(id);
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
        const item = entryFor(id) ?? liveObject(id);
        const window = item ? Niri.windowForApp([item.appName ?? "", item.desktopEntry ?? ""]) : null;
        if (window)
            Niri.focusWindow(window.id);
        markSeen([id]);
        finish(id);
    }

    function toggleDoNotDisturb() {
        doNotDisturb = !doNotDisturb;
        scheduleSave();
    }

    // At most historyLimit entries and nothing older than historyAge; a live
    // notification that falls out expires.
    function prune() {
        const cutoff = Date.now() - historyAge;
        const kept = internal.entries.filter(entry => entry.timestamp >= cutoff).slice(0, historyLimit);
        if (kept.length === internal.entries.length)
            return;
        const dropped = internal.entries.filter(entry => !kept.includes(entry));
        internal.entries = kept;
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

    // Notifications that arrived before the file was read stay in front. A
    // file that does not parse is kept beside it before the next save
    // replaces it.
    function parseState(text: string) {
        try {
            const state = JSON.parse(text);
            doNotDisturb = state.doNotDisturb === true;
            const stored = Array.isArray(state.notifications) ? state.notifications : [];
            const known = internal.entries.map(entry => entry.id);
            const restored = stored.filter(entry => entry && entry.id !== undefined).map(normalise).filter(entry => !known.includes(entry.id));
            internal.entries = internal.entries.concat(restored).sort((a, b) => b.timestamp - a.timestamp);
        } catch (error) {
            console.warn("Notifications: " + stateFile.path + " does not parse (" + error + "); kept as " + badCopy.path);
            badCopy.setText(text);
        }
        finishLoading();
    }

    // Only a missing file is an empty history. Any other failure leaves the
    // history unsaved for this session, so the file is not overwritten.
    function readFailed(error: int) {
        if (error === FileViewError.FileNotFound) {
            finishLoading();
            return;
        }
        console.warn("Notifications: cannot read " + stateFile.path + " (" + FileViewError.toString(error) + "); the history is not saved until the bar restarts");
        internal.unreadable = true;
        relink();
    }

    function finishLoading() {
        internal.loaded = true;
        prune();
        relink();
    }

    // After a config reload the server keeps its notifications (keepOnReload)
    // without announcing them again; their entry ids come back from the
    // persisted key map. A transient one lost its peek with the reload and ends.
    function relink() {
        const restored = internal.restoredKeys;
        internal.restoredKeys = ({});
        for (const notification of internal.liveNotifications) {
            if (internal.keyByServerId[notification.id] !== undefined)
                continue;
            if (notification.transient) {
                notification.expire();
                continue;
            }
            const known = restored[notification.id];
            if (known !== undefined && entryFor(known)) {
                setKey(notification.id, known);
                continue;
            }
            const id = known ?? newKey(notification.id);
            setKey(notification.id, id);
            internal.entries = [entryFrom(notification, id)].concat(internal.entries);
            scheduleSave();
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
            notifications: internal.entries
        }) + "\n");
    }

    Component.onDestruction: {
        if (saveTimer.running && internal.loaded)
            writeState();
    }

    QtObject {
        id: internal

        // Newest first, without `live`; transient notifications are never in
        // it. Image paths only: raw image data does not outlive the process.
        property var entries: []
        // Until the state file has been read, a save would drop the history.
        property bool loaded: false
        // The file exists but could not be read: nothing is saved.
        property bool unreadable: false
        // The server's id of every live notification to its entry id. Notification
        // ids start again at 1 with every bar process, so entries get their own.
        // Always replaced, never edited, so the bindings follow it.
        property var keyByServerId: ({})
        // The previous generation's map after a config reload, until relink.
        property var restoredKeys: ({})
        // Under qmllint 6.12 `values` of UntypedObjectModel does not resolve although the type info declares it.
        readonly property var liveNotifications: server.trackedNotifications.values // qmllint disable missing-property
    }

    // The key map across config reloads, as JSON: a JS object would belong to
    // the old generation's engine.
    PersistentProperties {
        id: persisted

        property string keys: "{}"

        reloadableId: "notificationKeys"
        onReloaded: {
            try {
                internal.restoredKeys = JSON.parse(keys);
            } catch (error) {
                internal.restoredKeys = ({});
            }
        }
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
        target: server.trackedNotifications // qmllint disable incompatible-type

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
                root.scheduleUpdate(watcher.modelData.id);
            }

            function onBodyChanged() {
                root.scheduleUpdate(watcher.modelData.id);
            }

            function onAppIconChanged() {
                root.scheduleUpdate(watcher.modelData.id);
            }

            function onImageChanged() {
                root.scheduleUpdate(watcher.modelData.id);
            }

            function onUrgencyChanged() {
                root.scheduleUpdate(watcher.modelData.id);
            }

            function onActionsChanged() {
                root.scheduleUpdate(watcher.modelData.id);
            }
        }
    }

    // A replace changes several properties at once; they arrive as one update.
    Timer {
        id: updateTimer

        property var pending: []

        interval: 0
        onTriggered: {
            const ids = pending;
            pending = [];
            ids.forEach(root.updateEntry);
        }
    }

    Timer {
        id: saveTimer

        interval: root.saveInterval
        onTriggered: {
            if (internal.loaded)
                root.writeState();
            else if (!internal.unreadable)
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
        onLoadFailed: error => root.readFailed(error)
    }

    FileView {
        id: badCopy

        path: stateFile.path + ".bad"
        preload: false
        printErrors: false
    }
}
