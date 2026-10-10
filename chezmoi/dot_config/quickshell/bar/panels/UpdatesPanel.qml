pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Updates state of the centre island: a count line, the fragile packages
// with a reason, the rest in a scrolling list, and Update all, Refresh, Report.
Item {
    id: panel

    property bool shown: false
    // Ticks while the panel is open so "checked 3 min ago" stays true.
    property real now: Date.now()

    readonly property var fragileItems: Updates.items.filter(item => item.fragile)
    readonly property var otherItems: Updates.items.filter(item => !item.fragile)
    readonly property real fragileHeight: fragileItems.length > 0 ? Theme.updatesSectionGap + fragileItems.length * Theme.updatesFragileRowHeight + (fragileItems.length - 1) * Theme.updatesFragileRowGap : 0
    readonly property real listHeight: Math.min(Theme.updatesListMaxHeight, otherItems.length * Theme.updatesRowHeight + Math.max(0, otherItems.length - 1) * Theme.updatesRowGap)
    readonly property real listSectionHeight: otherItems.length > 0 ? Theme.updatesSectionGap + listHeight : 0

    readonly property string headline: {
        if (!Updates.ready)
            return Updates.checking ? "Checking for updates…" : "Not checked yet";
        const count = Updates.count === 0 ? "Up to date" : Updates.count === 1 ? "1 update" : Updates.count + " updates";
        return count + " · checked " + relativeTime(Updates.lastChecked, now);
    }

    implicitWidth: Theme.panelWidths.updates
    implicitHeight: 2 * Theme.panelPadding + Theme.updatesHeadHeight + fragileHeight + listSectionHeight + Theme.updatesActionsGap + Theme.updatesButtonHeight

    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

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

    Text {
        objectName: "headline"
        x: Theme.panelPadding + 4
        y: Theme.panelPadding
        width: panel.width - 2 * x
        height: Theme.updatesHeadHeight
        verticalAlignment: Text.AlignVCenter
        text: panel.headline
        elide: Text.ElideRight
        color: Colors.foregroundVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.secondaryFontSize
        font.weight: Theme.fontWeight
        font.features: ({
                tnum: 1
            })
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

        // A thin scroll hint while the list is longer than its window.
        Rectangle {
            visible: list.contentHeight > list.height
            x: list.width - width
            y: list.visibleArea.yPosition * list.height
            width: 4
            height: list.visibleArea.heightRatio * list.height
            radius: width / 2
            color: Qt.alpha(Colors.foreground, 0.25)
        }
    }

    Row {
        x: Theme.panelPadding
        y: panel.implicitHeight - Theme.panelPadding - Theme.updatesButtonHeight
        width: panel.width - 2 * Theme.panelPadding
        spacing: Theme.gap

        ActionButton {
            objectName: "updateAllButton"
            text: "Update all"
            iconName: "download"
            primary: true
            enabled: Updates.count > 0 && !Updates.upgrading
            onActivated: {
                Updates.upgradeAll();
                Shell.close();
            }
        }

        ActionButton {
            objectName: "refreshButton"
            text: "Refresh"
            iconName: "refresh"
            spinning: Updates.checking
            onActivated: Updates.refresh()
        }

        ActionButton {
            objectName: "reportButton"
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
        color: fragile ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.error, 0.14)) : "transparent"

        Rectangle {
            id: chip

            x: Theme.paddingHorizontal
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.updatesChipWidth
            height: Theme.updatesChipHeight
            radius: height / 2
            color: row.fragile ? Qt.alpha(Colors.error, 0.18) : Qt.alpha(Colors.foreground, 0.07)

            Text {
                anchors.centerIn: parent
                text: row.item.source ?? ""
                color: row.fragile ? Colors.error : Colors.foregroundVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.updatesChipFontSize
                font.weight: Theme.fontWeight
            }
        }

        Column {
            anchors.left: chip.right
            anchors.leftMargin: Theme.paddingHorizontal
            anchors.right: version.left
            anchors.rightMargin: Theme.paddingHorizontal
            anchors.verticalCenter: parent.verticalCenter

            Text {
                width: parent.width
                text: row.item.name ?? ""
                elide: Text.ElideRight
                color: Colors.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
            }

            Text {
                visible: row.fragile
                width: parent.width
                text: row.reason
                elide: Text.ElideRight
                color: Colors.error
                font.family: Theme.fontFamily
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Theme.fontWeight
            }
        }

        Text {
            id: version

            anchors.right: parent.right
            anchors.rightMargin: Theme.paddingHorizontal
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, row.width / 2)
            text: (row.item.oldVersion ?? "") + " → " + (row.item.newVersion ?? "")
            elide: Text.ElideMiddle
            color: row.accent
            font.family: Theme.fontFamily
            font.pixelSize: Theme.secondaryFontSize
            font.weight: Theme.fontWeight
            font.features: ({
                    tnum: 1
                })
        }
    }

    component ActionButton: Item {
        id: button

        property string text: ""
        property string iconName: ""
        property bool primary: false
        property bool spinning: false

        signal activated

        readonly property color contentColor: primary ? Colors.primaryForeground : Colors.foreground

        width: (parent.width - 2 * Theme.gap) / 3
        height: Theme.updatesButtonHeight
        opacity: enabled ? 1 : 0.5
        activeFocusOnTab: true

        Accessible.role: Accessible.Button
        Accessible.name: text
        Accessible.onPressAction: button.activated()

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                button.activated();
            }
        }

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: {
                if (button.primary)
                    return pointer.containsMouse ? Qt.tint(Colors.primary, Qt.alpha(Colors.primaryForeground, 0.10)) : Colors.primary;
                return pointer.containsMouse ? Qt.tint(Colors.surfaceContainerHigh, Qt.alpha(Colors.primary, 0.16)) : Colors.surfaceContainerHigh;
            }

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }

            // Keyboard focus only arrives through Tab, so the ring never shows on a click.
            Rectangle {
                anchors.fill: parent
                anchors.margins: -3
                radius: height / 2
                color: "transparent"
                border.width: 2
                border.color: Colors.primary
                visible: button.activeFocus
            }
        }

        Row {
            anchors.centerIn: parent
            spacing: Theme.gap

            Icon {
                id: glyph

                anchors.verticalCenter: parent.verticalCenter
                name: button.iconName
                color: button.contentColor

                RotationAnimator on rotation {
                    // Only while the panel shows: a spin in the hidden panel still
                    // makes the bar window present frames.
                    running: button.spinning && glyph.visible && Motion.refreshSpinDuration > 0
                    from: 0
                    to: 360
                    duration: Motion.refreshSpinDuration
                    loops: Animation.Infinite
                    onRunningChanged: {
                        if (!running)
                            glyph.rotation = 0;
                    }
                }
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: button.text
                color: button.contentColor
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
            }
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }
}
