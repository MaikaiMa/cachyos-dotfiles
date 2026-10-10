pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Home state of the centre island: Time and Weather over Performance and
// Power, a narrow and a wide column on the 12 px tile grid, and a row of
// icon-only tiles that morph Home into the other panels, so each is reachable
// by touch. The height is fixed by the Theme tokens, so the island grows to it
// in one animation.
Panel {
    id: panel

    name: "home"

    readonly property real wideColumnX: Theme.panelPadding + Theme.homeTimeColumnWidth + Theme.tileGap
    readonly property real wideColumnWidth: width - wideColumnX - Theme.panelPadding
    readonly property real bottomRowY: Theme.panelPadding + Theme.homeTopRowHeight + Theme.tileGap
    readonly property real actionsRowY: bottomRowY + Theme.homeBottomRowHeight + Theme.tileGap

    readonly property var actions: [
        {
            state: "theme",
            title: "Theme",
            icon: "palette"
        },
        {
            state: "wallpaper",
            title: "Wallpaper",
            icon: "wallpaper"
        },
        {
            state: "player",
            title: "Player",
            icon: "music_note"
        },
        {
            state: "updates",
            title: "Updates",
            icon: "download"
        },
        {
            state: "settings",
            title: "Settings",
            icon: "tune"
        },
        {
            state: "power",
            title: "Power",
            icon: "power_settings_new"
        }
    ]
    readonly property var shownActions: actions.filter(action => action.state !== "player" || Music.hasPlayer)
    readonly property real actionWidth: (width - 2 * Theme.panelPadding - (shownActions.length - 1) * Theme.tileGap) / shownActions.length

    implicitHeight: Theme.homeHeight

    TimeTile {
        objectName: "timeTile"
        x: panel.contentX
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
        x: panel.contentX
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

    // Last in the Tab order, after the power profile control.
    Repeater {
        model: panel.shownActions

        Tile {
            required property var modelData
            required property int index

            objectName: "homeAction"
            x: Theme.panelPadding + index * (panel.actionWidth + Theme.tileGap)
            y: panel.actionsRowY
            width: panel.actionWidth
            height: Theme.homeActionHeight
            title: modelData.title
            iconName: modelData.icon
            checkable: false
            onActivated: Shell.open(modelData.state, Shell.screenName)
        }
    }
}
