pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Theme state of the centre island: Light / Dark / Auto, then the matugen
// schemes as a strip of cards. Left and Right move the selection, Enter or a
// click applies it; the applied scheme carries a dot.
Panel {
    id: panel

    name: "theme"

    readonly property int appliedIndex: Appearance.schemes.findIndex(scheme => scheme.value === Appearance.scheme)
    readonly property var modes: [
        {
            text: "Light",
            mode: "light"
        },
        {
            text: "Dark",
            mode: "dark"
        },
        {
            text: "Auto",
            mode: "auto"
        }
    ]

    implicitHeight: Theme.themePanelHeight

    onOpened: {
        Appearance.refresh();
        schemes.centreOn(Math.max(0, appliedIndex));
        focusWhenShown(schemes);
    }

    SegmentedControl {
        id: mode

        objectName: "themeMode"
        x: (panel.width - width) / 2
        y: Theme.panelPadding
        width: Theme.themeModeWidth
        accessibleName: "Theme mode"
        fontSize: Theme.themeModeFontSize
        interactive: !Appearance.busy
        // Static disabled look while DMS works: nothing may animate under the
        // frozen frame of the screen crossfade.
        opacity: Appearance.busy ? Theme.busyOpacity : 1
        model: panel.modes.map(entry => entry.text)
        // A change of currentIndex never emits selected: only a click or a key does.
        currentIndex: panel.modes.findIndex(entry => entry.mode === Appearance.displayedMode)
        onSelected: index => Appearance.requestMode(panel.modes[index].mode)
    }

    Carousel {
        id: schemes

        objectName: "schemes"
        opacity: Appearance.busy ? Theme.busyOpacity : 1
        y: mode.y + mode.height + Theme.tileGap
        width: panel.width
        height: Theme.schemeCardHeight + 2 * Theme.carouselPadding
        accessibleName: "Colour schemes"
        model: Appearance.schemes
        onActivated: index => {
            if (!Appearance.busy)
                Appearance.setScheme(Appearance.schemes[index].value);
        }

        delegate: Item {
            id: card

            required property var modelData
            required property int index

            readonly property bool selected: index === schemes.currentIndex
            readonly property bool applied: index === panel.appliedIndex

            objectName: "schemeCard"
            width: Theme.schemeCardWidth
            height: schemes.height

            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.text + (applied ? ", applied" : "")
            Accessible.selected: selected

            Rectangle {
                y: Theme.carouselPadding
                width: parent.width
                height: Theme.schemeCardHeight
                radius: Theme.schemeCardRadius
                color: pointer.containsMouse ? Colors.hoverSurface : Colors.surfaceContainerHigh
                border.width: Theme.focusRingWidth
                border.color: card.selected ? Colors.primary : "transparent"

                Behavior on border.color {
                    ColorCrossfade {}
                }

                Row {
                    x: Theme.schemeCardPadding
                    y: Theme.schemeCardPadding
                    spacing: Theme.schemeDotGap

                    Repeater {
                        model: Appearance.previewPalette(card.modelData.value)

                        Rectangle {
                            required property color modelData

                            width: Theme.schemeDotSize
                            height: Theme.schemeDotSize
                            radius: width / 2
                            color: modelData
                            border.width: Theme.hairlineWidth
                            border.color: Colors.dotOutline
                        }
                    }
                }

                Label {
                    x: Theme.schemeCardPadding
                    y: Theme.schemeCardPadding + Theme.schemeDotSize + Theme.schemeDotsGap
                    width: parent.width - 2 * Theme.schemeCardPadding
                    height: Theme.schemeLabelHeight
                    verticalAlignment: Text.AlignVCenter
                    text: card.modelData.text
                    secondary: true
                }

                Rectangle {
                    objectName: "appliedMarker"
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: Theme.schemeCardPadding
                    width: Theme.thumbMarker
                    height: width
                    radius: width / 2
                    color: Colors.primary
                    opacity: card.applied ? 1 : 0

                    Behavior on opacity {
                        Crossfade {}
                    }
                }
            }

            MouseArea {
                id: pointer

                anchors.fill: parent
                enabled: !Appearance.busy
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                    schemes.select(card.index);
                    schemes.activated(card.index);
                }
            }
        }
    }
}
