import QtQuick
import qs

// The scrolling list of the Wi-Fi and Bluetooth panels. The model is patched by
// key instead of replaced, so a row keeps its delegate (and a half-typed
// password its field) while the order changes. One row at a time is expanded,
// with a kind the panel gives it (what the row shows), and while it is the
// order holds still: rows keep their places, new ones join at the end, until
// it collapses. implicitHeight is the settled height from the keys, the
// expanded key and the errors, so the island grows in step with a row that
// expands.
Item {
    id: list

    // Row identities in display order: SSIDs or device addresses.
    property var keys: []
    property string expandedKey: ""
    property string expandedKind: ""
    // key -> error text
    property var errors: ({})
    // Shown in place of the rows while there are none.
    property string emptyText: ""
    property alias delegate: rowView.delegate

    readonly property real rowsHeight: {
        if (keys.length === 0)
            return Theme.listRowHeight;
        let height = (keys.length - 1) * Theme.listRowGap;
        for (const key of keys)
            height += Theme.listRowHeight + (key === expandedKey ? Theme.listRowExpansion : 0) + (errors[key] ? Theme.listRowErrorHeight : 0);
        return height;
    }

    implicitHeight: Math.min(Theme.listMaxHeight, rowsHeight)

    onKeysChanged: sync()
    Component.onCompleted: sync()

    // A row that expands below the visible part scrolls into view once it has grown.
    onExpandedKeyChanged: {
        sync();
        if (expandedKey !== "")
            revealTimer.restart();
    }

    function sync() {
        const shown = [];
        for (let index = 0; index < rowModel.count; index++)
            shown.push(rowModel.keyAt(index));
        const frozen = expandedKey !== "" && keys.includes(expandedKey) && shown.includes(expandedKey);
        rowModel.sync(frozen ? shown.filter(key => keys.includes(key)).concat(keys.filter(key => !shown.includes(key))) : keys);
    }

    function expand(key: string, kind: string) {
        expandedKind = kind;
        expandedKey = key;
    }

    function collapse() {
        expandedKey = "";
        expandedKind = "";
    }

    // The same row and kind again collapses it.
    function toggle(key: string, kind: string) {
        if (expandedKey === key && expandedKind === kind)
            collapse();
        else
            expand(key, kind);
    }

    function positionAtBeginning() {
        rowView.positionViewAtBeginning();
    }

    KeyedListModel {
        id: rowModel
    }

    Timer {
        id: revealTimer

        interval: Motion.growDuration + Motion.settleMargin
        onTriggered: {
            const index = rowModel.indexOf(list.expandedKey);
            if (index >= 0)
                rowView.positionViewAtIndex(index, ListView.Contain);
        }
    }

    ListView {
        id: rowView

        width: parent.width
        height: list.height
        clip: true
        spacing: Theme.listRowGap
        boundsBehavior: Flickable.StopAtBounds
        model: rowModel
    }

    ScrollHint {
        view: rowView
    }

    Label {
        anchors.centerIn: parent
        visible: list.keys.length === 0
        text: list.emptyText
        color: Colors.foregroundVariant
        font.pixelSize: Theme.fontSizeDetail
    }
}
