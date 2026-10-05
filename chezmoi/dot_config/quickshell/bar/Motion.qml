pragma Singleton

import QtQuick
import Quickshell

// Durations and curves from the Motion table in docs/shell-design.md.
Singleton {
    property bool reduceMotion: false

    readonly property int growDuration: reduceMotion ? 0 : 280
    readonly property var growEasing: [0.2, 0.8, 0.2, 1]
    readonly property int shrinkDuration: reduceMotion ? 0 : 220
    readonly property var shrinkEasing: [0.4, 0, 0.2, 1]
    readonly property int crossfadeDuration: reduceMotion ? 0 : 140
    readonly property int crossfadeEasing: Easing.OutCubic
    // Detail labels start fading in this long after the island starts growing.
    readonly property int detailLabelDelay: reduceMotion ? 0 : 60
    readonly property int workspaceSlideDuration: reduceMotion ? 0 : 200
    readonly property int indicatorDuration: reduceMotion ? 0 : 180
    // CSS ease-out.
    readonly property var indicatorEasing: [0, 0, 0.58, 1]
    readonly property int trayDuration: reduceMotion ? 0 : 200
    readonly property int refreshSpinDuration: reduceMotion ? 0 : 600
    readonly property int osdInDuration: reduceMotion ? 0 : 160
    readonly property int osdOutDuration: reduceMotion ? 0 : 240
    // The bar's colours glide to a new palette (theme, scheme or wallpaper change).
    readonly property int paletteDuration: reduceMotion ? 0 : 300
    readonly property int musicContentDelay: reduceMotion ? 0 : 120
    readonly property int waveInDuration: reduceMotion ? 0 : 600
    readonly property int waveOutDuration: reduceMotion ? 0 : 2000
    // Audio-driven values: attack when rising, release when falling (time constants).
    readonly property int audioAttack: 80
    readonly property int audioRelease: 250
    // The rim light's turn time follows the level; its rate settles in this time.
    // The music bar's rim turns faster than the orb's.
    readonly property int rimTurnRest: 6000
    readonly property int rimTurnFull: 1500
    readonly property int barRimTurnRest: 4000
    readonly property int barRimTurnFull: 1200
    readonly property int playerRimTurnRest: 8000
    readonly property int playerRimTurnFull: 3000
    readonly property int rimRateSettle: 400
    // On pause the rims ease to a stop and the bloom breathes; play eases them back.
    readonly property int rimEaseDuration: 600
    readonly property int bloomBreathPeriod: 4000
    // Audio animation ticks: 60 per second while playing, 10 while paused.
    readonly property int audioFrameInterval: 16
    readonly property int audioPausedInterval: 100
    // Marquee: a hold at each end and this much time per pixel of overflow.
    readonly property int marqueeBase: 2000
    readonly property int marqueePerPixel: 28

    // Easing.BezierSpline wants the end point (1, 1) after the CSS control points.
    readonly property var growCurve: growEasing.concat([1, 1])
    readonly property var shrinkCurve: shrinkEasing.concat([1, 1])
    readonly property var indicatorCurve: indicatorEasing.concat([1, 1])

    // Interaction timing, not animation: reduce motion leaves it alone.
    readonly property int hoverRestDelay: 250
    readonly property int hoverLeaveGrace: 120
    readonly property int orbHoverDelay: 80
    readonly property int nowPlayingPeekHold: 5000
    readonly property int longPressInterval: 500
}
