pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// One notification in the Settings list: app icon, app name, summary, one line
// of body and a dismiss button. A click expands it in place: the full body,
// the image, every action and the inline reply, the last two only while the
// sender's notification is alive. Leaving collapses it, then it reports gone.
Item {
    id: row

    // Named like the roles of the panel's model, which fills them in.
    required property string notificationId
    required property string appName
    required property string summary
    required property string body
    required property string appIcon
    required property string image
    required property string desktopEntry
    property bool leaving: false
    property bool expanded: false

    signal dismissClicked
    signal toggled
    signal actionInvoked(string identifier)
    signal replySent(string text)
    signal gone

    readonly property var notification: Notifications.liveIds.includes(notificationId) ? Notifications.liveObject(notificationId) : null
    readonly property string iconSource: Notifications.iconSource(appIcon, desktopEntry, image)
    // A live image may be raw data the history cannot keep; the icon may already
    // be the image, then it is not shown twice.
    readonly property string fullImage: {
        const source = notification ? Notifications.storedImage(notification.image ?? "") || (notification.image ?? "") : image;
        return source === iconSource ? "" : source;
    }
    readonly property var actions: expanded ? Notifications.pillActions(notification) : []
    readonly property bool replyShown: expanded && !!notification && notification.hasInlineReply
    readonly property bool imageShown: expanded && fullImage !== "" && fullImageItem.status === Image.Ready

    readonly property real textBlockHeight: Theme.notificationRowPadding + appLine.height + summaryLine.height + bodyLine.height
    readonly property real expandedHeight: {
        let height = Math.max(textBlockHeight, imageShown ? Theme.notificationRowPadding + Theme.notificationImageMaxSize : 0) + Theme.notificationRowPadding;
        if (actions.length > 0)
            height += actionFlow.implicitHeight + Theme.notificationRowPadding;
        if (replyShown)
            height += Theme.listRowFieldHeight + Theme.notificationRowPadding;
        return Math.max(Theme.notificationRowHeight, Math.ceil(height));
    }
    // What the row settles at, for the panel's height while this one is open.
    readonly property real expansionExtra: expanded && !leaving ? expandedHeight - Theme.notificationRowHeight : 0

    function submitReply() {
        if (replyField.text === "")
            return;
        const text = replyField.text;
        replyField.text = "";
        row.replySent(text);
    }

    implicitHeight: leaving ? 0 : expanded ? expandedHeight : Theme.notificationRowHeight
    height: implicitHeight
    opacity: leaving ? 0 : 1
    clip: true

    // Leaving keeps its quick collapse; expanding uses the island's grow and shrink.
    Behavior on implicitHeight {
        NumberAnimation {
            duration: row.leaving ? Motion.crossfadeDuration : row.expanded ? Motion.growDuration : Motion.shrinkDuration
            easing.type: row.leaving ? Motion.crossfadeEasing : Easing.BezierSpline
            easing.bezierCurve: row.expanded ? Motion.growCurve : Motion.shrinkCurve
        }
    }

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    onHeightChanged: {
        if (leaving && height === 0)
            gone();
    }
    onExpandedChanged: {
        if (!expanded)
            replyField.text = "";
    }

    Rectangle {
        width: parent.width
        height: Math.max(Theme.notificationRowHeight, row.height)
        radius: Theme.notificationRowRadius
        color: Colors.surfaceContainerHigh

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            enabled: !row.leaving
            onClicked: row.toggled()
        }

        Rectangle {
            id: badge

            x: 10
            y: (Theme.notificationRowHeight - height) / 2
            width: 26
            height: 26
            radius: 8
            color: Qt.alpha(Colors.foreground, 0.07)

            Image {
                id: appImage

                anchors.centerIn: parent
                width: Theme.iconSize
                height: Theme.iconSize
                sourceSize.width: Theme.iconSize * 2
                sourceSize.height: Theme.iconSize * 2
                source: row.iconSource
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
            id: textColumn

            anchors.left: badge.right
            anchors.leftMargin: 10
            anchors.right: row.imageShown ? imageBox.left : dismiss.left
            anchors.rightMargin: 6
            y: Theme.notificationRowPadding

            RowText {
                id: appLine

                text: row.appName
                color: Colors.foregroundVariant
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Font.Normal
                lineHeight: 14
            }

            RowText {
                id: summaryLine

                text: Notifications.oneLine(row.summary)
                color: Colors.foreground
                font.pixelSize: Theme.fontSize
                lineHeight: 17
            }

            RowText {
                id: bodyLine

                text: row.expanded ? Notifications.plainText(row.body).trim() : Notifications.oneLine(row.body)
                color: Colors.foregroundVariant
                font.pixelSize: 12
                font.weight: Font.Normal
                lineHeight: Theme.notificationBodyLineHeight
                wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                maximumLineCount: row.expanded ? Theme.notificationBodyMaxLines : 1
            }
        }

        Item {
            id: imageBox

            anchors.right: dismiss.left
            anchors.rightMargin: 6
            y: Theme.notificationRowPadding
            width: Theme.notificationImageMaxSize
            height: Theme.notificationImageMaxSize
            visible: row.imageShown

            Image {
                id: fullImageItem

                anchors.fill: parent
                sourceSize.width: Theme.notificationImageMaxSize * 2
                sourceSize.height: Theme.notificationImageMaxSize * 2
                source: row.expanded ? row.fullImage : ""
                fillMode: Image.PreserveAspectFit
                horizontalAlignment: Image.AlignRight
                verticalAlignment: Image.AlignTop
                asynchronous: true
            }
        }

        Rectangle {
            id: dismiss

            anchors.right: parent.right
            anchors.rightMargin: 6
            y: (Theme.notificationRowHeight - height) / 2
            width: 22
            height: 22
            radius: 11
            color: dismissPointer.containsMouse ? Qt.alpha(Colors.foreground, 0.07) : "transparent"

            Behavior on color {
                ColorAnimation {
                    duration: Motion.crossfadeDuration
                }
            }

            Icon {
                anchors.centerIn: parent
                name: "close"
                size: 14
                color: dismissPointer.containsMouse ? Colors.foreground : Colors.foregroundVariant
            }

            MouseArea {
                id: dismissPointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                enabled: !row.leaving
                onClicked: row.dismissClicked()
            }

            Accessible.role: Accessible.Button
            Accessible.name: "Dismiss"
        }

        Flow {
            id: actionFlow

            x: textColumn.x
            y: Math.max(row.textBlockHeight, row.imageShown ? Theme.notificationRowPadding + Theme.notificationImageMaxSize : 0) + Theme.notificationRowPadding
            width: parent.width - x - Theme.notificationRowPadding
            spacing: Theme.notificationActionGap
            visible: row.actions.length > 0

            Repeater {
                model: row.actions

                NotificationActionPill {
                    required property var modelData

                    label: modelData.text
                    primary: modelData.primary
                    baseColor: Colors.surfaceContainer
                    onActivated: row.actionInvoked(modelData.identifier)
                }
            }
        }

        Item {
            id: reply

            x: textColumn.x
            y: actionFlow.y + (row.actions.length > 0 ? actionFlow.implicitHeight + Theme.notificationRowPadding : 0)
            width: parent.width - x - Theme.notificationRowPadding
            height: Theme.listRowFieldHeight
            visible: row.replyShown

            Rectangle {
                width: parent.width - sendButton.width - Theme.gap
                height: parent.height
                radius: height / 2
                color: Colors.surfaceContainer
                border.width: replyField.activeFocus ? 2 : 0
                border.color: Colors.primary

                TextInput {
                    id: replyField

                    anchors.fill: parent
                    anchors.leftMargin: 12
                    anchors.rightMargin: 12
                    verticalAlignment: TextInput.AlignVCenter
                    clip: true
                    activeFocusOnTab: row.replyShown
                    color: Colors.foreground
                    selectionColor: Colors.primary
                    selectedTextColor: Colors.primaryForeground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.fontSize

                    // Handled here: TextInput passes Return on.
                    Keys.onPressed: event => {
                        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                            event.accepted = true;
                            row.submitReply();
                        }
                    }

                    Accessible.name: "Reply to " + row.appName

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        visible: replyField.text === ""
                        text: row.notification && row.notification.inlineReplyPlaceholder ? row.notification.inlineReplyPlaceholder : "Reply"
                        color: Colors.foregroundVariant
                        font: replyField.font
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.IBeamCursor
                    onPressed: mouse => {
                        replyField.forceActiveFocus();
                        mouse.accepted = false;
                    }
                }
            }

            NotificationActionPill {
                id: sendButton

                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.notificationReplyWidth
                height: parent.height
                label: "Send"
                primary: true
                baseColor: Colors.surfaceContainer
                onActivated: row.submitReply()
            }
        }
    }

    // A fixed line height, so every collapsed row has the same height.
    component RowText: Text {
        width: parent.width
        maximumLineCount: 1
        elide: Text.ElideRight
        textFormat: Text.PlainText
        lineHeightMode: Text.FixedHeight
        font.family: Theme.fontFamily
        font.weight: Theme.fontWeight
    }
}
