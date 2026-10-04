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
    readonly property int workspaceSlideDuration: reduceMotion ? 0 : 200
    readonly property int indicatorDuration: reduceMotion ? 0 : 180
    readonly property int trayDuration: reduceMotion ? 0 : 200
    readonly property int osdInDuration: reduceMotion ? 0 : 160
    readonly property int osdOutDuration: reduceMotion ? 0 : 240
    readonly property int musicContentDelay: reduceMotion ? 0 : 120
    readonly property int waveInDuration: reduceMotion ? 0 : 600
    readonly property int waveOutDuration: reduceMotion ? 0 : 2000

    // Easing.BezierSpline wants the end point (1, 1) after the CSS control points.
    readonly property var growCurve: growEasing.concat([1, 1])
    readonly property var shrinkCurve: shrinkEasing.concat([1, 1])

    // Interaction timing, not animation: reduce motion leaves it alone.
    readonly property int hoverRestDelay: 250
}
