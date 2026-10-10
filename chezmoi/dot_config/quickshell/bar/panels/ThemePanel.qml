pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Theme state of the centre island: Light / Dark / Auto, then the matugen
// schemes as a strip of cards. Left and Right move the selection, Enter or a
// click applies it; the applied scheme carries a dot.
Appear {
    id: panel

    readonly property int appliedIndex: Appearance.schemes.findIndex(scheme => scheme.value === Appearance.scheme)

    implicitWidth: Theme.panelWidths.theme
    implicitHeight: Theme.themePanelHeight

    onShownChanged: {
        if (!shown)
            return;
        Appearance.refresh();
        schemes.open(Math.max(0, appliedIndex));
        Qt.callLater(() => {
            if (panel.shown)
                schemes.forceActiveFocus();
        });
    }

    // Six representative dots per scheme, drawn from the live palette: running
    // matugen per card is too expensive. Accents (primary, secondary, tertiary),
    // then surface, container and text, shifted in hue and saturation the way
    // each scheme leans. Smart shows the live palette itself.
    readonly property var leanings: ({
            "scheme-tonal-spot": [[0, 0.6], [0, 0.25], [1 / 6, 0.4]],
            "scheme-vibrant": [[0, 1], [0.07, 0.9], [0.14, 0.85]],
            "scheme-content": [[0, 0.85], [0, 0.45], [0.08, 0.55]],
            "scheme-expressive": [[0.66, 0.55], [0.92, 0.6], [0, 0.5]],
            "scheme-fidelity": [[0, 0.95], [0, 0.5], [0.11, 0.6]],
            "scheme-fruit-salad": [[-0.14, 0.75], [0, 0.55], [0.11, 0.7]],
            "scheme-monochrome": [[0, 0], [0, 0], [0, 0]],
            "scheme-neutral": [[0, 0.18], [0, 0.1], [0.1, 0.14]],
            "scheme-rainbow": [[0, 0.6], [1 / 3, 0.5], [2 / 3, 0.5]]
        })

    function dots(value: string): var {
        const lean = leanings[value];
        if (!lean)
            return [Colors.primary, Colors.secondary, Colors.tertiary, Colors.surface, Colors.primaryContainer, Colors.foreground];
        const hue = Math.max(0, Colors.primary.hslHue);
        const saturation = Math.max(0.35, Colors.primary.hslSaturation);
        const dark = Colors.dark;
        const shade = (shift, amount, lightness) => Qt.hsla((hue + shift + 1) % 1, Math.min(1, saturation * amount), lightness, 1);
        const neutral = value === "scheme-monochrome" ? 0 : 0.15;
        return [shade(lean[0][0], lean[0][1], dark ? 0.75 : 0.4), shade(lean[1][0], lean[1][1], dark ? 0.7 : 0.45), shade(lean[2][0], lean[2][1], dark ? 0.75 : 0.42), shade(0, neutral, dark ? 0.08 : 0.96), shade(lean[0][0], lean[0][1] * 0.6, dark ? 0.3 : 0.85), shade(0, neutral * 0.6, dark ? 0.9 : 0.12)];
    }

    SegmentedControl {
        id: mode

        objectName: "themeMode"
        x: (panel.width - width) / 2
        y: Theme.panelPadding
        width: Theme.themeModeWidth
        label: "Theme mode"
        fontSize: Theme.themeModeFontSize
        interactive: !Appearance.busy
        // Static disabled look while DMS works: nothing may animate under the
        // frozen frame of the screen crossfade.
        opacity: Appearance.busy ? Theme.busyOpacity : 1
        model: ["Light", "Dark", "Auto"]
        // The choice shows at once and the accent slides; DMS reports the new
        // mode only after it has rendered, so the service value takes over
        // again once its theme action has settled. A change of currentIndex
        // never emits selected: only a click or a key does.
        property int chosen: -1
        readonly property int reported: Appearance.smartMode ? 2 : Appearance.mode === "light" ? 0 : 1

        currentIndex: chosen >= 0 ? chosen : reported
        onSelected: index => {
            chosen = index;
            if (index === 0) {
                Colors.preview("light");
                Appearance.setLight();
            } else if (index === 1) {
                Colors.preview("dark");
                Appearance.setDark();
            } else {
                Appearance.setAuto();
            }
        }
    }

    Connections {
        target: Appearance

        // Once DMS has settled and answered, its value is adopted once.
        function onReported() {
            mode.chosen = -1;
        }

    }

    Carousel {
        id: schemes

        opacity: Appearance.busy ? Theme.busyOpacity : 1

        objectName: "schemes"
        y: mode.y + mode.height + Theme.tileGap
        width: panel.width
        height: Theme.schemeCardHeight + 2 * Theme.carouselPadding
        label: "Colour schemes"
        model: Appearance.schemes
        onActivated: index => {
            if (!Appearance.busy)
                Appearance.setScheme(Appearance.schemes[index].value);
        }

        delegate: Item {
            id: card

            required property var modelData
            required property int index

            readonly property bool selected: index === schemes.selectedIndex
            readonly property bool applied: index === panel.appliedIndex

            objectName: "schemeCard"
            width: Theme.schemeCardWidth
            height: schemes.height

            Accessible.role: Accessible.ListItem
            Accessible.name: modelData.label + (applied ? ", applied" : "")
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
                        model: panel.dots(card.modelData.value)

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
                    text: card.modelData.label
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
