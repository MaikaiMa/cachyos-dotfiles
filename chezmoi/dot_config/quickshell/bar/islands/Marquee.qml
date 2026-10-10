pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import qs
import qs.components

// A strong line and a secondary one as one run, clipped to its width. While
// running and too long it glides to its end and back, holding at each end,
// with soft edges; stopped, it rests at its start.
Item {
    id: marquee

    property string primaryText: ""
    property string secondaryText: ""
    property bool running: false
    property real primaryPixelSize: Theme.fontSize

    readonly property real overflow: Math.max(0, run.width - width)
    readonly property bool scrolling: overflow > 0 && running && !Motion.reduceMotion

    Item {
        id: box

        width: marquee.width
        height: marquee.height
        clip: true

        layer.enabled: marquee.scrolling
        layer.effect: MultiEffect {
            maskEnabled: true
            maskSource: fadeMask
            // A soft ramp over the mask's alpha; the default thresholds cut it hard.
            maskThresholdMin: 0.5
            maskSpreadAtMin: 1
        }

        Row {
            id: run

            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.musicArtistGap

            Label {
                id: primaryLabel

                text: marquee.primaryText
                strong: true
                font.pixelSize: marquee.primaryPixelSize
            }

            Label {
                anchors.baseline: primaryLabel.baseline
                text: marquee.secondaryText
                visible: text !== ""
                secondary: true
            }
        }

        SequentialAnimation {
            id: glide

            readonly property real shift: marquee.overflow + Theme.marqueeTail
            readonly property real time: Motion.marqueeBase + marquee.overflow * Motion.marqueePerPixel
            readonly property int travel: Math.round(time * Motion.marqueeTravelShare)
            readonly property int hold: Math.round(time * Motion.marqueeHoldShare)

            running: marquee.scrolling
            loops: Animation.Infinite
            onRunningChanged: {
                if (!running)
                    run.x = 0;
            }

            PauseAnimation {
                duration: glide.hold
            }
            NumberAnimation {
                target: run
                property: "x"
                from: 0
                to: -glide.shift
                duration: glide.travel
            }
            PauseAnimation {
                duration: 2 * glide.hold
            }
            NumberAnimation {
                target: run
                property: "x"
                from: -glide.shift
                to: 0
                duration: glide.travel
            }
            PauseAnimation {
                duration: glide.hold
            }
        }
    }

    Rectangle {
        id: fadeMask

        width: marquee.width
        height: marquee.height
        visible: false
        layer.enabled: true
        gradient: Gradient {
            orientation: Gradient.Horizontal

            GradientStop {
                position: 0
                color: "transparent"
            }
            GradientStop {
                position: Theme.marqueeFade / Math.max(1, fadeMask.width)
                color: "black"
            }
            GradientStop {
                position: 1 - Theme.marqueeFade / Math.max(1, fadeMask.width)
                color: "black"
            }
            GradientStop {
                position: 1
                color: "transparent"
            }
        }
    }
}
