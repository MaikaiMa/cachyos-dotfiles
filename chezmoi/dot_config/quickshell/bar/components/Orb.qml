import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import ".."
import "../services"

// The music orb: a solid sphere in the album colour with a travelling rim light
// and a bloom that follows the low band. Paused or stopped, it rests: the core
// shrinks, rim and bloom fade out, and a thin ring around it breathes.
// The item is the hit area, orbHitPadding wider than the sphere on every side,
// the size of the bloom; it never changes.
Item {
    id: orb

    readonly property bool resting: Music.hasPlayer && !Music.playing
    // 1 playing, 0 resting; carries the core's size and the rim and bloom.
    property real liveness: resting ? 0 : 1

    implicitWidth: Theme.orbSize + 2 * Theme.orbHitPadding
    implicitHeight: implicitWidth

    Behavior on liveness {
        MorphAnimation {
            shrinking: orb.resting
        }
    }

    Rectangle {
        objectName: "orbRing"
        anchors.centerIn: parent
        width: Theme.orbRingDiameter
        height: Theme.orbRingDiameter
        radius: width / 2
        color: "transparent"
        border.width: Theme.orbRingWidth
        // A thin ring in a dark album colour vanishes on a light palette.
        border.color: Colors.dark ? Music.artColor : Colors.primary
        scale: 1 + (Theme.orbRingBreathDiameter / Theme.orbRingDiameter - 1) * Cava.ringSwell
        opacity: (1 - orb.liveness) * Cava.ringBreath
        visible: opacity > 0
    }

    // Core, rim and bloom scale together around the same centre.
    Item {
        objectName: "orbLive"
        anchors.centerIn: parent
        width: Theme.orbSize
        height: Theme.orbSize
        scale: (Theme.orbRestingSize + (Theme.orbSize - Theme.orbRestingSize) * orb.liveness) / Theme.orbSize

        // The bloom: a lit disc reaching orbBloom beyond the rim, faded out by a
        // radial mask. Only the item turns, so the masked layers are drawn once per
        // colour change, not per frame. MultiEffect's blur spreads a 16 px disc by
        // barely 3 px, too little for the glow.
        Item {
            objectName: "orbBloom"
            anchors.centerIn: parent
            width: Theme.orbSize + 2 * Theme.orbBloom
            height: width
            rotation: Cava.rimAngle
            opacity: Cava.bloom * orb.liveness
            visible: opacity > 0

            RimLight {
                id: bloomColours

                anchors.fill: parent
                thickness: width / 2
                brightness: 1
                visible: false
                layer.enabled: true
            }

            Shape {
                id: bloomFalloff

                readonly property real rimStop: Theme.orbSize / width

                anchors.fill: parent
                visible: false
                layer.enabled: true
                preferredRendererType: Shape.CurveRenderer

                ShapePath {
                    strokeWidth: -1
                    strokeColor: "transparent"
                    fillGradient: RadialGradient {
                        centerX: bloomFalloff.width / 2
                        centerY: bloomFalloff.height / 2
                        centerRadius: bloomFalloff.width / 2
                        focalX: centerX
                        focalY: centerY

                        GradientStop {
                            position: bloomFalloff.rimStop
                            color: "black"
                        }
                        GradientStop {
                            position: (1 + 2 * bloomFalloff.rimStop) / 3
                            color: Qt.rgba(0, 0, 0, 0.55)
                        }
                        GradientStop {
                            position: (2 + bloomFalloff.rimStop) / 3
                            color: Qt.rgba(0, 0, 0, 0.2)
                        }
                        GradientStop {
                            position: 1
                            color: "transparent"
                        }
                    }

                    PathRectangle {
                        width: bloomFalloff.width
                        height: bloomFalloff.height
                        radius: bloomFalloff.width / 2
                    }
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: bloomColours
                maskEnabled: true
                maskSource: bloomFalloff
                // A soft ramp over the mask's alpha; the default thresholds cut it hard.
                maskThresholdMin: 0.5
                maskSpreadAtMin: 1
            }
        }

        Rectangle {
            objectName: "orbCore"
            anchors.centerIn: parent
            width: Theme.orbSize
            height: Theme.orbSize
            radius: width / 2
            color: Music.artColor
        }

        RimLight {
            id: rim

            objectName: "orbRim"
            anchors.centerIn: parent
            width: Theme.orbSize
            height: Theme.orbSize
            thickness: Theme.orbRimWidth
            rotation: Cava.rimAngle
            level: Cava.level
            opacity: rim.levelOpacity * orb.liveness
            visible: opacity > 0
        }
    }
}
