import QtQuick
import ".."
import "../components"

// The Home state of the centre island: Time and Weather over Performance and
// Power, a narrow and a wide column on the 12 px tile grid. The height is fixed
// by the Theme tokens, so the island grows to it in one animation.
Item {
    id: panel

    property bool shown: false

    readonly property real wideColumnX: Theme.panelPadding + Theme.homeTimeColumnWidth + Theme.tileGap
    readonly property real wideColumnWidth: width - wideColumnX - Theme.panelPadding
    readonly property real bottomRowY: Theme.panelPadding + Theme.homeTopRowHeight + Theme.tileGap

    implicitWidth: Theme.panelWidths.home
    implicitHeight: Theme.homeHeight

    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    TimeTile {
        objectName: "timeTile"
        x: Theme.panelPadding
        y: Theme.panelPadding
        width: Theme.homeTimeColumnWidth
        height: Theme.homeTopRowHeight
    }

    // Declared in reading order, which is also the Tab order of their segmented controls.
    WeatherTile {
        objectName: "weatherTile"
        x: panel.wideColumnX
        y: Theme.panelPadding
        width: panel.wideColumnWidth
        height: Theme.homeTopRowHeight
    }

    PerformanceTile {
        objectName: "performanceTile"
        x: Theme.panelPadding
        y: panel.bottomRowY
        width: Theme.homeTimeColumnWidth
        height: Theme.homeBottomRowHeight
    }

    PowerTile {
        objectName: "powerTile"
        x: panel.wideColumnX
        y: panel.bottomRowY
        width: panel.wideColumnWidth
        height: Theme.homeBottomRowHeight
    }
}
