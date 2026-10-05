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

    // Left island: dots in 3 px padded slots; the active one is wider and filled.
    readonly property int workspaceDot: 8
    readonly property int workspaceActiveDot: 22
    readonly property int workspaceDotPadding: 3
    readonly property int workspaceSeparatorSize: 12
    // Under the focused app icon, this far below it.
    readonly property int focusDot: 4
    readonly property int focusDotGap: 2
    // Right island: tray discs and attention pills.
    readonly property int trayDisc: 24
    readonly property int trayOverlap: 10
    readonly property int trayGap: 4
    readonly property int trayStack: 2
    readonly property int trayChevronSize: 10
    // The widest entry sets the menu width, within these bounds.
    readonly property int trayMenuWidth: 160
    readonly property int trayMenuMaxWidth: 280
    readonly property int trayMenuMaxLines: 3
    // Vertical padding of a row, both sides together.
    readonly property int trayMenuRowPadding: 8
    readonly property int trayMenuRowHeight: 32
    readonly property int trayMenuSeparatorHeight: 9
    readonly property int trayMenuInset: 6
    readonly property int trayMenuSubmenuIndent: 12
    readonly property int indicatorPill: 24
    readonly property int indicatorGap: 2
    readonly property int indicatorCountGap: 4
    readonly property int indicatorCountFontSize: 12
    // Keeps an end pill's 12 px corner concentric with the island's 15 px corner.
    readonly property int rightEndInset: 3

    readonly property int powerButtonSize: 72
    // Updates is 420 px in the prototype; the contract table does not list it.
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

    // Updates: count line, fragile rows, a scrolling list and three buttons.
    readonly property int updatesHeadHeight: 20
    readonly property int updatesSectionGap: 8
    readonly property int updatesRowHeight: 32
    readonly property int updatesRowGap: 2
    readonly property int updatesFragileRowHeight: 48
    readonly property int updatesFragileRowGap: 6
    readonly property int updatesListMaxHeight: 280
    readonly property int updatesChipWidth: 50
    readonly property int updatesChipHeight: 18
    readonly property int updatesChipFontSize: 10
    readonly property int updatesRowRadius: 12
    readonly property int updatesActionsGap: 12
    readonly property int updatesButtonHeight: 36

    // Music: the orb sits orbGap left of the pill and glides to orbInset inside
    // the music bar. The bloom reaches orbBloom beyond the rim, and the hit area
    // is the whole bloom.
    readonly property int orbSize: 16
    readonly property int orbGap: 6
    readonly property int orbInset: 7
    readonly property real orbRimWidth: 2
    readonly property int orbBloom: 8
    // Bloom opacity: 0.15 to 0.5 with the low band while playing, a breath on pause.
    readonly property real bloomQuiet: 0.15
    readonly property real bloomLoud: 0.5
    readonly property real bloomBreathMin: 0.1
    readonly property real bloomBreathMax: 0.22
    readonly property int orbHitPadding: orbBloom
    // The prototype's 280 px bar, padding included: orb, gap, text, three controls.
    readonly property int musicBarWidth: 280
    readonly property real musicBarRimWidth: 2.5
    // How far the bar rim's lighter and warmer stops are pushed toward white.
    readonly property real musicBarRimLift: 0.25
    // The bar rim's outer glow: 2 px rings this far outside the edge, at this alpha.
    readonly property var musicBarGlowRings: [[2, 0.3], [4, 0.16], [6, 0.06]]
    readonly property int musicBarGlowRingWidth: 2
    // The Player's quiet rim, without glow.
    readonly property real playerRimWidth: 1.5
    readonly property int musicBarPaddingRight: 6
    readonly property int musicControlSize: 22
    readonly property int musicTitleFontSize: 12
    readonly property int musicArtistGap: 6
    // Space after the run before the marquee turns back.
    readonly property int marqueeTail: 12
    readonly property int marqueeFade: 10

    // Player: cover beside the text, a thin seekable track, controls, outputs.
    readonly property int playerCoverSize: 88
    readonly property int playerCoverRadius: 14
    readonly property int playerCoverGap: 14
    readonly property int playerTitleFontSize: 15
    readonly property int playerTextGap: 2
    readonly property int playerProgressGap: 14
    readonly property int playerTrackHeight: 4
    readonly property int playerTrackHitHeight: 16
    readonly property int playerTimesGap: 5
    readonly property int playerTimesHeight: 13
    readonly property int playerControlsGap: 4
    readonly property int playerControlSpacing: 22
    readonly property int playerControlSize: 32
    readonly property int playerPlaySize: 40
    readonly property int playerControlIconSize: 20
    readonly property int playerPlayIconSize: 18
    readonly property int outputsGap: 12
    readonly property int outputChipHeight: 24
    readonly property int outputChipGap: 6
    readonly property int outputChipPadding: 10
    readonly property int outputChipMaxWidth: 150
    // Seconds per arrow key on the progress track.
    readonly property int playerSeekStep: 5

    // Top-edge wave: a band of light along the top of every screen while music plays.
    readonly property bool topWaveEnabled: true
    readonly property int waveHeight: 48
    readonly property int waveAmplitude: 20
    readonly property real wavePeakOpacity: 0.5
    // Width and alpha of the layered strokes, widest first; they stand in for a blur.
    // Together they reach about 0.95 alpha on the curve, so the top row shows
    // close to the full peak opacity.
    readonly property var waveStrokes: [[58, 0.2], [41, 0.32], [29, 0.5], [24, 0.8]]

    // Placeholder bodies until the real panels set their own height.
    readonly property int placeholderPanelHeight: 240
    readonly property int osdWidth: 200

    Component.onCompleted: {
        if (!iconFontAvailable)
            console.warn("Theme: font \"" + iconFontFamily + "\" not found; icons are drawn as placeholders. Install ttf-material-symbols-variable.");
    }
}
