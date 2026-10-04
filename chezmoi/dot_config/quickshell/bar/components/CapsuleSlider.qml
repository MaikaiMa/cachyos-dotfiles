pragma ComponentBehavior: Bound

import QtQuick
import ".."

// A full-width capsule without a thumb: the fill runs from the left edge and its
// edge is the handle. Icon and value are drawn twice, once on the track and once
// in the accent's foreground clipped to the fill, so they flip where the fill passes.
Item {
    id: slider

    // 0..100, from the owning service.
    property real value: 0
    property real minimum: 0
    property bool available: true
    property bool muted: false
    property string iconName: ""
    property string label: ""

    // A drag, a click on the track or a key asks for a value; the owner writes it.
    signal moved(real value)
    // A click on the icon zone without movement.
    signal iconClicked

    // What the owner asked for last, shown until the service reports it back, so
    // the fill does not jump back while the write is under way.
    property real requestedValue: 0
    property bool holding: false
    property bool dragging: false
    readonly property real shownTarget: holding ? requestedValue : Math.max(0, Math.min(100, value))
    property real shownValue: shownTarget
    readonly property real fillWidth: width * shownValue / 100

    implicitHeight: Theme.sliderHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Slider
    Accessible.name: label
    Accessible.description: available ? Math.round(shownTarget) + "%" : ""

    // Dragging follows the pointer; everything else glides.
    Behavior on shownValue {
        enabled: !slider.dragging

        NumberAnimation {
            duration: Motion.growDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Motion.growCurve
        }
    }

    onValueChanged: {
        if (holding && Math.abs(value - requestedValue) < 0.5)
            holding = false;
    }

    function request(target: real) {
        requestedValue = Math.max(minimum, Math.min(100, Math.round(target)));
        holding = true;
        holdTimer.restart();
        moved(requestedValue);
    }

    // Keys and the wheel move from what is shown as the target, so quick
    // repeats add up instead of starting from a stale service value.
    function step(units: real) {
        request((holding ? requestedValue : value) + units);
    }

    function valueAt(pointerX: real): real {
        return pointerX / width * 100;
    }

    // A value the service never reports exactly (rounding, a refused write)
    // falls back to the service after a moment.
    Timer {
        id: holdTimer

        interval: 1000
        onTriggered: slider.holding = false
    }

    Keys.onPressed: event => {
        if (!available || event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier))
            return;
        switch (event.key) {
        case Qt.Key_Left:
            step(-Theme.sliderStep);
            break;
        case Qt.Key_Right:
            step(Theme.sliderStep);
            break;
        case Qt.Key_Home:
            request(0);
            break;
        case Qt.Key_End:
            request(100);
            break;
        default:
            return;
        }
        event.accepted = true;
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Colors.surfaceContainerHigh

        SliderLayer {
            tone: Colors.foreground
        }

        // The clip is square, the fill inside it is the whole capsule: the left
        // end stays round and the moving edge is straight.
        Item {
            id: fillClip

            objectName: "fillClip"
            width: slider.fillWidth
            height: parent.height
            clip: true

            Rectangle {
                width: track.width
                height: track.height
                radius: track.radius
                color: Colors.primary
                opacity: slider.muted ? 0.4 : 1

                Behavior on opacity {
                    NumberAnimation {
                        duration: Motion.crossfadeDuration
                        easing.type: Motion.crossfadeEasing
                    }
                }
            }

            SliderLayer {
                objectName: "accentLayer"
                tone: Colors.primaryForeground
            }
        }

        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Colors.primary
            visible: slider.activeFocus
        }
    }

    // Grabs the pointer on press, so a drag keeps setting the value outside the
    // capsule; touch arrives as the same events.
    MouseArea {
        anchors.fill: parent
        enabled: slider.available
        preventStealing: true
        cursorShape: Qt.PointingHandCursor

        // Wheel notches are 120 units; touchpads send small deltas that add up
        // to the same 120 per step.
        property real wheelRemainder: 0

        property real startX: 0
        property real startY: 0
        property bool travelled: false
        property bool onIcon: false

        onPressed: mouse => {
            startX = mouse.x;
            startY = mouse.y;
            travelled = false;
            onIcon = mouse.x < Theme.sliderIconZone;
        }
        onPositionChanged: mouse => {
            if (!travelled && Math.hypot(mouse.x - startX, mouse.y - startY) < Theme.sliderDragThreshold)
                return;
            travelled = true;
            slider.dragging = true;
            slider.request(slider.valueAt(mouse.x));
        }
        onReleased: mouse => {
            if (travelled) {
                slider.dragging = false;
                return;
            }
            if (onIcon)
                slider.iconClicked();
            else
                slider.request(slider.valueAt(mouse.x));
        }
        onCanceled: slider.dragging = false
        onWheel: wheel => {
            // The same rule as the Qt Quick Controls Slider.
            const delta = wheel.angleDelta.y === 0 ? wheel.angleDelta.x : wheel.inverted ? -wheel.angleDelta.y : wheel.angleDelta.y;
            if (Math.sign(delta) !== Math.sign(wheelRemainder))
                wheelRemainder = 0;
            wheelRemainder += delta;
            const steps = Math.trunc(wheelRemainder / 120);
            if (steps !== 0) {
                wheelRemainder -= steps * 120;
                slider.step(steps * Theme.sliderStep);
            }
            wheel.accepted = true;
        }
    }

    // The icon zone and the value zone, fixed at the capsule's ends.
    component SliderLayer: Item {
        id: layer

        property color tone

        width: track.width
        height: track.height

        Icon {
            x: (Theme.sliderIconZone - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            name: slider.iconName
            color: layer.tone
        }

        Text {
            x: layer.width - Theme.sliderValueZone
            width: Theme.sliderValueZone
            height: layer.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: slider.available ? Math.round(slider.shownValue) + "%" : "–"
            color: layer.tone
            font.family: Theme.fontFamily
            font.pixelSize: Theme.sliderValueFontSize
            font.weight: Theme.fontWeight
            font.features: ({
                    tnum: 1
                })
        }
    }
}
