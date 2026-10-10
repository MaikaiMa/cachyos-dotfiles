pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Wallpaper state of the centre island: the DMS wallpaper folder as a strip
// of thumbnails. Left and Right move the selection, Enter or a click applies
// it; the current wallpaper carries a dot. Thumbnails load small and
// asynchronously, and only for the cards in and near view.
Panel {
    id: panel

    name: "wallpaper"

    property bool centredOnCurrent: false

    readonly property int currentIndex: Wallpapers.files.indexOf(Wallpapers.current)

    implicitHeight: Theme.wallpaperPanelHeight

    onOpened: {
        centredOnCurrent = false;
        Wallpapers.refresh(Shell.screenName);
        centreOnCurrent();
        focusWhenShown(walls);
    }

    // The list and the current path arrive after the panel opened.
    onCurrentIndexChanged: centreOnCurrent()

    function centreOnCurrent() {
        if (centredOnCurrent || !shown)
            return;
        walls.centreOn(Math.max(0, currentIndex));
        centredOnCurrent = currentIndex >= 0;
    }

    Label {
        anchors.centerIn: parent
        visible: !Wallpapers.loading && Wallpapers.files.length === 0
        text: "No wallpapers in " + Wallpapers.folder
        secondary: true
    }

    Rectangle {
        id: thumbMask

        width: Theme.thumbWidth
        height: Theme.thumbHeight
        radius: Theme.thumbRadius
        visible: false
        layer.enabled: true
    }

    Carousel {
        id: walls

        objectName: "wallpapers"
        y: Theme.panelPadding
        width: panel.width
        height: panel.height - 2 * Theme.panelPadding
        accessibleName: "Wallpapers"
        adoptOnSettle: true
        model: Wallpapers.files
        onActivated: index => Wallpapers.set(Wallpapers.files[index], Shell.screenName)

        delegate: Item {
            id: thumb

            required property string modelData
            required property int index

            readonly property bool selected: index === walls.currentIndex
            readonly property bool applied: modelData === Wallpapers.current

            objectName: "wallpaperThumb"
            width: Theme.thumbWidth + 2 * Theme.thumbRing
            height: walls.height

            Accessible.role: Accessible.ListItem
            Accessible.name: Wallpapers.displayName(modelData) + (applied ? ", current" : "")
            Accessible.selected: selected

            // The selection ring keeps a gap to the picture.
            Rectangle {
                x: Theme.thumbRing - Theme.thumbRingOffset
                y: Theme.thumbRing - Theme.thumbRingOffset
                width: Theme.thumbWidth + 2 * Theme.thumbRingOffset
                height: Theme.thumbHeight + 2 * Theme.thumbRingOffset
                radius: Theme.thumbRadius + Theme.thumbRingOffset
                color: "transparent"
                border.width: Theme.focusRingWidth
                border.color: thumb.selected ? Colors.primary : "transparent"

                Behavior on border.color {
                    ColorCrossfade {}
                }
            }

            Item {
                x: Theme.thumbRing
                y: Theme.thumbRing
                width: Theme.thumbWidth
                height: Theme.thumbHeight

                Rectangle {
                    anchors.fill: parent
                    radius: Theme.thumbRadius
                    color: Colors.surfaceContainerHigh
                }

                RoundedImage {
                    objectName: "thumbImage"
                    anchors.fill: parent
                    source: Wallpapers.urlFor(thumb.modelData)
                    maskSource: thumbMask
                    fadeIn: true
                }

                Rectangle {
                    objectName: "currentMarker"
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.thumbMarker
                    width: Theme.thumbMarker
                    height: width
                    radius: width / 2
                    color: Colors.primary
                    border.width: 2
                    border.color: Colors.surface
                    opacity: thumb.applied ? 1 : 0

                    Behavior on opacity {
                        Crossfade {}
                    }
                }
            }

            Label {
                x: Theme.thumbRing
                y: Theme.thumbRing + Theme.thumbHeight + Theme.thumbLabelGap
                width: Theme.thumbWidth
                height: Theme.thumbLabelHeight
                verticalAlignment: Text.AlignVCenter
                text: Wallpapers.displayName(thumb.modelData)
                secondary: true
                color: thumb.applied ? Colors.foreground : Colors.foregroundVariant
            }

            MouseArea {
                id: pointer

                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    walls.select(thumb.index);
                    walls.activated(thumb.index);
                }
            }
        }
    }
}
