pragma Singleton

import QtQuick
import Quickshell

// Sizes and fonts from the Tokens table in docs/shell-design.md.
Singleton {
    readonly property int barHeight: 36

    readonly property int islandHeight: 30
    readonly property int islandDetailHeight: 48
    readonly property int islandTop: (barHeight - islandHeight) / 2
    readonly property int islandRadius: 15
    readonly property int islandRadiusExpanded: 20
    // The DMS bar and popup transparency, over the blur behind the islands.
    readonly property real islandOpacity: 0.92
    readonly property real panelOpacity: 0.92
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
    readonly property int panelPadding: 12
    readonly property int tileGap: 12
    readonly property int tileRadius: 16
    readonly property int toggleIconSize: 18

    readonly property int settingsColumns: 4
    readonly property int settingsTileHeight: 64
    readonly property int settingsTileRows: 2
    readonly property int tileIconDisc: 34
    readonly property int sliderHeight: 32
    readonly property int sliderGap: 8
    readonly property int sliderCount: 3
    readonly property int sliderIconZone: 32
    readonly property int sliderValueZone: 44
    readonly property int sliderValueFontSize: 12
    // Movement below this is a click, not a drag.
    readonly property int sliderDragThreshold: 4
    // One arrow key press or one wheel notch.
    readonly property int sliderStep: 5
    readonly property int notificationHeaderGap: 10
    readonly property int notificationHeaderHeight: 28
    readonly property int notificationRowHeight: 62
    readonly property int notificationRowGap: 6
    readonly property int notificationRowRadius: 14
    readonly property int notificationListMaxHeight: 240
    readonly property int settingsGridHeight: settingsTileRows * settingsTileHeight + (settingsTileRows - 1) * tileGap
    readonly property int settingsSlidersHeight: sliderCount * sliderHeight + (sliderCount - 1) * sliderGap

    // Home: a narrow and a wide column; row heights are fixed so the panel has one height.
    readonly property int homeTimeColumnWidth: 150
    readonly property int homeTilePadding: 12
    readonly property int homeSectionGap: 10
    readonly property int homeTimeFontSize: 44
    readonly property int homeLargeFontSize: 22
    readonly property int homeDetailFontSize: 12
    readonly property int segmentedHeight: 28
    readonly property int segmentedInset: 3
    readonly property int weatherNowHeight: 40
    readonly property int weatherNowIconSize: 28
    readonly property int weatherTabsWidth: 150
    readonly property int weatherCardCount: 5
    readonly property int weatherCardWidth: 64
    readonly property int weatherCardHeight: 72
    readonly property int weatherCardRadius: 12
    readonly property int meterWidth: 6
    // The temperature bar runs from empty at 30 °C to full at 95 °C.
    readonly property int tempScaleMin: 30
    readonly property int tempScaleMax: 95
    readonly property int powerHeadHeight: 28
    readonly property int powerIconSize: 20
    readonly property int chargeCapsuleHeight: 20
    readonly property int powerStatsHeight: 34
    readonly property int homeTopRowHeight: 2 * homeTilePadding + weatherNowHeight + 2 * homeSectionGap + segmentedHeight + weatherCardHeight
    readonly property int homeBottomRowHeight: 2 * homeTilePadding + powerHeadHeight + 3 * homeSectionGap + chargeCapsuleHeight + powerStatsHeight + segmentedHeight
    readonly property int homeHeight: 2 * panelPadding + homeTopRowHeight + tileGap + homeBottomRowHeight

    // Placeholder bodies until the real panels set their own height.
    readonly property int placeholderPanelHeight: 240
    readonly property int musicBarWidth: 360
    readonly property int osdWidth: 200

    Component.onCompleted: {
        if (!iconFontAvailable)
            console.warn("Theme: font \"" + iconFontFamily + "\" not found; icons are drawn as placeholders. Install ttf-material-symbols-variable.");
    }
}
