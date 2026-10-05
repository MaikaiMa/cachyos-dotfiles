pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import ".."
import "../components"
import "../services"

// The Wallpaper state of the centre island: the DMS wallpaper folder as a strip
// of thumbnails. Left and Right move the selection, Enter or a click applies
// it; the current wallpaper carries a dot. Thumbnails load small and
// asynchronously, and only for the cards in and near view.
Item {
    id: panel

    required property string screenName
    property bool shown: false
    // Whether the strip has been centred on the current wallpaper since opening.
    property bool placed: false

    readonly property int currentIndex: Wallpapers.files.indexOf(Wallpapers.current)

    implicitWidth: Theme.panelWidths.wallpaper
    implicitHeight: Theme.wallpaperPanelHeight

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
        if (!shown)
            return;
        placed = false;
        Wallpapers.refresh(screenName);
        place();
        Qt.callLater(() => {
            if (panel.shown)
                walls.forceActiveFocus();
        });
    }

    // The list and the current path arrive after the panel opened.
    onCurrentIndexChanged: place()

    function place() {
        if (placed || !shown)
            return;
        walls.open(Math.max(0, currentIndex));
        placed = currentIndex >= 0;
    }

    function fileUrl(path: string): string {
        return "file://" + path.split("/").map(encodeURIComponent).join("/");
    }

    function label(path: string): string {
        const name = Wallpapers.fileName(path);
        const dot = name.lastIndexOf(".");
        return dot > 0 ? name.slice(0, dot) : name;
    }

    Text {
        anchors.centerIn: parent
        visible: !Wallpapers.loading && Wallpapers.files.length === 0
        text: "No wallpapers in " + Wallpapers.folder
        color: Colors.foregroundVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.secondaryFontSize
        font.weight: Theme.fontWeight
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
        label: "Wallpapers"
        adoptOnSettle: true
        model: Wallpapers.files
        onActivated: index => Wallpapers.apply(Wallpapers.files[index], panel.screenName)

        delegate: Item {
            id: thumb

            required property string modelData
            required property int index

            readonly property bool selected: index === walls.selectedIndex
            readonly property bool applied: modelData === Wallpapers.current

            objectName: "wallpaperThumb"
            width: Theme.thumbWidth + 2 * Theme.thumbRing
            height: walls.height

            Accessible.role: Accessible.ListItem
            Accessible.name: panel.label(modelData) + (applied ? ", current" : "")
            Accessible.selected: selected

            // The selection ring sits 2 px outside the picture.
            Rectangle {
                x: Theme.thumbRing - 4
                y: Theme.thumbRing - 4
                width: Theme.thumbWidth + 8
                height: Theme.thumbHeight + 8
                radius: Theme.thumbRadius + 4
                color: "transparent"
                border.width: 2
                border.color: thumb.selected ? Colors.primary : "transparent"

                Behavior on border.color {
                    ColorAnimation {
                        duration: Motion.crossfadeDuration
                        easing.type: Motion.crossfadeEasing
                    }
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

                Image {
                    id: picture

                    objectName: "thumbImage"
                    anchors.fill: parent
                    source: panel.fileUrl(thumb.modelData)
                    sourceSize.width: 2 * Theme.thumbWidth
                    sourceSize.height: 2 * Theme.thumbHeight
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    visible: false
                }

                // Rounded through the panel's one shared mask, as the Player cover is.
                MultiEffect {
                    anchors.fill: parent
                    source: picture
                    maskEnabled: true
                    maskSource: thumbMask
                    maskThresholdMin: 0.5
                    maskSpreadAtMin: 1
                    opacity: picture.status === Image.Ready ? 1 : 0
                    visible: opacity > 0

                    Behavior on opacity {
                        NumberAnimation {
                            duration: Motion.crossfadeDuration
                            easing.type: Motion.crossfadeEasing
                        }
                    }
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
                        NumberAnimation {
                            duration: Motion.crossfadeDuration
                            easing.type: Motion.crossfadeEasing
                        }
                    }
                }
            }

            Text {
                x: Theme.thumbRing
                y: Theme.thumbRing + Theme.thumbHeight + Theme.thumbLabelGap
                width: Theme.thumbWidth
                height: Theme.thumbLabelHeight
                verticalAlignment: Text.AlignVCenter
                text: panel.label(thumb.modelData)
                elide: Text.ElideRight
                color: thumb.applied ? Colors.foreground : Colors.foregroundVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Theme.fontWeight
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
