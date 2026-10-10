pragma Singleton

import QtQuick
import Quickshell
import "services"

// Durations and curves from the Motion table in docs/shell-design.md.
Singleton {
    // The `bar reduceMotion` IPC switch, kept in Settings.
    readonly property bool reduceMotion: Settings.reduceMotion

    readonly property int growDuration: reduceMotion ? 0 : 280
    readonly property int shrinkDuration: reduceMotion ? 0 : 220
    readonly property int crossfadeDuration: reduceMotion ? 0 : 140
    readonly property int crossfadeEasing: Easing.OutCubic
    // Level meters and the charge capsule glide to a new reading.
    readonly property int meterDuration: reduceMotion ? 0 : 560
    // Detail labels start fading in this long after the island starts growing.
    readonly property int detailLabelDelay: reduceMotion ? 0 : 60
    readonly property int workspaceSlideDuration: reduceMotion ? 0 : 200
    // The accent under a segmented control's current segment.
    readonly property int segmentSlideDuration: reduceMotion ? 0 : 200
    readonly property int indicatorDuration: reduceMotion ? 0 : 180
    readonly property int trayDuration: reduceMotion ? 0 : 200
    readonly property int refreshSpinDuration: reduceMotion ? 0 : 600
    readonly property int osdInDuration: reduceMotion ? 0 : 160
    readonly property int osdOutDuration: reduceMotion ? 0 : 240
    readonly property int osdInEasing: Easing.OutCubic
    readonly property int osdOutEasing: Easing.InCubic
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
    // On pause the rims ease to a stop; play eases them back.
    readonly property int rimEaseDuration: 600
    // The resting orb's ring breathes once in this time.
    readonly property int orbRingBreathPeriod: 5000
    // Audio animation ticks: 30 per second while playing, cava's own frame rate,
    // 15 on battery and 15 while paused. Every frame the bar presents costs Niri
    // a screen composite, so on battery the frame rate is the lever. Smoothing
    // and rotation step by elapsed time, so the rates and the attack and release
    // times do not depend on the tick.
    readonly property int audioFrameInterval: 33
    readonly property int audioFrameIntervalBattery: 66
    readonly property int audioPausedInterval: 66
    // Marquee: a hold at each end and this much time per pixel of overflow.
    readonly property int marqueeBase: 2000
    readonly property int marqueePerPixel: 28

    // The CSS cubic-bezier control points, then the end point (1, 1) that
    // Easing.BezierSpline wants; the indicator's is CSS ease-out.
    readonly property var growCurve: [0.2, 0.8, 0.2, 1, 1, 1]
    readonly property var shrinkCurve: [0.4, 0, 0.2, 1, 1, 1]
    readonly property var indicatorCurve: [0, 0, 0.58, 1, 1, 1]

    // Interaction timing, not animation: reduce motion leaves it alone.
    readonly property int hoverRestDelay: 250
    readonly property int hoverLeaveGrace: 120
    readonly property int orbHoverDelay: 80
    readonly property int nowPlayingPeekHold: 5000
    readonly property int longPressInterval: 500
    // A slider shows the value it asked for until the service reports it, at most this long.
    readonly property int sliderHoldFallback: 1000
    // A scroll of the user's has come to rest after this long without a wheel event.
    readonly property int scrollSettleDelay: 140
    // A timer that waits for an animation to end adds this, so the last frame has landed.
    readonly property int settleMargin: 20
    // A notification peek row holds by urgency, or for the sender's timeout clamped
    // to these bounds; a critical one holds until it is clicked or dismissed.
    readonly property int notificationHoldNormal: 5000
    readonly property int notificationHoldLow: 3000
    readonly property int notificationHoldMin: 2000
    readonly property int notificationHoldMax: 15000
}
