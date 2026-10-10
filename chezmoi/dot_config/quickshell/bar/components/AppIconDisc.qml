import QtQuick
import ".."

// A notification's app icon on a disc, the bell glyph until or unless the
// image loads. The icon never grows past the disc.
Rectangle {
    id: disc

    property string source: ""
    property int size: Theme.notificationPeekDisc

    width: size
    height: size
    radius: width / 2
    color: Colors.subtleFill

    Image {
        id: appImage

        anchors.centerIn: parent
        width: Math.min(Theme.iconSize, disc.width)
        height: width
        sourceSize.width: Theme.iconSize * 2
        sourceSize.height: Theme.iconSize * 2
        source: disc.source
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
