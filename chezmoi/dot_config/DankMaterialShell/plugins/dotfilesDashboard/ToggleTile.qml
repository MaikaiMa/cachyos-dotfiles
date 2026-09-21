import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: tile

    property string iconName: ""
    property string label: ""
    property bool isActive: false
    property string imagePath: ""

    readonly property bool showsImage: imagePath.length > 0 && image.status === Image.Ready
    readonly property color foreground: isActive ? Theme.ccTileActiveText : Theme.surfaceText

    signal clicked

    height: 64
    radius: Theme.cornerRadius + 4
    clip: true
    antialiasing: true
    color: {
        if (isActive)
            return Theme.ccTileActiveBg;
        return mouseArea.containsMouse ? Theme.ccPillInactiveHoverBg : Theme.ccPillInactiveBg;
    }
    border.color: isActive ? Theme.ccTileRing : Theme.outlineMedium
    border.width: isActive ? 1 : Theme.layerOutlineWidth

    Image {
        id: image

        anchors.fill: parent
        source: tile.imagePath.startsWith("/") ? "file://" + tile.imagePath : tile.imagePath
        visible: tile.showsImage
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        cache: true
        sourceSize.width: width * 2
        sourceSize.height: height * 2
    }

    Rectangle {
        anchors.fill: parent
        color: Theme.withAlpha(Theme.surface, 0.45)
        visible: tile.showsImage
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        color: Theme.hoverTint(tile.color)
        opacity: mouseArea.pressed ? 0.3 : (mouseArea.containsMouse ? 0.2 : 0)
        visible: opacity > 0
        antialiasing: true

        Behavior on opacity {
            NumberAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    Column {
        anchors.centerIn: parent
        spacing: Theme.spacingXXS

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tile.iconName
            size: Theme.iconSize - 2
            color: tile.foreground
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            font.pixelSize: Theme.fontSizeSmall
            color: tile.isActive ? Theme.ccTileActiveText : Theme.surfaceVariantText
            elide: Text.ElideRight
            width: Math.min(implicitWidth, tile.width - Theme.spacingS * 2)
            horizontalAlignment: Text.AlignHCenter
        }
    }

    DankRipple {
        id: ripple

        cornerRadius: tile.radius
    }

    MouseArea {
        id: mouseArea

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onPressed: mouse => ripple.trigger(mouse.x, mouse.y)
        onClicked: tile.clicked()
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
        }
    }
}
