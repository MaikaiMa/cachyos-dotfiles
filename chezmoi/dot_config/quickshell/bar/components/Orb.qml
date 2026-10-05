import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import ".."
import "../services"

// The music orb: a solid sphere in the album colour with a travelling rim light
// and a bloom that follows the low band. Nothing scales. The item is the hit area,
// orbHitPadding wider than the sphere on every side, the size of the bloom.
Item {
    id: orb

    implicitWidth: Theme.orbSize + 2 * Theme.orbHitPadding
    implicitHeight: implicitWidth

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
        opacity: Cava.bloom

        RimLight {
            id: bloomColours

            anchors.fill: parent
            thickness: width / 2
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
        objectName: "orbRim"
        anchors.centerIn: parent
        width: Theme.orbSize
        height: Theme.orbSize
        thickness: Theme.orbRimWidth
        rotation: Cava.rimAngle
        brightness: 0.85 + 0.5 * Cava.level
        opacity: 0.6 + 0.4 * Cava.level
    }
}
