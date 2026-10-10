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
            height += Theme.fieldHeight + Theme.notificationRowPadding;
        return Math.max(Theme.notificationRowHeight, Math.ceil(height));
    }
    // What the row settles at, for the panel's height while this one is open.
    readonly property real expansionExtra: expanded && !leaving ? expandedHeight - Theme.notificationRowHeight : 0

    implicitHeight: leaving ? 0 : expanded ? expandedHeight : Theme.notificationRowHeight
    height: implicitHeight
    opacity: leaving ? 0 : 1
    clip: true

    // Leaving keeps its quick collapse; expanding uses the island's grow and shrink.
    Behavior on implicitHeight {
        MorphAnimation {
            shrinking: !row.expanded
            durationOverride: row.leaving ? Motion.crossfadeDuration : -1
            easing.type: row.leaving ? Motion.crossfadeEasing : Easing.BezierSpline
        }
    }

    Behavior on opacity {
        Crossfade {}
    }

    onHeightChanged: {
        if (leaving && height === 0)
            gone();
    }
    onExpandedChanged: {
        if (!expanded)
            reply.clear();
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

        AppIconDisc {
            id: badge

            x: Theme.notificationBadgeInset
            y: (Theme.notificationRowHeight - height) / 2
            size: Theme.notificationBadge
            radius: Theme.notificationBadgeRadius
            source: row.iconSource
        }

        Column {
            id: textColumn

            anchors.left: badge.right
            anchors.leftMargin: Theme.notificationTextGap
            anchors.right: row.imageShown ? imageBox.left : dismiss.left
            anchors.rightMargin: Theme.notificationColumnGap
            y: Theme.notificationRowPadding

            Label {
                id: appLine

                width: parent.width
                maximumLineCount: 1
                text: row.appName
                secondary: true
                font.weight: Font.Normal
                lineHeightPx: Theme.notificationAppLineHeight
            }

            Label {
                id: summaryLine

                width: parent.width
                maximumLineCount: 1
                text: Notifications.oneLine(row.summary)
                lineHeightPx: Theme.notificationSummaryLineHeight
            }

            Label {
                id: bodyLine

                width: parent.width
                text: row.expanded ? Notifications.plainText(row.body).trim() : Notifications.oneLine(row.body)
                color: Colors.foregroundVariant
                font.pixelSize: Theme.notificationBodyFontSize
                font.weight: Font.Normal
                lineHeightPx: Theme.notificationBodyLineHeight
                wrapMode: row.expanded ? Text.Wrap : Text.NoWrap
                maximumLineCount: row.expanded ? Theme.notificationBodyMaxLines : 1
            }
        }

        Item {
            id: imageBox

            anchors.right: dismiss.left
            anchors.rightMargin: Theme.notificationColumnGap
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

        IconButton {
            id: dismiss

            anchors.right: parent.right
            anchors.rightMargin: Theme.notificationColumnGap
            y: (Theme.notificationRowHeight - height) / 2
            size: Theme.notificationDismissSize
            iconName: "close"
            iconSize: Theme.smallIconSize
            iconColor: dismiss.hovered ? Colors.foreground : Colors.foregroundVariant
            enabled: !row.leaving
            accessibleName: "Dismiss"
            onActivated: row.dismissClicked()
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

                PillButton {
                    required property var modelData

                    text: modelData.text
                    tone: modelData.primary ? "accent" : "neutral"
                    fontSize: Theme.notificationActionFontSize
                    horizontalPadding: Theme.notificationActionPadding
                    maxWidth: Theme.notificationActionMaxWidth
                    baseColor: Colors.surfaceContainer
                    onActivated: row.actionInvoked(modelData.identifier)
                }
            }
        }

        InlineField {
            id: reply

            x: textColumn.x
            y: actionFlow.y + (row.actions.length > 0 ? actionFlow.implicitHeight + Theme.notificationRowPadding : 0)
            width: parent.width - x - Theme.notificationRowPadding
            height: Theme.fieldHeight
            visible: row.replyShown
            focusable: row.replyShown
            placeholder: row.notification && row.notification.inlineReplyPlaceholder ? row.notification.inlineReplyPlaceholder : "Reply"
            accessibleName: "Reply to " + row.appName
            buttonText: "Send"
            buttonWidth: Theme.notificationReplyWidth
            button.tone: "accent"
            button.fontSize: Theme.notificationActionFontSize
            onSubmitted: text => row.replySent(text)
        }
    }
}
