pragma ComponentBehavior: Bound

import QtQuick
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

    // Weather service icon names to Material Symbols ligatures.
    readonly property var weatherSymbols: ({
            "clear-day": "clear_day",
            "clear-night": "clear_night",
            "partly-cloudy-day": "partly_cloudy_day",
            "partly-cloudy-night": "partly_cloudy_night",
            "cloudy": "cloud",
            "fog": "foggy",
            "drizzle": "rainy",
            "rain": "rainy",
            "snow": "weather_snowy",
            "thunderstorm": "thunderstorm"
        })
    readonly property string weatherSymbol: Weather.ready ? weatherSymbols[Weather.iconName] ?? "" : ""
    readonly property string batterySymbol: {
        if (!Battery.available)
            return "";
        if (Battery.state === "charging")
            return "battery_charging_full";
        if (Battery.isLow && Battery.state === "discharging")
            return "battery_alert";
        if (Battery.percentage >= 95)
            return "battery_full";
        return "battery_" + Math.min(6, Math.max(1, Math.round(Battery.percentage / 100 * 6))) + "_bar";
    }

    // "Zo 04-10": Dutch short weekday with a capital, then day and month.
    function shortDate(date: date): string {
        const day = Qt.locale("nl_NL").dayName(date.getDay(), Locale.ShortFormat);
        return day.charAt(0).toUpperCase() + day.slice(1) + " " + Qt.formatDate(date, "dd-MM");
    }

    targetWidth: panelOpen ? Theme.panelWidths[centreState] : centreState === "musicbar" ? Theme.musicBarWidth : osd ? Theme.osdWidth : detail ? detailWidth : pillWidth
    targetHeight: centreState === "settings" ? settingsPanel.implicitHeight : panelOpen ? Theme.placeholderPanelHeight : detail ? Theme.islandDetailHeight : Theme.islandHeight
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

        Icon {
            x: island.centreX - island.iconOffset - width / 2
            y: (Theme.islandHeight - height) / 2
            name: island.weatherSymbol
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

        Icon {
            x: island.centreX + island.iconOffset - width / 2
            y: (Theme.islandHeight - height) / 2
            name: island.batterySymbol
            color: Battery.isLow ? Colors.error : Colors.foreground
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
                text: Weather.ready ? Math.round(Weather.temperature) + "°" : "–"
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

    // Stand-in for the OSD slider pill shown over the collapsed pill.
    Rectangle {
        anchors.centerIn: parent
        width: parent.width - 2 * Theme.paddingHorizontal
        height: Theme.paddingVertical
        radius: height / 2
        color: Colors.surfaceContainerHigh
        opacity: island.osd ? 1 : 0
        visible: opacity > 0

        Behavior on opacity {
            NumberAnimation {
                duration: island.osd ? Motion.osdInDuration : Motion.osdOutDuration
                easing.type: island.osd ? Easing.OutCubic : Easing.InCubic
            }
        }

        Rectangle {
            width: parent.width * 0.6
            height: parent.height
            radius: parent.radius
            color: Colors.primary
        }
    }

    // Centred on the island at its own width; the island clips it while it grows.
    SettingsPanel {
        id: settingsPanel

        x: (island.width - width) / 2
        width: implicitWidth
        height: implicitHeight
        shown: island.centreState === "settings"
    }

    Repeater {
        model: Shell.panelStates.filter(state => state !== "settings").concat(["musicbar"])

        PlaceholderPanel {
            required property string modelData

            anchors.fill: parent
            name: modelData
            shown: island.centreState === modelData
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
            if (Shell.centreState === "collapsed" && !island.osd)
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

    TapHandler {
        enabled: island.showsPill
        onTapped: Shell.toggle("home", island.screenName)
    }
}
