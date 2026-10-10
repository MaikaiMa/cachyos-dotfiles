pragma ComponentBehavior: Bound

import QtQuick
import qs

// A full-width capsule without a thumb: the fill runs from the left edge and its
// edge is the handle. Icon and value are drawn twice, once on the track and once
// in the accent's foreground clipped to the fill, so they flip where the fill passes.
// A capsule with a panel ends in a chevron zone behind a hairline, as the Wi-Fi
// tile does: the fill runs over the rest, and the zone, a right click, Enter or
// the menu key open the panel. No long press: on touch people hold before they drag.
Item {
    id: slider

    // 0..100, from the owning service.
    property real value: 0
    property real minimum: 0
    property bool available: true
    property bool muted: false
    property string iconName: ""
    property string accessibleName: ""
    // The chevron zone at the right end and the panel signal.
    property bool hasPanel: false
    // What the value zone shows; the owner may map shownValue to its own unit.
    property string valueText: Math.round(shownValue) + "%"
    // Requests land on multiples of this (temperatures in 500 K steps).
    property real snap: 1
    property real stepSize: Theme.sliderStep
    property int iconZone: Theme.sliderIconZone
    property int valueZone: Theme.sliderValueZone
    property int iconSize: Theme.iconSize
    property color trackColor: Colors.surfaceContainerHigh

    // A drag, a click on the track or a key asks for a value; the owner writes it.
    signal moved(real value)
    // A click on the icon zone without movement.
    signal iconClicked
    // The chevron zone, a right click, Enter or the menu key; only with hasPanel.
    signal panelRequested

    readonly property real shownTarget: internal.awaitingService ? internal.requestedValue : Math.max(0, Math.min(100, value))
    property real shownValue: shownTarget
    // The value runs over the capsule minus the chevron zone.
    readonly property real trackWidth: width - (hasPanel ? Theme.tileChevronZone : 0)
    readonly property real fillWidth: trackWidth * shownValue / 100
    readonly property bool overChevron: hasPanel && pointer.containsMouse && pointer.mouseX >= trackWidth

    implicitHeight: Theme.sliderHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.Slider
    Accessible.name: accessibleName
    Accessible.description: available ? valueText : ""

    // Dragging follows the pointer; everything else glides.
    Behavior on shownValue {
        enabled: !internal.dragging

        MorphAnimation {}
    }

    onValueChanged: {
        if (internal.awaitingService && Math.abs(value - internal.requestedValue) < 0.5)
            internal.awaitingService = false;
    }

    function request(target: real) {
        internal.requestedValue = Math.max(minimum, Math.min(100, Math.round(target / snap) * snap));
        internal.awaitingService = true;
        holdTimer.restart();
        moved(internal.requestedValue);
    }

    // Keys and the wheel move from what is shown as the target, so quick
    // repeats add up instead of starting from a stale service value.
    function step(units: real) {
        request((internal.awaitingService ? internal.requestedValue : value) + units);
    }

    function valueAt(pointerX: real): real {
        return Math.max(0, Math.min(100, pointerX / trackWidth * 100));
    }

    QtObject {
        id: internal

        // What the owner asked for last, shown until the service reports it back, so
        // the fill does not jump back while the write is under way.
        property real requestedValue: 0
        property bool awaitingService: false
        property bool dragging: false
    }

    // A value the service never reports exactly (rounding, a refused write)
    // falls back to the service after a moment.
    Timer {
        id: holdTimer

        interval: Motion.sliderHoldFallback
        onTriggered: internal.awaitingService = false
    }

    // Right keeps stepping: the panel opens with Enter or the menu key. Space is
    // the icon zone's click (mute), so an app row can be muted from the keyboard.
    Keys.onPressed: event => {
        if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier))
            return;
        if (hasPanel && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Menu)) {
            event.accepted = true;
            panelRequested();
            return;
        }
        if (!available)
            return;
        switch (event.key) {
        case Qt.Key_Left:
            step(-stepSize);
            break;
        case Qt.Key_Right:
            step(stepSize);
            break;
        case Qt.Key_Space:
            iconClicked();
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
        color: slider.trackColor

        ChevronZone {
            visible: slider.hasPanel
            x: slider.trackWidth
            width: track.width - x
            height: track.height
            shapeWidth: track.width
            shapeRadius: track.radius
            tint: Colors.hovered(slider.trackColor, false)
            lit: slider.overChevron
        }

        SliderLayer {
            tone: Colors.foreground
        }

        // The clip is square, the fill inside it is the whole capsule: the left
        // end stays round and the moving edge is straight.
        Item {
            id: fillClip

            width: slider.fillWidth
            height: parent.height
            clip: true

            Rectangle {
                width: track.width
                height: track.height
                radius: track.radius
                color: Colors.primary
                opacity: slider.muted ? Theme.mutedOpacity : 1

                Behavior on opacity {
                    Crossfade {}
                }
            }

            SliderLayer {
                tone: Colors.primaryForeground
            }
        }

        FocusRing {
            visible: slider.activeFocus
        }
    }

    // Grabs the pointer on press, so a drag keeps setting the value outside the
    // capsule; touch arrives as the same events. Reaches half the gap above and
    // below, so the chevron zone is a 40 x 40 touch target.
    MouseArea {
        id: pointer

        anchors.fill: parent
        anchors.topMargin: -Theme.sliderHitExtension
        anchors.bottomMargin: -Theme.sliderHitExtension
        enabled: slider.available || slider.hasPanel
        preventStealing: true
        hoverEnabled: slider.hasPanel
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: slider.hasPanel ? Qt.LeftButton | Qt.RightButton : Qt.LeftButton

        // Wheel notches are 120 units; touchpads send small deltas that add up
        // to the same 120 per step.
        property real wheelRemainder: 0

        property real startX: 0
        property real startY: 0
        property bool travelled: false
        property bool onIcon: false
        // Decided on press: a press in the chevron zone or with the right button
        // never drags; it opens the panel when released over the zone (or anywhere
        // for the right button).
        property bool onChevron: false
        property bool secondary: false

        function inChevron(x: real, y: real): bool {
            return slider.hasPanel && x >= slider.trackWidth && x <= width && y >= 0 && y <= height;
        }

        onPressed: mouse => {
            startX = mouse.x;
            startY = mouse.y;
            travelled = false;
            secondary = mouse.button === Qt.RightButton;
            onChevron = inChevron(mouse.x, mouse.y);
            onIcon = mouse.x < slider.iconZone;
        }
        onPositionChanged: mouse => {
            if (!pressed || onChevron || secondary || !slider.available)
                return;
            if (!travelled && Math.hypot(mouse.x - startX, mouse.y - startY) < Theme.sliderDragThreshold)
                return;
            travelled = true;
            internal.dragging = true;
            slider.request(slider.valueAt(mouse.x));
        }
        onReleased: mouse => {
            if (secondary) {
                slider.panelRequested();
                return;
            }
            if (onChevron) {
                if (inChevron(mouse.x, mouse.y))
                    slider.panelRequested();
                return;
            }
            if (travelled) {
                internal.dragging = false;
                return;
            }
            if (!slider.available)
                return;
            if (onIcon)
                slider.iconClicked();
            else
                slider.request(slider.valueAt(mouse.x));
        }
        onCanceled: internal.dragging = false
        onWheel: wheel => {
            if (!slider.available) {
                wheel.accepted = true;
                return;
            }
            // The same rule as the Qt Quick Controls Slider.
            const delta = wheel.angleDelta.y === 0 ? wheel.angleDelta.x : wheel.inverted ? -wheel.angleDelta.y : wheel.angleDelta.y;
            if (Math.sign(delta) !== Math.sign(wheelRemainder))
                wheelRemainder = 0;
            wheelRemainder += delta;
            const steps = Math.trunc(wheelRemainder / Theme.wheelNotch);
            if (steps !== 0) {
                wheelRemainder -= steps * Theme.wheelNotch;
                slider.step(steps * slider.stepSize);
            }
            wheel.accepted = true;
        }
    }

    component SliderLayer: Item {
        id: layer

        property color tone

        width: track.width
        height: track.height

        Icon {
            x: (slider.iconZone - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            name: slider.iconName
            size: slider.iconSize
            color: layer.tone
        }

        Label {
            x: slider.trackWidth - slider.valueZone
            width: slider.valueZone
            height: layer.height
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            text: slider.available ? slider.valueText : "–"
            color: layer.tone
            elide: Text.ElideNone
            numeric: true
            font.pixelSize: Theme.sliderValueFontSize
        }
    }
}
