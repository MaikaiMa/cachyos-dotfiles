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
        NumberAnimation {
            duration: row.actionMotion ? Motion.trayDuration : row.leaving ? Motion.shrinkDuration : Motion.growDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: row.actionMotion || !row.leaving ? Motion.growCurve : Motion.shrinkCurve
        }
    }
    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }
    Behavior on revealProgress {
        NumberAnimation {
            duration: Motion.trayDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.growCurve
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

        NumberAnimation {
            target: ghost
            property: "opacity"
            from: 1
            to: 0
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
        NumberAnimation {
            target: face
            property: "opacity"
            from: 0
            to: 1
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
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

            Text {
                id: actionLabel

                required property var modelData

                height: Theme.notificationPeekActionHeight
                verticalAlignment: Text.AlignVCenter
                text: modelData.text
                textFormat: Text.PlainText
                color: modelData.primary ? Colors.primary : Colors.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.notificationPeekActionFontSize
                font.weight: Theme.fontWeight
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

    Item {
        id: dismissButton

        objectName: "dismiss"
        x: parent.width - Theme.notificationPeekDismissInset - (Theme.iconSize + Theme.notificationPeekDismissHit) / 2
        y: Theme.notificationPeekDismissInset - (Theme.notificationPeekDismissHit - Theme.iconSize) / 2
        width: Theme.notificationPeekDismissHit
        height: Theme.notificationPeekDismissHit
        opacity: row.dismissShown ? 1 : 0
        visible: opacity > 0
        enabled: row.dismissShown
        activeFocusOnTab: row.dismissShown

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                event.accepted = true;
                row.dismiss();
            }
        }

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        Icon {
            anchors.centerIn: parent
            name: "close"
            color: dismissPointer.containsMouse ? Colors.foreground : Colors.foregroundVariant

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }
        }

        MouseArea {
            id: dismissPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: row.dismiss()
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Colors.primary
            visible: dismissButton.activeFocus
        }

        Accessible.role: Accessible.Button
        Accessible.name: "Dismiss " + row.summaryText
        Accessible.onPressAction: row.dismiss()
    }

    Rectangle {
        objectName: "hairline"
        y: row.contentHeight + (Theme.notificationPeekRowGap - height) / 2
        width: parent.width
        height: Theme.hairlineWidth
        color: Qt.alpha(Colors.outline, Theme.notificationPeekHairlineOpacity)
        opacity: row.lastRow ? 0 : 1

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
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

        Rectangle {
            id: discItem

            anchors.verticalCenter: parent.verticalCenter
            width: Theme.notificationPeekDisc
            height: Theme.notificationPeekDisc
            radius: width / 2
            color: Qt.alpha(Colors.foreground, Theme.notificationPeekDiscOpacity)
            // The blob carries the icon on from here.
            visible: !row.toBlob

            Image {
                id: appImage

                anchors.centerIn: parent
                width: Theme.iconSize
                height: Theme.iconSize
                sourceSize.width: Theme.iconSize * 2
                sourceSize.height: Theme.iconSize * 2
                source: faceItem.iconUrl
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                visible: status === Image.Ready
            }

            Icon {
                anchors.centerIn: parent
                visible: !appImage.visible
                name: "notifications"
                color: Colors.foregroundVariant
            }
        }

        Column {
            x: row.textX
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(0, parent.width - x - Theme.notificationPeekDismissReserve)
            spacing: Theme.notificationPeekLineGap

            PeekText {
                text: faceItem.summary
                color: faceItem.critical ? Colors.error : Colors.foreground
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
                lineHeight: Theme.notificationPeekSummaryLineHeight
            }

            PeekText {
                visible: faceItem.body !== ""
                text: faceItem.body
                color: Colors.foregroundVariant
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Font.Normal
                lineHeight: Theme.notificationPeekBodyLineHeight
            }
        }
    }

    component PeekText: Text {
        width: parent.width
        maximumLineCount: 1
        elide: Text.ElideRight
        textFormat: Text.PlainText
        lineHeightMode: Text.FixedHeight
        font.family: Theme.fontFamily
    }
}
