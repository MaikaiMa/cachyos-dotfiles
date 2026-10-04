import QtQuick
import ".."

// Growing and morphing use the spring-like curve, shrinking the standard one.
NumberAnimation {
    property bool shrinking: false

    duration: shrinking ? Motion.shrinkDuration : Motion.growDuration
    easing.type: Easing.BezierSpline
    easing.bezierCurve: shrinking ? Motion.shrinkCurve : Motion.growCurve
}
