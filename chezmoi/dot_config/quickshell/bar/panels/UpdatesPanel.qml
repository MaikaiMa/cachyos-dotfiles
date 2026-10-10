pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Updates state of the centre island: a count line, the fragile packages
// with a reason, the rest in a scrolling list, and Update all, Refresh, Report.
Appear {
    id: panel

    // Ticks while the panel is open so "checked 3 min ago" stays true.
    property real now: Date.now()

    readonly property var fragileItems: Updates.items.filter(item => item.fragile)
    readonly property var otherItems: Updates.items.filter(item => !item.fragile)
    readonly property real fragileHeight: fragileItems.length > 0 ? Theme.updatesSectionGap + fragileItems.length * Theme.updatesFragileRowHeight + (fragileItems.length - 1) * Theme.updatesFragileRowGap : 0
    readonly property real listHeight: Math.min(Theme.updatesListMaxHeight, otherItems.length * Theme.updatesRowHeight + Math.max(0, otherItems.length - 1) * Theme.updatesRowGap)
    readonly property real actionWidth: (width - 2 * Theme.panelPadding - 2 * Theme.gap) / 3
    readonly property real listSectionHeight: otherItems.length > 0 ? Theme.updatesSectionGap + listHeight : 0

    readonly property string headline: {
        if (!Updates.ready)
            return Updates.checking ? "Checking for updates…" : "Not checked yet";
        const count = Updates.count === 0 ? "Up to date" : Updates.count === 1 ? "1 update" : Updates.count + " updates";
        return count + " · checked " + relativeTime(Updates.lastChecked, now);
    }

    implicitWidth: Theme.panelWidths.updates
    implicitHeight: 2 * Theme.panelPadding + Theme.updatesHeadHeight + fragileHeight + listSectionHeight + Theme.updatesActionsGap + Theme.updatesButtonHeight

    onShownChanged: {
        now = Date.now();
        if (shown)
            list.positionViewAtBeginning();
    }

    function relativeTime(then: date, reference: real): string {
        const minutes = Math.floor((reference - then.getTime()) / 60000);
        if (minutes < 1)
            return "just now";
        if (minutes < 60)
            return minutes + " min ago";
        const hours = Math.floor(minutes / 60);
        return hours < 24 ? hours + " h ago" : Math.floor(hours / 24) + " d ago";
    }

    Timer {
        interval: 30000
        repeat: true
        running: panel.shown
        onTriggered: panel.now = Date.now()
    }

    Label {
        objectName: "headline"
        x: Theme.panelPadding + Theme.updatesHeadInset
        y: Theme.panelPadding
        width: panel.width - 2 * x
        height: Theme.updatesHeadHeight
        verticalAlignment: Text.AlignVCenter
        text: panel.headline
        secondary: true
        numeric: true
    }

    Column {
        id: fragile

        x: Theme.panelPadding
        y: Theme.panelPadding + Theme.updatesHeadHeight + Theme.updatesSectionGap
        width: panel.width - 2 * Theme.panelPadding
        spacing: Theme.updatesFragileRowGap
        visible: panel.fragileItems.length > 0

        Repeater {
            model: panel.fragileItems

            UpdateRow {
                required property var modelData

                objectName: "fragileRow"
                width: fragile.width
                height: Theme.updatesFragileRowHeight
                item: modelData
                fragile: true
                reason: modelData.reason
            }
        }
    }

    ListView {
        id: list

        objectName: "updatesList"
        x: Theme.panelPadding
        y: Theme.panelPadding + Theme.updatesHeadHeight + panel.fragileHeight + Theme.updatesSectionGap
        width: panel.width - 2 * Theme.panelPadding
        height: panel.listHeight
        visible: panel.otherItems.length > 0
        clip: true
        spacing: Theme.updatesRowGap
        boundsBehavior: Flickable.StopAtBounds
        model: panel.otherItems

        delegate: UpdateRow {
            required property var modelData

            objectName: "updateRow"
            width: ListView.view.width
            height: Theme.updatesRowHeight
            item: modelData
        }
    }

    ScrollHint {
        view: list
    }

    Row {
        x: Theme.panelPadding
        y: panel.implicitHeight - Theme.panelPadding - Theme.updatesButtonHeight
        width: panel.width - 2 * Theme.panelPadding
        spacing: Theme.gap

        PillButton {
            objectName: "updateAllButton"
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
            objectName: "refreshButton"
            width: panel.actionWidth
            height: Theme.updatesButtonHeight
            text: "Refresh"
            iconName: "refresh"
            spinning: Updates.checking
            onActivated: Updates.refresh()
        }

        PillButton {
            objectName: "reportButton"
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

        property var item: ({})
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
                text: row.item.source ?? ""
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
                text: row.item.name ?? ""
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
            text: (row.item.oldVersion ?? "") + " → " + (row.item.newVersion ?? "")
            elide: Text.ElideMiddle
            secondary: true
            numeric: true
            color: row.accent
        }
    }
}
