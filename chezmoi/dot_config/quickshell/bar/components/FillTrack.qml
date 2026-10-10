import QtQuick
import qs

// A rounded track filled to value (0..1) from the left, or from the bottom
// when vertical. capsuleClip clips a whole capsule instead of shortening it,
// so the start stays round and the moving edge is straight. The fill glides
// only while the track shows, unless glideWhileHidden: an animation in a
// hidden panel still makes the bar window present frames. A move shorter than
// glideThreshold pixels is set at once: each glide frame is a presented frame,
// and a meter that ticks every sample would otherwise keep the window busy.
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
    property real glideThreshold: 0

    readonly property real targetFraction: Math.max(0, Math.min(1, value))
    property real fraction
    readonly property real length: vertical ? height : width
    readonly property real radius: (vertical ? width : height) / 2

    Component.onCompleted: fraction = targetFraction

    onTargetFractionChanged: {
        glide.stop();
        const canGlide = track.visible || track.glideWhileHidden;
        const distance = Math.abs(track.targetFraction - track.fraction) * track.length;
        if (canGlide && distance >= track.glideThreshold) {
            glide.from = track.fraction;
            glide.to = track.targetFraction;
            glide.start();
        } else {
            track.fraction = track.targetFraction;
        }
    }

    NumberAnimation {
        id: glide

        target: track
        property: "fraction"
        duration: track.duration
        easing.type: track.easingType
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
