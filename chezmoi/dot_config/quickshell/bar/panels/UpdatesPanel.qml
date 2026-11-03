pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.components

// The Updates state of the centre island: a count line, one scrolling list
// with the fragile packages first (taller, with a reason), and Update all,
// Refresh, Report. The list is capped so the actions stay on screen whatever
// the count: after a long absence the fragile group alone can be twenty rows.
Panel {
    id: panel

    name: "updates"

    // Ticks while the panel is open so "checked 3 min ago" stays true.
    property real now: Date.now()

    readonly property int itemCount: Updates.items.length
    readonly property real rowsHeight: Updates.fragileCount * Theme.updatesFragileRowHeight + (itemCount - Updates.fragileCount) * Theme.updatesRowHeight + Math.max(0, itemCount - 1) * Theme.updatesRowGap
    readonly property real listHeight: Math.min(Theme.updatesListMaxHeight, rowsHeight)
    readonly property real listSectionHeight: itemCount > 0 ? Theme.updatesSectionGap + listHeight : 0
    readonly property real actionWidth: (contentWidth - (actions.children.length - 1) * Theme.gap) / actions.children.length

    readonly property string headline: {
        if (Updates.checking && !Updates.ready)
            return "Checking for updates…";
        if (!Updates.ready)
            return Updates.error !== "" ? Updates.error : "Not checked yet";
        const count = Updates.count === 0 ? "Up to date" : Updates.count === 1 ? "1 update" : Updates.count + " updates";
        return count + " · " + Updates.checkedText(now) + (Updates.error !== "" ? " · last check failed" : "");
    }

    implicitHeight: 2 * Theme.panelPadding + Theme.updatesHeadHeight + listSectionHeight + Theme.updatesActionsGap + Theme.updatesButtonHeight

    onOpened: {
        now = Date.now();
        list.positionViewAtBeginning();
    }

    Timer {
        interval: 30000
        repeat: true
        running: panel.shown
        onTriggered: panel.now = Date.now()
    }

    Label {
        x: Theme.panelPadding + Theme.updatesHeadInset
        y: Theme.panelPadding
        width: panel.width - 2 * x
        height: Theme.updatesHeadHeight
        verticalAlignment: Text.AlignVCenter
        text: panel.headline
        secondary: true
        numeric: true
    }

    ListView {
        id: list

        x: panel.contentX
        y: Theme.panelPadding + Theme.updatesHeadHeight + Theme.updatesSectionGap
        width: panel.contentWidth
        height: panel.listHeight
        visible: panel.itemCount > 0
        clip: true
        spacing: Theme.updatesRowGap
        boundsBehavior: Flickable.StopAtBounds
        model: Updates.items

        delegate: UpdateRow {
            required property var modelData

            width: ListView.view.width
            height: modelData.fragile ? Theme.updatesFragileRowHeight : Theme.updatesRowHeight
            item: modelData
            fragile: modelData.fragile
            reason: modelData.reason
        }
    }

    ScrollHint {
        view: list
    }

    Row {
        id: actions

        x: panel.contentX
        y: panel.implicitHeight - Theme.panelPadding - Theme.updatesButtonHeight
        width: panel.contentWidth
        spacing: Theme.gap

        PillButton {
            width: panel.actionWidth
            height: Theme.updatesButtonHeight
            text: "Update all"
            iconName: "download"
            filled: true
            enabled: Updates.count > 0 && !Updates.upgrading
            onActivated: {
                Updates.upgradeAll();
                Shell.close();
            }
        }

        PillButton {
            width: panel.actionWidth
            height: Theme.updatesButtonHeight
            text: "Refresh"
            iconName: "refresh"
            spinning: Updates.checking
            onActivated: Updates.refresh()
        }

        PillButton {
            width: panel.actionWidth
            height: Theme.updatesButtonHeight
            text: "Report"
            iconName: "description"
            enabled: Updates.reportAvailable
            onActivated: {
                Updates.openReport();
                Shell.close();
            }
        }
    }

    component UpdateRow: Rectangle {
        id: row

        required property var item
        property bool fragile: false
        property string reason: ""

        readonly property color accent: fragile ? Colors.error : Colors.primary

        radius: Theme.updatesRowRadius
        color: fragile ? Colors.errorSurface : "transparent"

        Rectangle {
            id: chip

            x: Theme.paddingHorizontal
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.updatesChipWidth
            height: Theme.updatesChipHeight
            radius: height / 2
            color: row.fragile ? Colors.errorChip : Colors.subtleFill

            Label {
                anchors.centerIn: parent
                text: row.item.source
                color: row.fragile ? Colors.error : Colors.foregroundVariant
                font.pixelSize: Theme.updatesChipFontSize
            }
        }

        Column {
            anchors.left: chip.right
            anchors.leftMargin: Theme.paddingHorizontal
            anchors.right: version.left
            anchors.rightMargin: Theme.paddingHorizontal
            anchors.verticalCenter: parent.verticalCenter

            Label {
                width: parent.width
                text: row.item.name
            }

            Label {
                visible: row.fragile
                width: parent.width
                text: row.reason
                secondary: true
                color: Colors.error
            }
        }

        Label {
            id: version

            anchors.right: parent.right
            anchors.rightMargin: Theme.paddingHorizontal
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, row.width / 2)
            text: row.item.oldVersion + " → " + row.item.newVersion
            elide: Text.ElideMiddle
            secondary: true
            numeric: true
            color: row.accent
        }
    }
}
