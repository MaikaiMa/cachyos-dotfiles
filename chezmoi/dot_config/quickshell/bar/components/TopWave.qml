import QtQuick
import ".."
import "../services"

// A breathing band of light along the top edge: one Catmull-Rom curve through
// the smoothed cava bands, stroked several times wider and fainter in place of a
// blur, in a horizontal gradient of the music colours, and faded out toward the
// bottom inside the canvas itself (the window behind it is transparent). It only
// repaints on the audio tick while Cava.waveOpacity is above zero.
//
// The canvas is rasterised by QPainter on the CPU, and four wide strokes across
// the screen cost about half a core at full resolution. It paints at
// Theme.waveResolution of the item's size and is scaled up with smooth filtering;
// the soft glow hides the lower resolution.
Item {
    id: wave

    readonly property var colors: [Music.artColor, Music.artLight, Colors.primary, Music.artWarm, Music.artColor]

    signal painted

    height: Theme.waveHeight
    opacity: Cava.waveOpacity
    // Off at once when switched off, without waiting for the fade.
    visible: Settings.waveEnabled && opacity > 0
    enabled: false

    onVisibleChanged: {
        if (visible)
            canvas.requestPaint();
    }

    Connections {
        target: Cava
        enabled: wave.visible

        function onTick() {
            canvas.requestPaint();
        }
    }

    function trace(context: var, points: var) {
        const at = index => points[Math.max(0, Math.min(points.length - 1, index))];
        context.beginPath();
        context.moveTo(points[0][0], points[0][1]);
        for (let index = 0; index < points.length - 1; index += 1) {
            const [x0, y0] = at(index - 1);
            const [x1, y1] = at(index);
            const [x2, y2] = at(index + 1);
            const [x3, y3] = at(index + 2);
            context.bezierCurveTo(x1 + (x2 - x0) / 6, y1 + (y2 - y0) / 6, x2 - (x3 - x1) / 6, y2 - (y3 - y1) / 6, x2, y2);
        }
    }

    Canvas {
        id: canvas

        width: wave.width * Theme.waveResolution
        height: wave.height * Theme.waveResolution
        scale: 1 / Theme.waveResolution
        transformOrigin: Item.TopLeft
        smooth: true

        onPainted: wave.painted()

        // Drawn in the item's full-size coordinates; the context scale maps the
        // strokes, the gradients and the fade onto the smaller canvas.
        onPaint: {
            const context = getContext("2d");
            context.reset();
            context.scale(Theme.waveResolution, Theme.waveResolution);
            const width = wave.width;
            const height = wave.height;
            const bands = Cava.smoothBands;
            // The curve runs a little past both edges so its round caps stay off screen.
            const step = width * 1.1 / (bands.length - 1);
            const points = bands.map((value, index) => [index * step - width * 0.05, 2 + Theme.waveAmplitude * value]);

            const gradient = context.createLinearGradient(0, 0, width, 0);
            wave.colors.forEach((color, index) => gradient.addColorStop(index / (wave.colors.length - 1), String(color)));
            // The band above the curve is filled at the core's alpha, so the top
            // edge stays covered when the curve swings down past the core stroke.
            const strokes = Theme.waveStrokes;
            wave.trace(context, points);
            context.lineTo(points[points.length - 1][0], -Theme.waveTopOverdraw);
            context.lineTo(points[0][0], -Theme.waveTopOverdraw);
            context.closePath();
            context.fillStyle = gradient;
            context.globalAlpha = strokes[strokes.length - 1][1];
            context.fill();

            wave.trace(context, points);
            context.strokeStyle = gradient;
            context.lineCap = "round";
            context.lineJoin = "round";
            for (const [lineWidth, alpha] of strokes) {
                context.lineWidth = lineWidth;
                context.globalAlpha = alpha;
                context.stroke();
            }

            context.globalAlpha = 1;
            context.globalCompositeOperation = "destination-in";
            const fade = context.createLinearGradient(0, 0, 0, height);
            fade.addColorStop(0, "rgba(0, 0, 0, 1)");
            fade.addColorStop(0.25, "rgba(0, 0, 0, 1)");
            fade.addColorStop(1, "rgba(0, 0, 0, 0)");
            context.fillStyle = fade;
            context.fillRect(0, 0, width, height);
            context.globalCompositeOperation = "source-over";
        }
    }
}
