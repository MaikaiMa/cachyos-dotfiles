pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// The notification history under a header with Clear all: newest first, one
// row expanded at a time. A dismissed row collapses before the service drops
// it, so the list keeps its delegates while items come and go. settledHeight
// is what the list takes once every leaving row has gone, header included,
// 0 without notifications: the owner sizes itself from it, so the island
// shrinks in one animation while a row collapses inside it.
Item {
    id: list

    // Rows that are animating out; the service drops them once they are gone.
    property var leavingIds: []
    property bool clearing: false
    // One row at a time is expanded; expandedExtra is what it adds once settled.
    property string expandedId: ""
    property real expandedExtra: 0
    readonly property int settledCount: clearing ? 0 : Notifications.items.filter(item => !leavingIds.includes(item.id)).length
    readonly property real settledListHeight: Math.min(Theme.notificationListMaxHeight, settledCount * Theme.notificationRowHeight + Math.max(0, settledCount - 1) * Theme.notificationRowGap + (clearing ? 0 : expandedExtra))
    readonly property real settledHeight: settledCount > 0 ? Theme.notificationHeaderGap + Theme.notificationHeaderHeight + settledListHeight : 0

    // Collapses the expanded row.
    function reset() {
        expandedId = "";
    }

    function positionAtBeginning() {
        listView.positionViewAtBeginning();
    }

    function dismiss(id: string) {
        if (expandedId === id)
            expandedId = "";
        if (!leavingIds.includes(id))
            leavingIds = leavingIds.concat([id]);
    }

    function toggleExpanded(id: string) {
        expandedId = expandedId === id ? "" : id;
    }

    function noteExtra(id: string, extra: real) {
        if (id === expandedId)
            expandedExtra = extra;
    }

    // A resident notification stays in the list after an action or a reply.
    function invokeAction(id: string, identifier: string) {
        const resident = Notifications.isResident(id);
        if (Notifications.invoke(id, identifier) && !resident)
            dismiss(id);
    }

    function sendReply(id: string, text: string) {
        const resident = Notifications.isResident(id);
        if (Notifications.reply(id, text) && !resident)
            dismiss(id);
    }

    function clearAll() {
        expandedId = "";
        clearing = true;
        clearTimer.restart();
    }

    function syncModel() {
        const items = Notifications.items;
        const ids = items.map(item => item.id);
        rows.sync(ids, id => {
            const item = items.find(candidate => candidate.id === id);
            return {
                appName: item.appName,
                summary: item.summary,
                body: item.body,
                appIcon: item.appIcon,
                image: item.image,
                desktopEntry: item.desktopEntry
            };
        });
        const kept = leavingIds.filter(id => ids.includes(id));
        if (kept.length !== leavingIds.length)
            leavingIds = kept;
        if (expandedId !== "" && !ids.includes(expandedId))
            expandedId = "";
    }

    height: Theme.notificationHeaderGap + Theme.notificationHeaderHeight + listView.height
    visible: rows.count > 0

    onExpandedIdChanged: {
        if (expandedId === "")
            expandedExtra = 0;
    }

    Component.onCompleted: syncModel()

    Connections {
        target: Notifications

        function onItemsChanged() {
            list.syncModel();
        }
    }

    KeyedListModel {
        id: rows

        keyRole: "notificationId"
        refresh: true
    }

    Timer {
        id: clearTimer

        interval: Motion.crossfadeDuration + Motion.settleMargin
        onTriggered: {
            Notifications.clearAll();
            list.clearing = false;
            list.leavingIds = [];
        }
    }

    SectionHeader {
        id: header

        x: Theme.panelPadding
        y: Theme.notificationHeaderGap
        width: parent.width - 2 * Theme.panelPadding
        height: Theme.notificationHeaderHeight
        iconName: "notifications"
        text: "Notifications · " + list.settledCount
        numeric: true
        opacity: list.settledCount > 0 ? 1 : 0

        Behavior on opacity {
            Crossfade {}
        }

        PillButton {
            id: clearButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            height: clearButton.label.implicitHeight + 2 * Theme.textButtonPaddingVertical
            text: "Clear all"
            accessibleName: "Clear all notifications"
            tone: "accent"
            fontSize: Theme.secondaryFontSize
            horizontalPadding: Theme.textButtonPadding
            baseColor: "transparent"
            hoverColor: Colors.subtleFill
            enabled: !list.clearing
            onActivated: list.clearAll()
        }
    }

    ListView {
        id: listView

        x: Theme.panelPadding
        y: header.y + header.height
        width: parent.width - 2 * Theme.panelPadding
        height: Math.min(Theme.notificationListMaxHeight, contentHeight)
        clip: true
        spacing: Theme.notificationRowGap
        boundsBehavior: Flickable.StopAtBounds
        model: rows

        delegate: NotificationRow {
            width: ListView.view.width
            leaving: list.clearing || list.leavingIds.includes(notificationId)
            expanded: list.expandedId === notificationId
            onToggled: list.toggleExpanded(notificationId)
            onExpansionExtraChanged: list.noteExtra(notificationId, expansionExtra)
            onActionInvoked: identifier => list.invokeAction(notificationId, identifier)
            onReplySent: text => list.sendReply(notificationId, text)
            onDismissClicked: list.dismiss(notificationId)
            // Clear all hands the whole list to the service at once.
            onGone: {
                if (!list.clearing)
                    Notifications.dismiss(notificationId);
            }
        }
    }

    ScrollHint {
        view: listView
    }
}
