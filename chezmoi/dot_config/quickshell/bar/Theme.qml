pragma Singleton

import QtQuick
import Quickshell

// Sizes and fonts from the Tokens table in docs/shell-design.md.
Singleton {
    readonly property int barHeight: 36

    readonly property int islandHeight: 30
    readonly property int islandDetailHeight: 48
    // Every vertical position derives from this: islands, orb, Detail, panels, hiding.
    readonly property int islandTop: 5
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
    // The type scale; the domain sizes below are names for its steps.
    readonly property int fontSizeSmall: 11
    readonly property int fontSizeDetail: 12
    readonly property int fontSize: 13
    readonly property int fontSizeTitle: 15
    readonly property int fontSizeLarge: 22
    readonly property int fontSizeDisplay: 44
    readonly property int fontWeight: Font.Medium
    readonly property int secondaryFontSize: fontSizeSmall
    readonly property int iconSize: 16
    readonly property int smallIconSize: 14
    // From ttf-material-symbols-variable; without it every Icon draws its placeholder.
    readonly property string iconFontFamily: "Material Symbols Rounded"
    readonly property bool iconFontAvailable: Qt.fontFamilies().includes(iconFontFamily)

    readonly property int shadowOffsetY: 8
    readonly property int shadowBlur: 24
    readonly property real shadowOpacity: 0.35

    // Keyboard focus: a ring this far outside the focused item.
    readonly property int focusRingInset: 3
    readonly property int focusRingWidth: 2
    // Interaction states, as alphas over a surface (see Colors.hovered).
    readonly property real hoverTint: 0.16
    readonly property real hoverTintOnAccent: 0.10
    readonly property real selectedTint: 0.22
    readonly property real subtleFillOpacity: 0.07
    readonly property real errorSurfaceTint: 0.14
    readonly property real errorChipTint: 0.18
    readonly property real dotOutlineOpacity: 0.12
    readonly property real disabledOpacity: 0.5
    // A muted level: the fill of a muted slider or OSD.
    readonly property real mutedOpacity: 0.4
    readonly property int scrollHintWidth: 4
    readonly property real scrollHintOpacity: 0.25
    // Text pills and buttons; a text-only button pads its label by these.
    readonly property int pillHeight: 24
    readonly property int pillPadding: 10
    readonly property int textButtonPadding: 8
    readonly property int textButtonPaddingVertical: 4
    // A one-line text field with a button after it, and the field's text inset.
    readonly property int fieldHeight: 32
    readonly property int fieldPadding: 12
    // Lists that scroll: Wi-Fi, Bluetooth and the notifications.
    readonly property int listMaxHeight: 240
    // A small glyph and a name over a group of rows.
    readonly property int sectionHeaderSpacing: 6

    // Left island: dots in 3 px padded slots; the active one is wider and filled.
    readonly property int workspaceDot: 8
    readonly property int workspaceActiveDot: 22
    readonly property int workspaceDotPadding: 3
    readonly property int workspaceSeparatorSize: 12
    readonly property real workspaceOccupiedOpacity: 0.75
    readonly property real workspaceEmptyOpacity: 0.45
    // An app icon of the active workspace that is not its active window.
    readonly property real inactiveAppOpacity: 0.5
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
    readonly property int indicatorCountFontSize: fontSizeDetail
    // Keeps an end pill's 12 px corner concentric with the island's 15 px corner.
    readonly property int rightEndInset: 3

    readonly property int powerButtonSize: 72
    // Updates is 420 px in the prototype; the contract table does not list it.
    readonly property var panelWidths: ({
            home: 560,
            settings: 420,
            player: 360,
            power: 5 * powerButtonSize + 4 * gap + 2 * powerPanelPadding,
            theme: 560,
            wallpaper: 560,
            updates: 420,
            wifi: 420,
            bluetooth: 420,
            sound: 420,
            display: 420
        })
    readonly property int panelPadding: 12
    readonly property int tileGap: 12
    readonly property int tileRadius: 16
    readonly property int toggleIconSize: 18
    // A wide tile: its icon disc and text this far from the edges, on the
    // accent a lighter disc and a dimmed state line.
    readonly property int tileContentInset: 12
    readonly property int tileTextGap: 10
    readonly property real tileDiscOnAccentOpacity: 0.14
    readonly property real tileStateOnAccentOpacity: 0.72

    readonly property int settingsColumns: 4
    readonly property int settingsTileHeight: 64
    readonly property int settingsTileRows: 2
    readonly property int tileIconDisc: 34
    readonly property int sliderHeight: 32
    readonly property int sliderGap: 8
    readonly property int sliderCount: 3
    readonly property int sliderIconZone: 32
    readonly property int sliderValueZone: 44
    readonly property int sliderValueFontSize: fontSizeDetail
    // Movement below this is a click, not a drag.
    readonly property int sliderDragThreshold: 4
    // One arrow key press or one wheel notch.
    readonly property int sliderStep: 5
    // The hit area reaches this far into the gap above and below, so the
    // chevron zone of a capsule is a 40 x 40 touch target.
    readonly property int sliderHitExtension: 4
    readonly property int notificationHeaderGap: 10
    readonly property int notificationHeaderHeight: 28
    readonly property int notificationRowHeight: 62
    readonly property int notificationRowGap: 6
    readonly property int notificationRowRadius: 14
    readonly property int notificationListMaxHeight: listMaxHeight
    // A list row expanded in place: the body in at most four lines, the image
    // right of the text, the action pills and the reply field under it.
    readonly property int notificationRowPadding: 8
    // The app badge left of the text, the dismiss button at the right end.
    readonly property int notificationBadge: 26
    readonly property int notificationBadgeRadius: 8
    readonly property int notificationBadgeInset: 10
    readonly property int notificationTextGap: 10
    readonly property int notificationColumnGap: 6
    readonly property int notificationDismissSize: 22
    readonly property int notificationAppLineHeight: 14
    readonly property int notificationSummaryLineHeight: 17
    readonly property int notificationBodyFontSize: fontSizeDetail
    readonly property int notificationBodyLineHeight: 15
    readonly property int notificationBodyMaxLines: 4
    readonly property int notificationImageMaxSize: 64
    readonly property int notificationReplyWidth: 72
    // Notification peek: the stack replaces the right island at the Player's
    // width, never closer to the centre island than the clearance (it truncates
    // instead), and grows down one bare row at a time, newest on top.
    readonly property bool notificationPeek: true
    readonly property int notificationPeekWidth: 360
    readonly property int notificationPeekCentreClearance: 8
    readonly property int notificationPeekPaddingHorizontal: 10
    readonly property int notificationPeekPaddingVertical: 8
    readonly property int notificationPeekMaxRows: 3
    readonly property int notificationPeekRowHeight: 48
    // The hairline is centred in the gap and never drawn under the last row.
    readonly property int notificationPeekRowGap: 12
    readonly property real notificationPeekHairlineOpacity: 0.12
    readonly property int notificationPeekDisc: 26
    readonly property int notificationPeekTextGap: 10
    readonly property int notificationPeekSummaryLineHeight: 16
    readonly property int notificationPeekBodyLineHeight: 14
    readonly property int notificationPeekLineGap: 1
    // Kept free right of the text for the dismiss glyph, which sits this far
    // from the row's top and right edges in a larger hit area.
    readonly property int notificationPeekDismissReserve: 28
    readonly property int notificationPeekDismissInset: 8
    readonly property int notificationPeekDismissHit: 24
    // A row with actions grows on hover rest or long press; the text actions
    // rise this far from under the body, the rest are in the list.
    readonly property int notificationPeekRowOpenHeight: 80
    readonly property int notificationPeekActions: 3
    readonly property int notificationPeekActionHeight: 32
    readonly property int notificationPeekActionGap: 24
    readonly property int notificationPeekActionFontSize: fontSizeDetail
    readonly property int notificationPeekActionRise: 10
    // Rows that broke out of the stack, under the island and right-aligned
    // with it; past the maximum a "+N" blob on the far left.
    readonly property int notificationBlobSize: 30
    readonly property int notificationBlobGap: 8
    readonly property int notificationBlobMax: 6
    readonly property int notificationBlobCountWeight: Font.DemiBold
    // Action pills in the Settings list.
    readonly property int notificationActionHeight: pillHeight
    readonly property int notificationActionFontSize: fontSizeSmall
    readonly property int notificationActionPadding: pillPadding
    readonly property int notificationActionGap: 4
    readonly property int notificationActionMaxWidth: 140
    // The Wi-Fi and Bluetooth tiles: a chevron zone on the right opens their panel.
    readonly property int tileChevronZone: 40
    readonly property real tileChevronHairlineOpacity: 0.15
    readonly property int settingsGridHeight: settingsTileRows * settingsTileHeight + (settingsTileRows - 1) * tileGap
    readonly property int settingsSlidersHeight: sliderCount * sliderHeight + (sliderCount - 1) * sliderGap

    // Home: a narrow and a wide column; row heights are fixed so the panel has one height.
    readonly property int homeTimeColumnWidth: 150
    readonly property int homeTilePadding: 12
    readonly property int homeSectionGap: 10
    readonly property int homeTimeFontSize: fontSizeDisplay
    readonly property int homeLargeFontSize: fontSizeLarge
    readonly property int homeDetailFontSize: fontSizeDetail
    readonly property int segmentedHeight: 28
    readonly property int segmentedInset: 3
    // A segment's label keeps this far from the segment's ends.
    readonly property int segmentedLabelInset: 4
    readonly property int weatherNowHeight: 40
    readonly property int weatherNowIconSize: 28
    readonly property int weatherTabsWidth: 150
    readonly property int weatherCardCount: 5
    readonly property int weatherCardWidth: 64
    readonly property int weatherCardHeight: 72
    readonly property int weatherCardRadius: 12
    // Label, icon and temperatures of a card; high and low.
    readonly property int weatherCardGap: 4
    readonly property int weatherTemperatureGap: 3
    readonly property int meterWidth: 6
    readonly property int meterGap: 6
    // The temperature bar runs from empty at 30 °C to full at 95 °C.
    readonly property int tempScaleMin: 30
    readonly property int tempScaleMax: 95
    readonly property int powerHeadHeight: 28
    readonly property int powerIconSize: 20
    readonly property int chargeCapsuleHeight: 20
    readonly property int powerStatsHeight: 34
    readonly property int homeTopRowHeight: 2 * homeTilePadding + weatherNowHeight + 2 * homeSectionGap + segmentedHeight + weatherCardHeight
    readonly property int homeBottomRowHeight: 2 * homeTilePadding + powerHeadHeight + 3 * homeSectionGap + chargeCapsuleHeight + powerStatsHeight + segmentedHeight
    // Home's bottom row of icon-only tiles, one per panel, for touch.
    readonly property int homeActionHeight: 40
    readonly property int homeHeight: 2 * panelPadding + homeTopRowHeight + tileGap + homeBottomRowHeight + tileGap + homeActionHeight

    // Wi-Fi and Bluetooth: a control row over a list of rows that expand in place.
    readonly property int controlRowHeight: 32
    readonly property int controlButtonSize: 32
    readonly property int switchWidth: 36
    readonly property int switchHeight: 20
    readonly property int switchKnob: 14
    readonly property int switchHitExtension: 6
    readonly property int controlLabelGap: 12
    readonly property int listRowHeight: 44
    readonly property int listRowGap: 4
    readonly property int listRowRadius: 12
    readonly property int listRowPadding: 12
    // An expanded row adds a line of controls; an error adds a line of text.
    readonly property int listRowExpansion: 42
    readonly property int listRowErrorHeight: 16
    // The expansion and the error line sit this much higher than their slots.
    readonly property int listRowExpansionLift: 2
    readonly property int listRowErrorLift: 4
    readonly property int listRowButtonWidth: 88
    // While the panel is open; Bluetooth discovery stops after this at the latest.
    readonly property int bluetoothDiscoveryTime: 30000

    // Sound: Output, Input and Apps sections of list rows in one scrolling area.
    readonly property int sectionHeaderHeight: 24
    readonly property int sectionGap: 8
    readonly property int soundListMaxHeight: 360
    // The live level bar under the default input's name.
    readonly property int levelBarHeight: 3
    readonly property int levelBarGap: 4
    // An app row's compact capsule: mute icon zone, value zone.
    readonly property int appSliderWidth: 176
    readonly property int appSliderHeight: 24
    readonly property int appSliderIconZone: 26
    readonly property int appSliderValueZone: 40
    readonly property int appIconSize: 20

    // Display: capsules and segmented rows; the schedule line under the night capsule.
    readonly property int scheduleLineHeight: 20
    readonly property int displayLabelWidth: 132
    readonly property int colorDotSize: 10

    // Updates: count line, fragile rows, a scrolling list and three buttons.
    readonly property int updatesHeadHeight: 20
    readonly property int updatesHeadInset: 4
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
    // Bloom opacity: 0.15 to 0.5 with the low band while playing.
    readonly property real bloomQuiet: 0.15
    readonly property real bloomLoud: 0.5
    // Paused or stopped: a 6 px core inside a 1 px ring that breathes between
    // these diameters and opacities.
    readonly property int orbRestingSize: 6
    readonly property int orbRingWidth: 1
    readonly property int orbRingDiameter: 12
    readonly property int orbRingBreathDiameter: 14
    readonly property real orbRingMin: 0.2
    readonly property real orbRingMax: 0.8
    readonly property int orbHitPadding: orbBloom
    // The prototype's 280 px bar, padding included: orb, gap, text, three controls.
    readonly property int musicBarWidth: 280
    // The music bar opens by itself for a moment when the playing track changes.
    readonly property bool nowPlayingPeek: true
    readonly property real musicBarRimWidth: 2.5
    // A rim light follows the audio level from rest to full: brighter and more opaque.
    readonly property real rimBrightnessRest: 0.85
    readonly property real rimBrightnessGain: 0.5
    readonly property real rimOpacityRest: 0.6
    readonly property real rimOpacityGain: 0.4
    // How far the bar rim's lighter and warmer stops are pushed toward white.
    readonly property real musicBarRimLift: 0.25
    // The bar rim's outer glow: 2 px rings this far outside the edge, at this alpha.
    readonly property var musicBarGlowRings: [[2, 0.3], [4, 0.16], [6, 0.06]]
    readonly property int musicBarGlowRingWidth: 2
    // The Player's quiet rim, without glow.
    readonly property real playerRimWidth: 1.5
    readonly property int musicBarPaddingRight: 6
    readonly property int musicControlSize: 22
    readonly property int musicTitleFontSize: fontSizeDetail
    readonly property int musicArtistGap: 6
    // Space after the run before the marquee turns back.
    readonly property int marqueeTail: 12
    readonly property int marqueeFade: 10

    // Player: cover beside the text, a thin seekable track, controls, outputs.
    readonly property int playerCoverSize: 88
    readonly property int playerCoverRadius: 14
    readonly property int playerCoverGap: 14
    // Hover over the cover: a dimming surface and an "open" glyph.
    readonly property real playerCoverOverlayOpacity: 0.45
    readonly property int playerCoverIconSize: 24
    // The note drawn while the cover loads or is missing.
    readonly property int playerCoverPlaceholderSize: 32
    readonly property int playerTitleFontSize: fontSizeTitle
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
    readonly property int outputChipHeight: pillHeight
    readonly property int outputChipGap: 6
    readonly property int outputChipPadding: 10
    readonly property int outputChipMaxWidth: 150
    // Seconds per arrow key on the progress track.
    readonly property int playerSeekStep: 5

    // Privacy dots right of the centre island, mirroring the orb. Fixed colours,
    // not the wallpaper palette: they must read the same on every scheme.
    readonly property int privacyDotSize: 6
    readonly property int privacyDotGap: 4
    readonly property int privacyDotOffset: 6
    readonly property color privacyMicColor: "#FF9F0A"
    readonly property color privacyCameraColor: "#30D158"
    readonly property color privacyShareColor: "#0A84FF"
    // While the bar is hidden the dots sit in a mini island at the screen centre.
    readonly property int privacyPillHeight: 16
    readonly property int privacyPillPadding: 6

    // Top-edge wave: a band of light along the top of every screen while music plays.
    readonly property bool topWaveEnabled: true
    readonly property int waveHeight: 48
    readonly property int waveAmplitude: 20
    readonly property real wavePeakOpacity: 0.5
    // The wave canvas paints at this fraction of its size and is scaled up.
    readonly property real waveResolution: 0.5
    // The filled band above the curve starts this far above the screen edge.
    readonly property int waveTopOverdraw: 8
    // Width and alpha of the layered strokes, widest first; they stand in for a blur.
    // Together they reach about 0.95 alpha on the curve, so the top row shows
    // close to the full peak opacity.
    readonly property var waveStrokes: [[58, 0.2], [41, 0.32], [29, 0.5], [24, 0.8]]

    // Power: one row of square buttons, the panel's padding all round.
    readonly property int powerPanelPadding: 10
    readonly property int powerButtonIconSize: 22
    readonly property int powerButtonLabelGap: 7
    // A pressed button gives a little under the pointer.
    readonly property real pressedScale: 0.97
    readonly property int powerPanelHeight: powerButtonSize + 2 * powerPanelPadding

    // Theme and Wallpaper: a strip of cards that scrolls sideways.
    readonly property int carouselGap: 8
    readonly property int carouselPadding: 3
    readonly property int themeModeWidth: 264
    readonly property int themeModeFontSize: fontSizeDetail
    readonly property int schemeCardWidth: 148
    // Only the visible cards and a few on either side exist.
    readonly property int carouselCacheBuffer: 2 * schemeCardWidth
    readonly property int schemeCardPadding: 12
    readonly property int schemeCardRadius: 14
    readonly property int schemeDotSize: 16
    readonly property int schemeDotGap: 4
    readonly property int schemeDotsGap: 9
    readonly property int schemeLabelHeight: 14
    readonly property int schemeCardHeight: schemeCardPadding + schemeDotSize + schemeDotsGap + schemeLabelHeight + 10
    // Light and Dark: the bar calls DMS this long after the click, once the
    // control has slid and the bar has recoloured, then asks Niri for a screen
    // transition whose delay covers DMS's render and its templates (about
    // 0.8 s from the call; measure with scripts/theme-switch-timings.sh).
    readonly property bool themeCrossfade: true
    readonly property int themeCrossfadeLead: 300
    readonly property int themeCrossfadeDelay: 1400
    // How long the blank toast that makes DMS paint stays up; the colour
    // scheme is written after it, once DMS's own write has landed.
    readonly property int themeNudgeDuration: 400
    // Static disabled look of the Theme panel while DMS works.
    readonly property real busyOpacity: 0.5
    readonly property int themePanelHeight: 2 * panelPadding + segmentedHeight + tileGap + 2 * carouselPadding + schemeCardHeight
    readonly property int thumbWidth: 120
    readonly property int thumbHeight: 68
    readonly property int thumbRadius: 10
    readonly property int thumbLabelGap: 7
    readonly property int thumbLabelHeight: 14
    // Room for the selection ring outside the thumbnail.
    readonly property int thumbRing: 4
    // The ring's outer edge from the picture; its stroke leaves a gap inside.
    readonly property int thumbRingOffset: 4
    readonly property int thumbMarker: 8
    readonly property int wallpaperPanelHeight: 2 * panelPadding + 2 * thumbRing + thumbHeight + thumbLabelGap + thumbLabelHeight
    // One wheel notch moves the strip this far.
    readonly property int carouselWheelStep: 120

    // OSD: icon, a thin fill track and the value, in the collapsed island's height.
    readonly property int osdWidth: 200
    readonly property int osdPadding: 12
    readonly property int osdGap: 10
    readonly property int osdTrackHeight: 4
    readonly property int osdValueWidth: 34

    // The hide toggle slides the islands this far up, until their bottom edge is
    // hideClearance above the screen.
    readonly property int hideClearance: 15
    readonly property int hideDistance: islandTop + islandHeight + hideClearance

    Component.onCompleted: {
        if (!iconFontAvailable)
            console.warn("Theme: font \"" + iconFontFamily + "\" not found; icons are drawn as placeholders. Install ttf-material-symbols-variable.");
    }
}
