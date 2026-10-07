import QtQuick
import ".."

// The scrolling list of the Wi-Fi and Bluetooth panels. The model is patched by
// key instead of replaced, so a row keeps its delegate (and a half-typed
// password its field) while the order changes, and while a row is expanded the
// order holds still: rows keep their places, new ones join at the end, until it
// collapses. implicitHeight is the settled
// height from the keys, the expanded key and the errors, so the island grows in
// step with a row that expands.
Item {
    id: list

    // Row identities in display order: SSIDs or device addresses.
    property var keys: []
    property string expandedKey: ""
    // key -> error text
    property var errors: ({})
    // Shown in place of the rows while there are none.
    property string emptyText: ""
    property alias delegate: view.delegate

    readonly property real rowsHeight: {
        if (keys.length === 0)
            return Theme.listRowHeight;
        let height = (keys.length - 1) * Theme.listRowGap;
        for (const key of keys)
            height += Theme.listRowHeight + (key === expandedKey ? Theme.listRowExpansion : 0) + (errors[key] ? Theme.listRowErrorHeight : 0);
        return height;
    }

    implicitHeight: Math.min(Theme.notificationListMaxHeight, rowsHeight)

    onKeysChanged: sync()
    Component.onCompleted: sync()

    // A row that expands below the visible part scrolls into view once it has grown.
    onExpandedKeyChanged: {
        sync();
        if (expandedKey !== "")
            revealTimer.restart();
    }

    function modelKeys(): var {
        const shown = [];
        for (let index = 0; index < rowModel.count; index++)
            shown.push(rowModel.get(index).rowKey);
        return shown;
    }

    function sync() {
        const shown = modelKeys();
        const frozen = expandedKey !== "" && keys.includes(expandedKey) && shown.includes(expandedKey);
        const order = frozen ? shown.filter(key => keys.includes(key)).concat(keys.filter(key => !shown.includes(key))) : keys;
        for (let index = rowModel.count - 1; index >= 0; index--) {
            if (!keys.includes(rowModel.get(index).rowKey))
                rowModel.remove(index);
        }
        order.forEach((key, index) => {
            if (index < rowModel.count && rowModel.get(index).rowKey === key)
                return;
            for (let from = index + 1; from < rowModel.count; from++) {
                if (rowModel.get(from).rowKey === key) {
                    rowModel.move(from, index, 1);
                    return;
                }
            }
            rowModel.insert(index, {
                rowKey: key
            });
        });
    }

    function positionAtBeginning() {
        view.positionViewAtBeginning();
    }

    ListModel {
        id: rowModel
    }

    Timer {
        id: revealTimer

        interval: Motion.growDuration + 20
        onTriggered: {
            const index = list.modelKeys().indexOf(list.expandedKey);
            if (index >= 0)
                view.positionViewAtIndex(index, ListView.Contain);
        }
    }

    ListView {
        id: view

        width: parent.width
        height: list.height
        clip: true
        spacing: Theme.listRowGap
        boundsBehavior: Flickable.StopAtBounds
        model: rowModel
    }

    // A thin scroll hint while the list is longer than its window.
    Rectangle {
        visible: view.contentHeight > view.height
        x: view.width - width
        y: view.visibleArea.yPosition * view.height
        width: 4
        height: view.visibleArea.heightRatio * view.height
        radius: width / 2
        color: Qt.alpha(Colors.foreground, 0.25)
    }

    Text {
        anchors.centerIn: parent
        visible: list.keys.length === 0
        text: list.emptyText
        color: Colors.foregroundVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.homeDetailFontSize
        font.weight: Theme.fontWeight
    }
}
