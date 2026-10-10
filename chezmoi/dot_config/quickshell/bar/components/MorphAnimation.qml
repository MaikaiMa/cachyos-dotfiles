import QtQuick
import ".."

// Growing and morphing use the spring-like curve, shrinking the standard one.
// A change with a Motion token of its own (a workspace slide, a tray fan)
// overrides the duration or the curve; -1 and [] keep grow and shrink.
NumberAnimation {
    property bool shrinking: false
    property int durationOverride: -1
    property var curveOverride: []

    duration: durationOverride >= 0 ? durationOverride : shrinking ? Motion.shrinkDuration : Motion.growDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: curveOverride.length > 0 ? curveOverride : shrinking ? Motion.shrinkCurve : Motion.growCurve
}
