import QtQuick
import ".."

// One attention indicator of the right island: a permanent pill hit area of
// the indicator height; hover only tints it. The width and opacity carry the
// appear and disappear, the gap to the indicator before it rides inside the
// width. Any click first emits pressed, then the button's own signal.
Item {
    id: indicator

    property bool shown: false
    // Keeps its place but is not drawn: the bell while the stack shows and
    // the island morphs back; then it fades in.
    property bool held: false
    property bool gap: false
    property string iconName: ""
    property int count: 0
    property color tint: Colors.foreground
    property string accessibleName: ""
    property bool takesWheel: false

    signal pressed
    signal activated
    signal middleClicked
    signal rightClicked
    signal scrolled(real delta)

    readonly property real pillWidth: 2 * Theme.gap + Theme.iconSize + (count > 0 ? Theme.indicatorCountGap + Math.ceil(countText.implicitWidth) : 0)
    readonly property real targetWidth: shown ? (gap ? Theme.indicatorGap : 0) + pillWidth : 0

    width: targetWidth
    height: Theme.islandHeight
    opacity: shown && !held ? 1 : 0
    enabled: shown && !held
    clip: true

    Behavior on width {
        enabled: !indicator.held

        IndicatorAnimation {}
    }
    Behavior on opacity {
        IndicatorAnimation {}
    }

    Rectangle {
        x: indicator.gap ? Theme.indicatorGap : 0
        y: (Theme.islandHeight - height) / 2
        width: indicator.pillWidth
        height: Theme.indicatorPill
        radius: height / 2
        color: pointer.containsMouse ? Colors.hoverSurface : "transparent"

        Behavior on color {
            ColorCrossfade {}
        }

        Icon {
            x: Theme.gap
            anchors.verticalCenter: parent.verticalCenter
            name: indicator.iconName
            color: indicator.tint
        }

        Label {
            id: countText

            visible: indicator.count > 0
            x: Theme.gap + Theme.iconSize + Theme.indicatorCountGap
            anchors.verticalCenter: parent.verticalCenter
            text: indicator.count
            color: indicator.tint
            numeric: true
            font.pixelSize: Theme.indicatorCountFontSize
        }

        MouseArea {
            id: pointer

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            onClicked: mouse => {
                indicator.pressed();
                if (mouse.button === Qt.MiddleButton)
                    indicator.middleClicked();
                else if (mouse.button === Qt.RightButton)
                    indicator.rightClicked();
                else
                    indicator.activated();
            }
            onWheel: wheel => {
                if (!indicator.takesWheel) {
                    wheel.accepted = false;
                    return;
                }
                indicator.scrolled(wheel.angleDelta.y);
            }
        }

        Accessible.role: Accessible.Button
        Accessible.name: indicator.accessibleName
    }

    component IndicatorAnimation: MorphAnimation {
        durationOverride: Motion.indicatorDuration
        curveOverride: Motion.indicatorCurve
    }
}
