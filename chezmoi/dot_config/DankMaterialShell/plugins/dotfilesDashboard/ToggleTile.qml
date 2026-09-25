import QtQuick
import qs.Common
import qs.Widgets

Rectangle {
    id: tile

    property string iconName: ""
    property string label: ""
    property bool isActive: false
    property string imagePath: ""
    property bool hasDetails: false
    property bool detailsAvailable: false
    property bool detailsOpen: false
    property bool longPressFired: false

    readonly property bool showsImage: imagePath.length > 0 && image.status === Image.Ready
    readonly property color foreground: isActive ? Theme.ccTileActiveText : Theme.surfaceText
    readonly property real tileHeight: 76

    signal clicked
    signal detailsRequested
    signal enableAndExpandRequested

    onHasDetailsChanged: {
        if (!hasDetails)
            longPressTimer.stop();
    }

    height: tileHeight
    radius: Theme.cornerRadius + Theme.spacingXS
    clip: true
    antialiasing: true
    color: {
        if (isActive)
            return Theme.ccTileActiveBg;
        return mouseArea.containsMouse ? Theme.ccPillInactiveHoverBg : Theme.ccPillInactiveBg;
    }
    border.color: {
        if (detailsOpen)
            return Theme.primary;
        return isActive ? Theme.ccTileRing : Theme.outlineMedium;
    }
    border.width: {
        if (detailsOpen)
            return 2;
        return isActive ? 1 : Theme.layerOutlineWidth;
    }

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
        spacing: Theme.spacingXS

        DankIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: tile.iconName
            size: Theme.iconSize
            color: tile.foreground
        }

        StyledText {
            anchors.horizontalCenter: parent.horizontalCenter
            text: tile.label
            font.pixelSize: Theme.fontSizeSmall
            color: tile.isActive ? Theme.ccTileActiveText : Theme.surfaceVariantText
            elide: Text.ElideRight
            width: Math.min(implicitWidth, tile.width - Theme.spacingS * 2 - (tile.detailsAvailable ? (detailsButton.width + Theme.spacingXS) * 2 : 0))
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
        acceptedButtons: tile.detailsAvailable ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton
        onPressed: mouse => {
            tile.longPressFired = false;
            if (tile.hasDetails && mouse.button === Qt.LeftButton)
                longPressTimer.restart();
            ripple.trigger(mouse.x, mouse.y);
        }
        onReleased: longPressTimer.stop()
        onCanceled: longPressTimer.stop()
        onExited: longPressTimer.stop()
        onClicked: mouse => {
            if (mouse.button === Qt.RightButton) {
                tile.detailsRequested();
                return;
            }
            if (tile.longPressFired)
                return;
            tile.clicked();
        }
    }

    Timer {
        id: longPressTimer

        interval: Qt.styleHints.mousePressAndHoldInterval
        onTriggered: {
            tile.longPressFired = true;
            if (tile.detailsAvailable)
                tile.detailsRequested();
            else
                tile.enableAndExpandRequested();
        }
    }

    Rectangle {
        id: detailsButton

        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Theme.spacingXS
        width: 24
        height: 24
        radius: height / 2
        visible: tile.detailsAvailable
        color: detailsArea.containsMouse ? Theme.withAlpha(tile.foreground, 0.16) : "transparent"

        DankIcon {
            anchors.centerIn: parent
            name: "expand_more"
            size: Theme.iconSizeSmall
            color: tile.foreground
            rotation: tile.detailsOpen ? 180 : 0

            Behavior on rotation {
                NumberAnimation {
                    duration: Theme.shortDuration
                }
            }
        }

        MouseArea {
            id: detailsArea

            anchors.fill: parent
            anchors.margins: -Theme.spacingXS
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            Accessible.role: Accessible.Button
            Accessible.name: tile.detailsOpen ? I18n.trFor("dotfilesDashboard", "Hide details") : I18n.trFor("dotfilesDashboard", "Show details")
            onClicked: tile.detailsRequested()
        }

        Behavior on color {
            ColorAnimation {
                duration: Theme.shortDuration
            }
        }
    }

    Behavior on color {
        ColorAnimation {
            duration: Theme.shortDuration
        }
    }
}
