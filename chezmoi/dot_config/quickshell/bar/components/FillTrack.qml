import QtQuick
import qs

// A rounded track filled to value (0..1) from the left, or from the bottom
// when vertical. capsuleClip clips a whole capsule instead of shortening it,
// so the start stays round and the moving edge is straight. The fill glides
// only while the track shows, unless glideWhileHidden: an animation in a
// hidden panel still makes the bar window present frames.
Item {
    id: track

    property real value: 0
    property bool vertical: false
    property bool capsuleClip: false
    property color trackColor: Colors.surfaceContainer
    property color fillColor: Colors.primary
    property real fillOpacity: 1
    property int duration: Motion.meterDuration
    property int easingType: Motion.crossfadeEasing
    property bool glideWhileHidden: false

    property real fraction: Math.max(0, Math.min(1, value))
    readonly property real radius: (vertical ? width : height) / 2

    Behavior on fraction {
        enabled: track.visible || track.glideWhileHidden

        NumberAnimation {
            duration: track.duration
            easing.type: track.easingType
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: track.radius
        color: track.trackColor
    }

    Rectangle {
        visible: !track.capsuleClip
        y: track.vertical ? track.height - height : 0
        width: track.vertical ? track.width : track.width * track.fraction
        height: track.vertical ? track.height * track.fraction : track.height
        radius: track.radius
        color: track.fillColor
        opacity: track.fillOpacity
    }

    Item {
        visible: track.capsuleClip
        width: track.width * track.fraction
        height: track.height
        clip: true

        Rectangle {
            width: track.width
            height: track.height
            radius: track.radius
            color: track.fillColor
            opacity: track.fillOpacity
        }
    }
}
