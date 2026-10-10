import QtQuick
import QtQuick.Shapes
import qs
import qs.services

// A ring along the inside edge of a rounded rectangle, lit by a conic gradient in
// the music colours. A thickness of half the short side fills the shape. The light
// turns with angle; the owner either binds angle or rotates the whole item.
Shape {
    id: rim

    property real radius: Math.min(width, height) / 2
    property real thickness: Theme.orbRimWidth
    property real angle: 0
    // The audio level, 0..1: the light brightens with it, and levelOpacity is
    // the matching opacity for the owner to multiply into its own fade.
    property real level: 0
    readonly property real levelOpacity: Theme.rimOpacityRest + Theme.rimOpacityGain * level
    // Multiplies the colours' value: 1 is the plain palette.
    property real brightness: Theme.rimBrightnessRest + Theme.rimBrightnessGain * level
    // Pushes the lighter and warmer stops toward white, 0..1.
    property real lift: 0

    readonly property bool filled: 2 * thickness >= Math.min(width, height)

    function lit(base: color): color {
        return Qt.lighter(base, brightness);
    }

    function lifted(base: color): color {
        return lit(Qt.tint(base, Qt.rgba(1, 1, 1, lift)));
    }

    preferredRendererType: Shape.CurveRenderer

    ShapePath {
        strokeWidth: -1
        strokeColor: "transparent"
        fillRule: ShapePath.OddEvenFill
        fillGradient: ConicalGradient {
            centerX: rim.width / 2
            centerY: rim.height / 2
            angle: rim.angle

            GradientStop {
                position: 0
                color: rim.lifted(Music.artLight)
            }
            GradientStop {
                position: 0.25
                color: rim.lit(Colors.primary)
            }
            GradientStop {
                position: 0.5
                color: rim.lifted(Music.artWarm)
            }
            GradientStop {
                position: 0.75
                color: rim.lit(Music.artColor)
            }
            GradientStop {
                position: 1
                color: rim.lifted(Music.artLight)
            }
        }

        PathRectangle {
            width: rim.width
            height: rim.height
            radius: rim.radius
        }

        // The hole; an empty rectangle adds nothing to the path.
        PathRectangle {
            x: rim.thickness
            y: rim.thickness
            width: rim.filled ? 0 : rim.width - 2 * rim.thickness
            height: rim.filled ? 0 : rim.height - 2 * rim.thickness
            radius: Math.max(0, rim.radius - rim.thickness)
        }
    }
}
