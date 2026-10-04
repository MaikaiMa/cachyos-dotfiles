pragma Singleton

import QtQuick
import Quickshell

// Sizes and fonts from the Tokens table in docs/shell-design.md.
Singleton {
    readonly property int barHeight: 36
    // The layer surface cannot draw outside itself, so it is as tall as the largest panel.
    readonly property int windowHeight: 480

    readonly property int islandHeight: 30
    readonly property int islandDetailHeight: 48
    readonly property int islandTop: (barHeight - islandHeight) / 2
    readonly property int islandRadius: 15
    readonly property int islandRadiusExpanded: 20
    readonly property real islandOpacity: 0.92
    readonly property int paddingHorizontal: 10
    readonly property int paddingVertical: 6
    readonly property int gap: 8

    readonly property int hairlineWidth: 1
    readonly property int hairlineHeight: 14
    readonly property real hairlineOpacity: 0.4

    readonly property string fontFamily: "Inter Variable"
    readonly property int fontSize: 13
    readonly property int fontWeight: Font.Medium
    readonly property int secondaryFontSize: 11
    readonly property int iconSize: 16
    // From ttf-material-symbols-variable; without it every Icon draws its placeholder.
    readonly property string iconFontFamily: "Material Symbols Rounded"
    readonly property bool iconFontAvailable: Qt.fontFamilies().includes(iconFontFamily)

    readonly property int shadowOffsetY: 8
    readonly property int shadowBlur: 24
    readonly property real shadowOpacity: 0.35

    readonly property int powerButtonSize: 72
    // Updates has no width in the contract yet; it borrows the Settings width.
    readonly property var panelWidths: ({
            home: 560,
            settings: 420,
            player: 360,
            power: 5 * powerButtonSize + 4 * gap + 2 * paddingHorizontal,
            theme: 560,
            wallpaper: 560,
            updates: 420
        })
    // Placeholder bodies until the real panels set their own height.
    readonly property int placeholderPanelHeight: 240
    readonly property int musicBarWidth: 360
    readonly property int osdWidth: 200

    Component.onCompleted: {
        if (!iconFontAvailable)
            console.warn("Theme: font \"" + iconFontFamily + "\" not found; icons are drawn as placeholders. Install ttf-material-symbols-variable.");
    }
}
