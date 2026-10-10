pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.components

// Weather icon | clock | battery icon, in Detail a label under each, and the
// Detail hover. Everything is placed from the centre line with fixed sizes:
// nothing lays out again while the island animates, and the clock stays put.
// The owner makes it as wide as the island, at its left edge.
Appear {
    id: pill

    required property string screenName
    property bool detail: false
    // The island's own animation: 0 collapsed, 1 in Detail.
    property real blend: 0
    // The island's x in its parent, fractional while it animates.
    property real originX: 0
    // The pointer rests on the owner's hit area over the pill and Detail.
    property bool hovered: false

    // Collapsed: icon | clock | icon at the icon size. Even widths keep the
    // island symmetric around the whole-pixel clock.
    readonly property int clockWidth: 2 * Math.ceil(clockItem.implicitWidth / 2)
    readonly property int pillWidth: columnsWidth(Theme.iconSize, clockWidth)
    // Detail: measured from the label text once on entering, not from live layout,
    // so the target does not hop while a font loads. See measureDetail().
    property int detailSideWidth: Theme.iconSize
    property int detailClockWidth: clockWidth
    readonly property int detailWidth: columnsWidth(detailSideWidth, detailClockWidth)
    // The owner's hover hit area: the collapsed pill and Detail, at a fixed size.
    readonly property int hoverWidth: Math.max(pillWidth, detailWidth)
    readonly property alias clock: clockItem

    // Distance from the centre line to the centre of a side column.
    readonly property real collapsedIconOffset: clockWidth / 2 + 2 * Theme.gap + Theme.hairlineWidth + Theme.iconSize / 2
    readonly property real detailIconOffset: detailClockWidth / 2 + 2 * Theme.gap + Theme.hairlineWidth + detailSideWidth / 2
    readonly property real iconOffset: collapsedIconOffset + (detailIconOffset - collapsedIconOffset) * blend
    readonly property real localCentreX: width / 2

    // Opacity only. Labels fade in once the island is under way and are done
    // before it settles, and fade out at once; hairlines do the reverse.
    property real labelOpacity: 0
    property real hairlineOpacity: 1

    // Whole screen pixels for the text on the centre line.
    function onPixel(localX: real): real {
        return Math.round(originX + localX) - originX;
    }

    function columnsWidth(side: real, middle: real): int {
        return 2 * side + middle + 4 * Theme.gap + 2 * Theme.hairlineWidth + 2 * Theme.paddingHorizontal;
    }

    function measureDetail() {
        detailSideWidth = Math.max(Theme.iconSize, Math.ceil(weatherMetrics.advanceWidth), Math.ceil(batteryMetrics.advanceWidth));
        detailClockWidth = 2 * Math.ceil(Math.max(clockItem.implicitWidth, dateMetrics.advanceWidth) / 2);
    }

    // "Zo 04-10": Dutch short weekday with a capital, then day and month.
    function shortDate(date: date): string {
        return Time.shortDay(date, true) + " " + Qt.formatDate(date, "dd-MM");
    }

    height: Theme.islandDetailHeight

    Component.onCompleted: measureDetail()

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

    // A short grace absorbs a leave and re-enter on the way.
    onHoveredChanged: {
        if (hovered) {
            leaveTimer.stop();
            restTimer.restart();
        } else {
            restTimer.stop();
            if (detail)
                leaveTimer.restart();
        }
    }

    // A hover rest opens Detail only from this screen's pill, judged per
    // screen: a pointer resting here takes the centre over from a panel on
    // another screen, as a click here would.
    Timer {
        id: restTimer

        interval: Motion.hoverRestDelay
        onTriggered: {
            if (pill.shown && !pill.detail)
                Shell.open("detail", pill.screenName);
        }
    }

    Timer {
        id: leaveTimer

        interval: Motion.hoverLeaveGrace
        onTriggered: {
            if (!pill.hovered && pill.detail)
                Shell.close();
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

    WeatherIcon {
        x: pill.localCentreX - pill.iconOffset - width / 2
        y: (Theme.islandHeight - height) / 2
        condition: Weather.ready && !Weather.stale ? Weather.iconName : ""
    }

    PillHairline {
        x: pill.onPixel(pill.localCentreX - pill.clockWidth / 2 - Theme.gap - width)
    }

    Clock {
        id: clockItem

        x: pill.onPixel(pill.localCentreX - width / 2)
        y: (Theme.islandHeight - height) / 2
    }

    PillHairline {
        x: pill.onPixel(pill.localCentreX + pill.clockWidth / 2 + Theme.gap)
    }

    BatteryIcon {
        x: pill.localCentreX + pill.iconOffset - width / 2
        y: (Theme.islandHeight - height) / 2
    }

    // The label row is always there with its full height; only its opacity
    // changes, so showing the labels never moves anything.
    Item {
        y: Theme.islandHeight - Theme.paddingVertical / 2
        width: parent.width
        height: Theme.islandDetailHeight - y
        opacity: pill.labelOpacity

        Label {
            id: weatherLabel

            x: pill.localCentreX - pill.iconOffset - width / 2
            text: Weather.ready && !Weather.stale ? Math.round(Weather.temperature) + "°" : "–"
            secondary: true
            numeric: true
        }

        Clock {
            id: dateLabel

            x: pill.onPixel(pill.localCentreX - width / 2)
            formatter: date => pill.shortDate(date)
            secondary: true
        }

        Label {
            id: batteryLabel

            x: pill.localCentreX + pill.iconOffset - width / 2
            text: Battery.available ? Math.round(Battery.percentage) + "%" : "–"
            secondary: true
            numeric: true
        }
    }

    // Only the pill toggles Home; the handler lives on it, not on the island,
    // so no click inside an open panel can reach it. A long press opens Power
    // instead: TapHandler emits tapped only for a release before the threshold.
    TapHandler {
        enabled: pill.shown
        longPressThreshold: Motion.longPressInterval / 1000
        onTapped: Shell.toggle("home", pill.screenName)
        onLongPressed: Shell.open("power", pill.screenName)
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

    component FadeAnimation: Crossfade {
        target: pill
    }

    component PillHairline: Hairline {
        y: (Theme.islandHeight - height) / 2
        opacity: pill.hairlineOpacity
    }
}
