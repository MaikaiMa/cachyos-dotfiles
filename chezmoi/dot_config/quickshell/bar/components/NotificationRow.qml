import QtQuick
import Quickshell
import ".."

// One notification in the Settings list: app icon, app name, summary, one line
// of body and a dismiss button. Leaving collapses it, then it reports gone.
Item {
    id: row

    // Named like the roles of the panel's model, which fills them in.
    required property string appName
    required property string summary
    required property string body
    required property string appIcon
    required property string image
    required property string desktopEntry
    property bool leaving: false

    signal dismissClicked
    signal gone

    // The app's own icon first; the notification image is often content (an
    // avatar, a screenshot) and only stands in when the app has none.
    readonly property string iconSource: {
        for (const candidate of [appIcon, desktopEntry]) {
            if (candidate === "")
                continue;
            if (/^(\/|[a-z]+:)/.test(candidate))
                return candidate.startsWith("/") ? "file://" + candidate : candidate;
            const path = Quickshell.iconPath(candidate, true);
            if (path !== "")
                return path;
        }
        return image;
    }

    // Bodies may carry the basic markup of the notification spec and line breaks.
    function oneLine(text: string): string {
        return text.replace(/<[^>]*>/g, "").replace(/\s+/g, " ").trim();
    }

    implicitHeight: leaving ? 0 : Theme.notificationRowHeight
    height: implicitHeight
    opacity: leaving ? 0 : 1
    clip: true

    Behavior on implicitHeight {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
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

    Rectangle {
        width: parent.width
        height: Theme.notificationRowHeight
        radius: Theme.notificationRowRadius
        color: Colors.surfaceContainerHigh

        Rectangle {
            id: badge

            x: 10
            anchors.verticalCenter: parent.verticalCenter
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
            anchors.left: badge.right
            anchors.leftMargin: 10
            anchors.right: dismiss.left
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter

            RowText {
                text: row.appName
                color: Colors.foregroundVariant
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Font.Normal
                lineHeight: 14
            }

            RowText {
                text: row.oneLine(row.summary)
                color: Colors.foreground
                font.pixelSize: Theme.fontSize
                lineHeight: 17
            }

            RowText {
                text: row.oneLine(row.body)
                color: Colors.foregroundVariant
                font.pixelSize: 12
                font.weight: Font.Normal
                lineHeight: 15
            }
        }

        Rectangle {
            id: dismiss

            anchors.right: parent.right
            anchors.rightMargin: 6
            anchors.verticalCenter: parent.verticalCenter
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
    }

    // One line each with a fixed line height, so every row has the same height.
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
