pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The notification stack's rows, newest on top, at a fixed width so the text
// does not reflow while the island morphs. sync(ids) gives the rows that
// should show; a row that goes stays until its collapse is done. rowsHeight
// is the height of the rows that stay, without the gap under the last;
// emptied tells the owner, from inside sync, that the last row has started
// to leave.
Column {
    id: stack

    readonly property var ids: internal.ids
    property int backlogCount: 0
    readonly property real rowsHeight: internal.rowsHeight

    signal emptied
    // A row's actions were revealed or hidden: the owner's next resize uses the tray timing.
    signal actionsToggled
    signal settingsRequested

    // Where a row's icon disc is, for the blob that starts from it.
    function discFor(id: string): Item {
        for (let index = 0; index < repeater.count; index++) {
            const row = repeater.itemAt(index) as NotificationPeekRow;
            if (row && row.rowId === id)
                return row.disc;
        }
        return null;
    }

    // The island is as tall as the rows that stay; the last one has no hairline.
    function measure() {
        let height = 0;
        let settled = 0;
        let last = "";
        for (let index = 0; index < repeater.count; index++) {
            const row = repeater.itemAt(index) as NotificationPeekRow;
            if (!row || row.leaving)
                continue;
            height += row.settledHeight;
            settled++;
            last = row.rowId;
        }
        if (settled === 0)
            return;
        internal.rowsHeight = height + (settled - 1) * Theme.notificationPeekRowGap;
        internal.lastId = last;
    }

    // Called by the owner, not bound: emptied changes what the owner passes.
    function sync(next: var) {
        internal.ids = next;
        rows.sync(next);
        measure();
        if (rows.settledCount === 0)
            emptied();
    }

    objectName: "peek"
    visible: rows.count > 0

    QtObject {
        id: internal

        property var ids: []
        property real rowsHeight: 0
        property string lastId: ""
    }

    // Rows that leave stay until their collapse is done (rows.finish).
    KeyedListModel {
        id: rows

        keyRole: "rowId"
        leavingRoles: ["leaving"]
    }

    Repeater {
        id: repeater

        model: rows

        NotificationPeekRow {
            width: stack.width
            backlogCount: stack.backlogCount
            holding: stack.ids.includes(rowId)
            lastRow: rowId === internal.lastId
            onHoldEnded: NotificationStack.expirePeek(rowId)
            onSettingsRequested: stack.settingsRequested()
            onGone: rows.finish(rowId)
            onRevealedChanged: {
                if (!leaving)
                    stack.actionsToggled();
            }
            onSettledHeightChanged: Qt.callLater(stack.measure)
        }
    }
}
