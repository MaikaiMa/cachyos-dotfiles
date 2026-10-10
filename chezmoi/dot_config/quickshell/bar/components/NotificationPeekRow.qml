pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Services.Notifications
import ".."
import "../services"

// One bare row of the notification stack: the app's icon on a disc, the
// summary over one line of body, and the hairline in the gap below it. Its own
// hold ends it. Resting the pointer on it, or a long press, shows the dismiss
// glyph and grows a row with actions so its text actions rise from under the
// body. The owner reads settledHeight to size the island and disc to start a
// blob where the row's icon was.
Item {
    id: row

    // Roles of the island's model: an entry id from Notifications.peekIds or
    // Notifications.backlogRow, and whether the row is collapsing out.
    required property string rowId
    required property bool leaving
    property int backlogCount: 0
    // False while the island prepares or once the row has left the stack.
    property bool holding: false
    // The last row that stays draws no hairline under it.
    property bool lastRow: true

    signal holdEnded
    signal settingsRequested
    signal gone

    readonly property bool combined: rowId === Notifications.backlogRow
    readonly property var notification: !combined && Notifications.liveIds.includes(rowId) ? Notifications.liveObject(rowId) : null
    readonly property bool critical: !!notification && notification.urgency === NotificationUrgency.Critical
    readonly property var actions: Notifications.pillActions(notification).slice(0, Theme.notificationPeekActions)

    // Copied, not bound: a replace cross-fades from the old text to the new.
    property string summaryText: ""
    property string bodyText: ""
    property string iconUrl: ""

    property bool pointerHeld: false
    property bool hoverRested: false
    property bool pressRevealed: false
    readonly property bool dismissShown: (hoverRested || pressRevealed) && !leaving
    readonly property bool revealed: actions.length > 0 && dismissShown
    property real revealProgress: revealed ? 1 : 0
    // Set as the row starts leaving: its disc goes on as a blob under the island.
    property bool toBlob: false
    // Which timing the next height change uses: the island's, or the tray's for the actions.
    property bool actionMotion: false

    readonly property real contentHeight: revealed ? Theme.notificationPeekRowOpenHeight : Theme.notificationPeekRowHeight
    readonly property real settledHeight: entered && !leaving ? contentHeight : 0
    readonly property Item disc: face.disc
    readonly property real textX: Theme.notificationPeekDisc + Theme.notificationPeekTextGap

    readonly property int holdInterval: Notifications.holdFor(rowId)
    readonly property bool holdActive: holding && !leaving && holdInterval > 0 && !pointerHeld && !pressRevealed

    property bool entered: false

    function adopt() {
        if (combined) {
            summaryText = backlogCount === 1 ? "1 new notification" : backlogCount + " new notifications";
            bodyText = "";
            iconUrl = "";
            return;
        }
        // A re-peeked blob may outlive its sender's notification: its entry stands in.
        const source = notification ?? Notifications.entryFor(rowId);
        if (!source)
            return;
        summaryText = Notifications.oneLine(source.summary ?? "");
        bodyText = Notifications.oneLine(source.body ?? "");
        iconUrl = Notifications.iconSource(source.appIcon ?? "", source.desktopEntry ?? "", source.image ?? "");
    }

    function dismiss() {
        if (combined)
            Notifications.endPeek(rowId);
        else
            Notifications.dismiss(rowId);
    }

    // The gap below the row is part of it, so the rows below follow its height.
    implicitHeight: settledHeight > 0 ? settledHeight + Theme.notificationPeekRowGap : 0
    height: implicitHeight
    opacity: entered && !leaving ? 1 : 0
    clip: true

    // Rows come in with the island's grow and leave with its shrink, so the
    // rows below slide in step with the island; the actions use the tray timing.
    Behavior on implicitHeight {
        MorphAnimation {
            shrinking: row.leaving && !row.actionMotion
            durationOverride: row.actionMotion ? Motion.trayDuration : -1
        }
    }
    Behavior on opacity {
        Crossfade {}
    }
    Behavior on revealProgress {
        MorphAnimation {
            durationOverride: Motion.trayDuration
        }
    }

    Component.onCompleted: {
        adopt();
        entered = true;
    }
    onNotificationChanged: {
        if (summaryText === "")
            adopt();
    }
    onBacklogCountChanged: {
        if (combined)
            adopt();
    }
    onRevealedChanged: actionMotion = !leaving
    onHeightChanged: {
        if (leaving && height === 0)
            gone();
    }
    onLeavingChanged: {
        if (!leaving)
            return;
        actionMotion = false;
        toBlob = Notifications.blobIds.includes(rowId);
        if (height === 0)
            gone();
    }

    Connections {
        target: Notifications

        function onReplaced(id: string) {
            if (id !== row.rowId || row.leaving)
                return;
            ghost.summary = row.summaryText;
            ghost.body = row.bodyText;
            ghost.iconUrl = row.iconUrl;
            ghost.critical = row.critical;
            row.adopt();
            replaceFade.restart();
            hold.restart();
        }
    }

    Timer {
        id: hold

        interval: Math.max(1, row.holdInterval)
        running: row.holdActive
        onTriggered: row.holdEnded()
    }

    Timer {
        id: rest

        interval: Motion.hoverRestDelay
        onTriggered: row.hoverRested = true
    }

    // Leaving folds the actions and restarts the hold after the grace.
    Timer {
        id: grace

        interval: Motion.hoverLeaveGrace
        onTriggered: {
            row.hoverRested = false;
            row.pointerHeld = false;
        }
    }

    ParallelAnimation {
        id: replaceFade

        Crossfade {
            target: ghost
            property: "opacity"
            from: 1
            to: 0
        }
        Crossfade {
            target: face
            property: "opacity"
            from: 0
            to: 1
        }
    }

    HoverHandler {
        onHoveredChanged: {
            if (hovered) {
                grace.stop();
                row.pointerHeld = true;
                rest.restart();
            } else {
                rest.stop();
                grace.restart();
            }
        }
    }

    // Under the actions and the dismiss glyph, which take their own clicks.
    MouseArea {
        width: parent.width
        height: row.contentHeight
        enabled: !row.leaving
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        pressAndHoldInterval: Motion.longPressInterval
        onPressAndHold: mouse => {
            if (mouse.button === Qt.LeftButton)
                row.pressRevealed = true;
        }
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                row.settingsRequested();
            } else if (mouse.button === Qt.MiddleButton) {
                row.dismiss();
            } else if (row.pressRevealed) {
                row.pressRevealed = false;
            } else if (row.combined) {
                row.settingsRequested();
            } else {
                Notifications.open(row.rowId);
            }
        }
    }

    Face {
        id: ghost

        opacity: 0
        visible: opacity > 0
    }

    Face {
        id: face

        summary: row.summaryText
        body: row.bodyText
        iconUrl: row.iconUrl
        critical: row.critical
    }

    // Plain text in the text column, under the body; the default action first.
    Row {
        x: row.textX
        y: Theme.notificationPeekRowHeight + (1 - row.revealProgress) * Theme.notificationPeekActionRise
        spacing: Theme.notificationPeekActionGap
        opacity: row.revealProgress
        visible: opacity > 0
        enabled: row.revealed

        Repeater {
            model: row.actions

            Label {
                id: actionLabel

                required property var modelData

                height: Theme.notificationPeekActionHeight
                verticalAlignment: Text.AlignVCenter
                text: modelData.text
                color: modelData.primary ? Colors.primary : Colors.foreground
                font.pixelSize: Theme.notificationPeekActionFontSize
                font.underline: actionPointer.containsMouse

                MouseArea {
                    id: actionPointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Notifications.activate(row.rowId, actionLabel.modelData.identifier)
                }

                Accessible.role: Accessible.Button
                Accessible.name: actionLabel.text
            }
        }
    }

    IconButton {
        id: dismissButton

        objectName: "dismiss"
        x: parent.width - Theme.notificationPeekDismissInset - (Theme.iconSize + Theme.notificationPeekDismissHit) / 2
        y: Theme.notificationPeekDismissInset - (Theme.notificationPeekDismissHit - Theme.iconSize) / 2
        size: Theme.notificationPeekDismissHit
        iconName: "close"
        iconSize: Theme.iconSize
        background: false
        iconColor: dismissButton.hovered ? Colors.foreground : Colors.foregroundVariant
        opacity: row.dismissShown ? 1 : 0
        visible: opacity > 0
        enabled: row.dismissShown
        focusable: row.dismissShown
        accessibleName: "Dismiss " + row.summaryText
        onActivated: row.dismiss()

        Behavior on opacity {
            Crossfade {}
        }
    }

    Rectangle {
        objectName: "hairline"
        y: row.contentHeight + (Theme.notificationPeekRowGap - height) / 2
        width: parent.width
        height: Theme.hairlineWidth
        color: Qt.alpha(Colors.outline, Theme.notificationPeekHairlineOpacity)
        opacity: row.lastRow ? 0 : 1

        Behavior on opacity {
            Crossfade {}
        }
    }

    Accessible.role: Accessible.Button
    Accessible.name: row.summaryText + (row.bodyText !== "" ? ", " + row.bodyText : "")

    // Disc and two lines in the top 48 px; the combined row has one line.
    component Face: Item {
        id: faceItem

        property string summary: ""
        property string body: ""
        property string iconUrl: ""
        property bool critical: false
        readonly property Item disc: discItem

        width: row.width
        height: Theme.notificationPeekRowHeight

        AppIconDisc {
            id: discItem

            anchors.verticalCenter: parent.verticalCenter
            source: faceItem.iconUrl
            // The blob carries the icon on from here.
            visible: !row.toBlob
        }

        Column {
            x: row.textX
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - x - Theme.notificationPeekDismissReserve)
            spacing: Theme.notificationPeekLineGap

            Label {
                width: parent.width
                maximumLineCount: 1
                text: faceItem.summary
                color: faceItem.critical ? Colors.error : Colors.foreground
                lineHeightPx: Theme.notificationPeekSummaryLineHeight
            }

            Label {
                width: parent.width
                maximumLineCount: 1
                visible: faceItem.body !== ""
                text: faceItem.body
                secondary: true
                font.weight: Font.Normal
                lineHeightPx: Theme.notificationPeekBodyLineHeight
            }
        }
    }
}
