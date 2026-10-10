pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import ".."
import "../components"
import "../panels"
import "../services"

// The dynamic island. The owner centres it horizontally on the screen and fixes
// its top, so it grows symmetrically sideways and downward and the clock stays put.
Island {
    id: island

    required property string screenName

    readonly property string centreState: Shell.stateOn(screenName)
    readonly property bool panelOpen: Shell.panelStates.includes(centreState)
    readonly property bool detail: centreState === "detail"
    readonly property bool osd: Shell.osdVisible && Shell.screenName === screenName
    readonly property bool showsPill: (centreState === "collapsed" || detail) && !osd
    readonly property bool musicBar: centreState === "musicbar"
    // A hover rest opens Detail or the music bar only from this screen's pill,
    // judged per screen: a pointer resting here takes the centre over from a
    // panel on another screen, as a click here would.
    readonly property bool hoverMayOpen: showsPill
    // The orb lives in a small surface of its own (orbParent), so its 30 Hz rim
    // does not make the bar window present frames. The owner places that surface
    // over orbTravelLeft..orbTravelRight from the island's centre line and gives
    // its left edge, in the island's parent's coordinates, as orbOrigin.
    readonly property alias orb: orbItem
    property Item orbParent: parent
    property real orbOrigin: 0
    readonly property real centreLine: x + width / 2
    // Where the orb's hit area can be, from the centre line: left of the pill,
    // Detail or the OSD, or 7 px inside the music bar.
    readonly property real orbOutside: Theme.orbGap + Theme.orbSize + Theme.orbHitPadding
    readonly property real orbInsideBar: -Theme.musicBarWidth / 2 + Theme.orbInset - Theme.orbHitPadding
    readonly property real orbTravelLeft: Math.floor(Math.min(-Math.max(pillWidth, detailWidth, Theme.osdWidth) / 2 - orbOutside, orbInsideBar))
    readonly property real orbTravelRight: Math.ceil(Math.max(-Math.min(pillWidth, detailWidth, Theme.osdWidth) / 2 - orbOutside, orbInsideBar) + orbItem.width)
    // In the bar window, mirroring the orb on the right; click-through, so not in the mask.
    readonly property alias privacyDots: privacyDotsItem
    // The mini island the dots sit in while the bar is hidden; blurred, not in the mask.
    readonly property alias privacyPill: privacyPillItem

    // Collapsed: icon | clock | icon at the icon size. Even widths keep the
    // island symmetric around the whole-pixel clock.
    readonly property int clockWidth: 2 * Math.ceil(clock.implicitWidth / 2)
    readonly property int pillWidth: columnsWidth(Theme.iconSize, clockWidth)
    // Detail: measured from the label text once on entering, not from live layout,
    // so the target does not hop while a font loads. See measureDetail().
    property int detailSideWidth: Theme.iconSize
    property int detailClockWidth: clockWidth
    readonly property int detailWidth: columnsWidth(detailSideWidth, detailClockWidth)

    // Distance from the centre line to the centre of a side column.
    readonly property real collapsedIconOffset: clockWidth / 2 + 2 * Theme.gap + Theme.hairlineWidth + Theme.iconSize / 2
    readonly property real detailIconOffset: detailClockWidth / 2 + 2 * Theme.gap + Theme.hairlineWidth + detailSideWidth / 2
    // Moves with the island's own animation: 0 collapsed, 1 in Detail.
    readonly property real iconOffset: collapsedIconOffset + (detailIconOffset - collapsedIconOffset) * blend
    readonly property real centreX: width / 2

    // Whole screen pixels for the text on the centre line; the island's own x is
    // fractional while it animates.
    function onPixel(localX: real): real {
        return Math.round(x + localX) - x;
    }

    function columnsWidth(side: real, middle: real): int {
        return 2 * side + middle + 4 * Theme.gap + 2 * Theme.hairlineWidth + 2 * Theme.paddingHorizontal;
    }

    function measureDetail() {
        detailSideWidth = Math.max(Theme.iconSize, Math.ceil(weatherMetrics.advanceWidth), Math.ceil(batteryMetrics.advanceWidth));
        detailClockWidth = 2 * Math.ceil(Math.max(clock.implicitWidth, dateMetrics.advanceWidth) / 2);
    }

    // Opacity only. Labels fade in once the island is under way and are done
    // before it settles, and fade out at once; hairlines do the reverse.
    property real labelOpacity: 0
    property real hairlineOpacity: 1

    onDetailChanged: {
        detailFades.stop();
        collapsedFades.stop();
        if (detail) {
            measureDetail();
            detailFades.start();
        } else {
            collapsedFades.start();
        }
    }

    ParallelAnimation {
        id: detailFades

        SequentialAnimation {
            PauseAnimation {
                duration: Motion.detailLabelDelay
            }
            FadeAnimation {
                property: "labelOpacity"
                to: 1
            }
        }
        FadeAnimation {
            property: "hairlineOpacity"
            to: 0
        }
    }

    ParallelAnimation {
        id: collapsedFades

        FadeAnimation {
            property: "labelOpacity"
            to: 0
        }
        SequentialAnimation {
            PauseAnimation {
                duration: Math.max(0, Motion.shrinkDuration - Motion.crossfadeDuration)
            }
            FadeAnimation {
                property: "hairlineOpacity"
                to: 1
            }
        }
    }

    component FadeAnimation: NumberAnimation {
        target: island
        duration: Motion.crossfadeDuration
        easing.type: Motion.crossfadeEasing
    }

    Component.onCompleted: measureDetail()

    // "Zo 04-10": Dutch short weekday with a capital, then day and month.
    function shortDate(date: date): string {
        const day = Qt.locale("nl_NL").dayName(date.getDay(), Locale.ShortFormat);
        return day.charAt(0).toUpperCase() + day.slice(1) + " " + Qt.formatDate(date, "dd-MM");
    }

    // From the island's left edge to the orb's hit area: left of the pill, or the
    // bar's first element. It moves with the island's own curve and duration.
    property real orbOffset: musicBar ? Theme.orbInset - Theme.orbHitPadding : -orbOutside

    Behavior on orbOffset {
        IslandAnimation {
            shrinking: !island.musicBar
        }
    }

    targetWidth: panelOpen ? Theme.panelWidths[centreState] : centreState === "musicbar" ? Theme.musicBarWidth : osd ? Theme.osdWidth : detail ? detailWidth : pillWidth
    readonly property var panelHeights: ({
            home: homePanel.implicitHeight,
            settings: settingsPanel.implicitHeight,
            updates: updatesPanel.implicitHeight,
            player: playerPanel.implicitHeight,
            power: powerPanel.implicitHeight,
            theme: themePanel.implicitHeight,
            wallpaper: wallpaperPanel.implicitHeight,
            wifi: wifiPanel.implicitHeight,
            bluetooth: bluetoothPanel.implicitHeight,
            sound: soundPanel.implicitHeight,
            display: displayPanel.implicitHeight
        })

    targetHeight: panelOpen ? panelHeights[centreState] : detail ? Theme.islandDetailHeight : Theme.islandHeight
    targetOpacity: panelOpen ? Theme.panelOpacity : Theme.islandOpacity
    targetBlend: detail ? 1 : 0
    expanded: panelOpen || detail

    // Weather icon | clock | battery icon, in Detail a label under each. Everything
    // is placed from the centre line with fixed sizes: nothing lays out again while
    // the island animates, and the clock stays put.
    Item {
        id: pill

        width: island.width
        height: Theme.islandDetailHeight
        opacity: island.showsPill ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        WeatherIcon {
            x: island.centreX - island.iconOffset - width / 2
            y: (Theme.islandHeight - height) / 2
            condition: Weather.ready && !Weather.stale ? Weather.iconName : ""
        }

        PillHairline {
            x: island.onPixel(island.centreX - island.clockWidth / 2 - Theme.gap - width)
        }

        Clock {
            id: clock

            x: island.onPixel(island.centreX - width / 2)
            y: (Theme.islandHeight - height) / 2
        }

        PillHairline {
            x: island.onPixel(island.centreX + island.clockWidth / 2 + Theme.gap)
        }

        BatteryIcon {
            x: island.centreX + island.iconOffset - width / 2
            y: (Theme.islandHeight - height) / 2
        }

        // The label row is always there with its full height; only its opacity
        // changes, so showing the labels never moves anything.
        Item {
            y: Theme.islandHeight - Theme.paddingVertical / 2
            width: parent.width
            height: Theme.islandDetailHeight - y
            opacity: island.labelOpacity

            DetailLabel {
                id: weatherLabel

                x: island.centreX - island.iconOffset - width / 2
                text: Weather.ready && !Weather.stale ? Math.round(Weather.temperature) + "°" : "–"
            }

            Clock {
                id: dateLabel

                x: island.onPixel(island.centreX - width / 2)
                formatter: date => island.shortDate(date)
                color: Colors.foregroundVariant
                font.pixelSize: Theme.secondaryFontSize
            }

            DetailLabel {
                id: batteryLabel

                x: island.centreX + island.iconOffset - width / 2
                text: Battery.available ? Math.round(Battery.percentage) + "%" : "–"
            }
        }

        // Only the pill toggles Home; the handler lives on it, not on the island,
        // so no click inside an open panel can reach it. A long press opens Power
        // instead: TapHandler emits tapped only for a release before the threshold.
        TapHandler {
            objectName: "pillTap"
            enabled: island.showsPill
            longPressThreshold: Motion.longPressInterval / 1000
            onTapped: Shell.toggle("home", island.screenName)
            onLongPressed: Shell.open("power", island.screenName)
        }

        TextMetrics {
            id: weatherMetrics

            font: weatherLabel.font
            text: weatherLabel.text
        }

        TextMetrics {
            id: dateMetrics

            font: dateLabel.font
            text: dateLabel.text
        }

        TextMetrics {
            id: batteryMetrics

            font: batteryLabel.font
            text: batteryLabel.text
        }
    }

    // Over the collapsed pill while a volume or brightness key was pressed.
    Osd {
        objectName: "osd"
        x: (island.width - width) / 2
        shown: island.osd
    }

    // The orb's travelling light runs around the bar's edge while it is open.
    // The rims read the audio clock only while they show: a hidden item that
    // changes still makes the window present a frame.
    Item {
        id: barRim

        anchors.fill: parent
        opacity: island.musicBar ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            MusicFade {}
        }

        RimLight {
            objectName: "musicBarRim"
            anchors.fill: parent
            radius: island.radius
            thickness: Theme.musicBarRimWidth
            angle: barRim.visible ? -Cava.barRimAngle : 0
            lift: Theme.musicBarRimLift
            brightness: 0.85 + 0.5 * island.barLevel
            opacity: 0.6 + 0.4 * island.barLevel
        }
    }

    readonly property real barLevel: barRim.visible ? Cava.level : 0

    // Title and artist as one run, then previous, play or pause, next. The orb
    // sits in the left padding. A click anywhere but a control opens the Player.
    Item {
        id: musicBarBody

        objectName: "musicBar"
        x: (island.width - width) / 2
        width: Theme.musicBarWidth
        height: Theme.islandHeight
        opacity: island.musicBar ? 1 : 0
        visible: opacity > 0
        enabled: island.musicBar

        Behavior on opacity {
            MusicFade {}
        }

        MouseArea {
            anchors.fill: parent
            onClicked: Shell.open("player", island.screenName)
        }

        Item {
            id: marqueeBox

            objectName: "marquee"
            readonly property real overflow: Math.max(0, run.width - width)
            readonly property bool scrolling: overflow > 0 && island.musicBar && !Motion.reduceMotion

            x: Theme.orbInset + Theme.orbSize + Theme.gap
            width: musicControls.x - Theme.gap - x
            height: parent.height
            clip: true

            // Soft edges while the run scrolls, as in the prototype.
            layer.enabled: scrolling
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: marqueeMask
                // A soft ramp over the mask's alpha; the default thresholds cut it hard.
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }

            Row {
                id: run

                objectName: "musicRun"
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.musicArtistGap

                Text {
                    id: musicTitle

                    text: Music.title
                    color: Colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.musicTitleFontSize
                    font.weight: Font.DemiBold
                }

                Text {
                    anchors.baseline: musicTitle.baseline
                    text: Music.artist
                    visible: text !== ""
                    color: Colors.foregroundVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.secondaryFontSize
                    font.weight: Theme.fontWeight
                }
            }

            // Holds at each end, glides across, and comes back.
            SequentialAnimation {
                id: marquee

                readonly property real shift: marqueeBox.overflow + Theme.marqueeTail
                readonly property int travel: Math.round((Motion.marqueeBase + marqueeBox.overflow * Motion.marqueePerPixel) * 0.7)
                readonly property int hold: Math.round((Motion.marqueeBase + marqueeBox.overflow * Motion.marqueePerPixel) * 0.15)

                running: marqueeBox.scrolling
                loops: Animation.Infinite
                onRunningChanged: {
                    if (!running)
                        run.x = 0;
                }

                PauseAnimation {
                    duration: marquee.hold
                }
                NumberAnimation {
                    target: run
                    property: "x"
                    from: 0
                    to: -marquee.shift
                    duration: marquee.travel
                }
                PauseAnimation {
                    duration: 2 * marquee.hold
                }
                NumberAnimation {
                    target: run
                    property: "x"
                    from: -marquee.shift
                    to: 0
                    duration: marquee.travel
                }
                PauseAnimation {
                    duration: marquee.hold
                }
            }
        }

        Rectangle {
            id: marqueeMask

            width: marqueeBox.width
            height: marqueeBox.height
            visible: false
            layer.enabled: true
            gradient: Gradient {
                orientation: Gradient.Horizontal

                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: Theme.marqueeFade / Math.max(1, marqueeMask.width)
                    color: "black"
                }
                GradientStop {
                    position: 1 - Theme.marqueeFade / Math.max(1, marqueeMask.width)
                    color: "black"
                }
                GradientStop {
                    position: 1
                    color: "transparent"
                }
            }
        }

        Row {
            id: musicControls

            x: parent.width - width - Theme.musicBarPaddingRight
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.gap

            MusicButton {
                objectName: "musicPrevious"
                iconName: "skip_previous"
                label: "Previous"
                onActivated: Music.previous()
            }

            MusicButton {
                objectName: "musicToggle"
                iconName: Music.playing ? "pause" : "play_arrow"
                label: Music.playing ? "Pause" : "Play"
                onActivated: Music.togglePlaying()
            }

            MusicButton {
                objectName: "musicNext"
                iconName: "skip_next"
                label: "Next"
                onActivated: Music.next()
            }
        }
    }

    // The Player carries the rim light as a quiet continuation: thinner, slower,
    // no glow, fading with the panel body.
    Item {
        id: playerRim

        anchors.fill: parent
        opacity: island.centreState === "player" ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        RimLight {
            objectName: "playerRim"
            anchors.fill: parent
            radius: island.radius
            thickness: Theme.playerRimWidth
            angle: playerRim.visible ? -Cava.playerRimAngle : 0
            lift: Theme.musicBarRimLift
            brightness: 0.85 + 0.5 * island.playerLevel
            opacity: 0.6 + 0.4 * island.playerLevel
        }
    }

    readonly property real playerLevel: playerRim.visible ? Cava.level : 0

    // Under the panel bodies: a click on empty panel space stops here and does nothing.
    MouseArea {
        objectName: "panelGuard"
        anchors.fill: parent
        enabled: island.panelOpen
        acceptedButtons: Qt.AllButtons
    }

    // Centred on the island at their own width; the island clips them while it grows.
    HomePanel {
        id: homePanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "home"
    }

    SettingsPanel {
        id: settingsPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "settings"
    }

    UpdatesPanel {
        id: updatesPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "updates"
    }

    PlayerPanel {
        id: playerPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "player"
    }

    PowerPanel {
        id: powerPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "power"
    }

    ThemePanel {
        id: themePanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "theme"
    }

    WallpaperPanel {
        id: wallpaperPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        screenName: island.screenName
        shown: island.centreState === "wallpaper"
    }

    WifiPanel {
        id: wifiPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "wifi"
    }

    BluetoothPanel {
        id: bluetoothPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "bluetooth"
    }

    SoundPanel {
        id: soundPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "sound"
    }

    DisplayPanel {
        id: displayPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "display"
    }

    component MusicFade: SequentialAnimation {
        PauseAnimation {
            duration: island.musicBar ? Motion.musicContentDelay : 0
        }
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    component MusicButton: Item {
        id: button

        property string iconName: ""
        property string label: ""

        signal activated

        width: Theme.musicControlSize
        height: Theme.musicControlSize

        Accessible.role: Accessible.Button
        Accessible.name: label
        Accessible.onPressAction: button.activated()

        Icon {
            anchors.centerIn: parent
            name: button.iconName
            fill: 1
            color: buttonPointer.containsMouse ? Colors.primary : Colors.foreground
        }

        MouseArea {
            id: buttonPointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: button.activated()
        }
    }

    component PillHairline: Hairline {
        y: (Theme.islandHeight - height) / 2
        opacity: island.hairlineOpacity
    }

    component DetailLabel: Text {
        color: Colors.foregroundVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.secondaryFontSize
        font.weight: Theme.fontWeight
        font.features: ({
                tnum: 1
            })
    }

    // Hover lives on a hit area that covers the collapsed pill and the Detail
    // island and does not resize while the island animates, so the growing edge
    // never toggles it. A short grace absorbs a leave and re-enter on the way.
    Item {
        width: Math.max(island.pillWidth, island.detailWidth)
        height: Theme.islandDetailHeight
        x: island.centreX - width / 2

        HoverHandler {
            id: hover

            onHoveredChanged: {
                if (hovered) {
                    leaveTimer.stop();
                    restTimer.restart();
                } else {
                    restTimer.stop();
                    if (island.detail)
                        leaveTimer.restart();
                }
            }
        }
    }

    Timer {
        id: restTimer

        interval: Motion.hoverRestDelay
        onTriggered: {
            if (island.hoverMayOpen && !island.detail)
                Shell.open("detail", island.screenName);
        }
    }

    Timer {
        id: leaveTimer

        interval: Motion.hoverLeaveGrace
        onTriggered: {
            if (!hover.hovered && island.detail)
                Shell.close();
        }
    }

    // The bar rim's soft outer glow: rings outside the island's edge, so they
    // live in the window under the island, fainter the farther out.
    Item {
        parent: island.parent
        x: island.x
        y: island.y
        z: island.z - 0.5
        width: island.width
        height: island.height
        opacity: island.musicBar ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            MusicFade {}
        }

        Repeater {
            model: Theme.musicBarGlowRings

            RimLight {
                required property var modelData

                objectName: "musicBarGlow"
                x: -modelData[0]
                y: -modelData[0]
                width: island.width + 2 * modelData[0]
                height: island.height + 2 * modelData[0]
                radius: island.radius + modelData[0]
                thickness: Theme.musicBarGlowRingWidth
                angle: barRim.visible ? -Cava.barRimAngle : 0
                lift: Theme.musicBarRimLift
                brightness: 0.85 + 0.5 * island.barLevel
                opacity: modelData[1] * (0.6 + 0.4 * island.barLevel)
            }
        }
    }

    // Not in the island: the island clips its children. Held inside its surface
    // while a panel's island carries it farther out and it fades.
    Orb {
        id: orbItem

        objectName: "orb"
        parent: island.orbParent
        x: Math.max(island.centreLine + island.orbTravelLeft, Math.min(island.centreLine + island.orbTravelRight - width, island.x + island.orbOffset)) - island.orbOrigin
        y: island.y + (Theme.islandHeight - height) / 2
        z: island.z + 1
        opacity: Music.hasPlayer && !island.panelOpen ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: Motion.crossfadeDuration
                easing.type: Motion.crossfadeEasing
            }
        }

        HoverHandler {
            id: orbHover

            onHoveredChanged: island.musicHoverChanged()
        }

        TapHandler {
            onTapped: {
                orbRestTimer.stop();
                Shell.open("player", island.screenName);
            }
        }
    }

    // Hidden with something recording (and no OSD bringing the island back), the
    // dots glide to the screen centre into a mini island of their own.
    readonly property bool privacyDocked: Shell.hidden && !osd && Privacy.anyActive
    // 0 at the island's right edge, 1 centred on the clock; the grow curve both ways.
    property real privacyGlide: privacyDocked ? 1 : 0
    property real privacyPillOpacity: privacyDocked ? 1 : 0
    // The pill keeps its last width while it fades out with no dot left.
    property real privacyPillWidth: Theme.privacyDotSize + 2 * Theme.privacyPillPadding

    Behavior on privacyGlide {
        IslandAnimation {}
    }

    Behavior on privacyPillOpacity {
        id: privacyPillFade

        IslandAnimation {
            shrinking: privacyPillFade.targetValue < 1
        }
    }

    // A dot coming or going while docked resizes the pill around the clock's x.
    Behavior on privacyPillWidth {
        id: privacyPillResize

        enabled: island.privacyPillOpacity > 0

        IslandAnimation {
            shrinking: privacyPillResize.targetValue < island.privacyPillWidth
        }
    }

    Binding on privacyPillWidth {
        when: privacyDotsItem.implicitWidth > 0
        value: privacyDotsItem.implicitWidth + 2 * Theme.privacyPillPadding
        restoreMode: Binding.RestoreNone
    }

    Rectangle {
        id: privacyPillItem

        objectName: "privacyPill"
        parent: island.parent
        x: Math.round(island.x + island.width / 2 - width / 2)
        y: Theme.islandTop + (Theme.islandHeight - height) / 2
        z: island.z + 0.5
        width: island.privacyPillWidth
        height: Theme.privacyPillHeight
        radius: height / 2
        color: Qt.alpha(Colors.surfaceContainer, Theme.islandOpacity)
        opacity: island.privacyPillOpacity
        visible: opacity > 0
    }

    // Through Detail, the music bar and every panel: never hidden while something
    // records. While the bar is hidden they stay at the islands' top row.
    PrivacyDots {
        id: privacyDotsItem

        readonly property real edgeX: Math.round(island.x + island.width) + Theme.privacyDotOffset
        readonly property real centredX: privacyPillItem.x + Theme.privacyPillPadding

        objectName: "privacyDots"
        parent: island.parent
        x: edgeX + (centredX - edgeX) * island.privacyGlide
        y: Math.round((Shell.hidden ? Theme.islandTop : island.y) + (Theme.islandHeight - height) / 2)
        z: island.z + 1
    }

    // The music bar stays open while the pointer is on the orb or the island.
    HoverHandler {
        id: islandHover

        onHoveredChanged: island.musicHoverChanged()
    }

    function musicHoverChanged() {
        if (orbHover.hovered || islandHover.hovered) {
            musicLeaveTimer.stop();
            if (musicBar && Shell.peeking)
                Shell.endPeek();
            if (orbHover.hovered && !musicBar)
                orbRestTimer.restart();
        } else {
            orbRestTimer.stop();
            if (musicBar)
                musicLeaveTimer.restart();
        }
    }

    // A peek that opens under a resting pointer is a hover from the start.
    Connections {
        target: Shell

        function onPeekingChanged() {
            if (Shell.peeking && island.musicBar && (orbHover.hovered || islandHover.hovered))
                Shell.endPeek();
        }
    }

    Timer {
        id: orbRestTimer

        interval: Motion.orbHoverDelay
        onTriggered: {
            if (island.hoverMayOpen && orbHover.hovered)
                Shell.open("musicbar", island.screenName);
        }
    }

    Timer {
        id: musicLeaveTimer

        interval: Motion.hoverLeaveGrace
        onTriggered: {
            if (island.musicBar && !orbHover.hovered && !islandHover.hovered)
                Shell.close();
        }
    }
}
