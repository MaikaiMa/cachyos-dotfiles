pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import ".."

// The notification stack, one for all screens, shown on the screen that had
// focus when it started: the peek rows, the blobs that broke out of it and
// the backlog of what arrived while the bar was hidden or the session
// locked. It follows Notifications' signals; the daemon does not know it.
Singleton {
    id: root

    // Peek rows, newest first; backlogRow is the combined row for the backlog.
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
    // The bell counts what is neither peeking nor a blob: they join the count
    // when the stack morphs back into the bell.
    readonly property int bellCount: Notifications.items.filter(item => !peekIds.includes(item.id) && !blobIds.includes(item.id)).length

    onPeekDeferredChanged: {
        if (!peekDeferred)
            Qt.callLater(showBacklog);
    }

    // An open panel covers the right island; what was peeking is in the list.
    onPeekBlockedChanged: {
        if (peekBlocked)
            clearPeeks();
    }

    // The stack's rows and blobs as one screen sees them, like Shell.stateOn.
    function peekIdsOn(screen: string): var {
        return peekScreen === screen ? peekIds : [];
    }

    function blobIdsOn(screen: string): var {
        return peekScreen === screen ? blobIds : [];
    }

    // How long a peek row holds, in ms; 0 holds until it is clicked or dismissed.
    function holdFor(id: string): int {
        const notification = id === backlogRow ? null : Notifications.liveObject(id);
        if (!notification)
            return Motion.notificationHoldNormal;
        if (notification.urgency === NotificationUrgency.Critical)
            return 0;
        const timeout = Number(notification.expireTimeout);
        if (timeout > 0)
            return Math.max(Motion.notificationHoldMin, Math.min(Motion.notificationHoldMax, Math.round(timeout)));
        return notification.urgency === NotificationUrgency.Low ? Motion.notificationHoldLow : Motion.notificationHoldNormal;
    }

    // A transient that does not peek now never will, so it ends here; after
    // the server has taken it, not inside its own arrival.
    function offer(id: string, notification: var) {
        const wanted = Settings.notificationPeek && (!Notifications.doNotDisturb || notification.urgency === NotificationUrgency.Critical);
        if (wanted && !peekDeferred && !peekBlocked) {
            pushPeek(id);
            return;
        }
        if (notification.transient)
            Qt.callLater(() => Notifications.expireTransient(id));
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
        dropped.forEach(Notifications.expireTransient);
    }

    // Before the rows change, so a leaving row already knows it becomes a blob.
    // Only list entries become blobs: not the combined row, not transients.
    function addBlobs(ids: var) {
        const fresh = ids.filter(id => id !== backlogRow && Notifications.entryFor(id) !== null && !blobIds.includes(id));
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
        Notifications.expireTransient(id);
    }

    // The row's verbs: the notification's own, then the row leaves.
    function activate(id: string, identifier: string) {
        Notifications.activate(id, identifier);
        endPeek(id);
    }

    function open(id: string) {
        Notifications.open(id);
        endPeek(id);
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

    function clear() {
        blobIds = [];
        peekIds = [];
    }

    function clearPeeks() {
        const rows = peekIds;
        clear();
        rows.forEach(Notifications.expireTransient);
    }

    // The stack's clear-all: its rows and blobs, the rest of the list stays.
    // The combined row only ends; what it stands for was never shown.
    function clearStack() {
        const ids = peekIds.concat(blobIds).filter(id => id !== backlogRow);
        clear();
        Notifications.dismissAll(ids);
    }

    function showBacklog() {
        const waiting = backlogIds.filter(id => Notifications.entryFor(id) !== null);
        backlogIds = [];
        if (waiting.length === 0 || peekDeferred || peekBlocked)
            return;
        backlogCount = waiting.length;
        pushPeek(backlogRow);
    }

    Connections {
        target: Notifications

        function onArrived(id: string, notification: var) {
            root.offer(id, notification);
        }

        function onGone(id: string) {
            root.removePeek(id);
        }

        function onRemoved(ids: var) {
            root.blobIds = root.blobIds.filter(blob => !ids.includes(blob));
            ids.forEach(root.removePeek);
        }

        function onCleared() {
            root.clear();
        }
    }
}
