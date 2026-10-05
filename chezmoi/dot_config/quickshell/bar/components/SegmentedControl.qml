pragma ComponentBehavior: Bound

import QtQuick
import ".."

// A pill of equal segments with a sliding accent under the current one. The owner
// keeps currentIndex and writes it on selected, so a service can drive it too.
Item {
    id: control

    property var model: []
    property int currentIndex: 0
    property string label: ""
    property int fontSize: Theme.secondaryFontSize
    // Off: clicks and keys do nothing; the control looks the same.
    property bool interactive: true

    signal selected(int index)

    readonly property int count: model.length
    readonly property real segmentWidth: (width - 2 * Theme.segmentedInset) / Math.max(1, count)

    implicitHeight: Theme.segmentedHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.PageTabList
    Accessible.name: label
    Accessible.description: model[currentIndex] ?? ""

    // Only a click or a key calls this: an owner changing currentIndex (a
    // service reporting back) never emits selected.
    function choose(index: int) {
        if (!interactive)
            return;
        const next = Math.max(0, Math.min(count - 1, index));
        if (next !== currentIndex)
            selected(next);
    }

    Keys.onPressed: event => {
        if (event.modifiers & (Qt.AltModifier | Qt.ControlModifier | Qt.MetaModifier))
            return;
        if (event.key === Qt.Key_Left)
            choose(currentIndex - 1);
        else if (event.key === Qt.Key_Right)
            choose(currentIndex + 1);
        else
            return;
        event.accepted = true;
    }

    Rectangle {
        id: track

        anchors.fill: parent
        radius: height / 2
        color: Colors.surfaceContainer

        Rectangle {
            objectName: "segmentIndicator"
            // Drawn under the labels; never part of the hit test.
            enabled: false
            visible: control.currentIndex >= 0 && control.currentIndex < control.count
            x: Theme.segmentedInset + control.currentIndex * control.segmentWidth
            y: Theme.segmentedInset
            width: control.segmentWidth
            height: parent.height - 2 * Theme.segmentedInset
            radius: height / 2
            color: Colors.primary

            Behavior on x {
                NumberAnimation {
                    duration: Motion.workspaceSlideDuration
                    easing.type: Easing.BezierSpline
                    easing.bezierCurve: Motion.growCurve
                }
            }
        }

        Repeater {
            model: control.model

            Item {
                id: segment

                required property string modelData
                required property int index

                readonly property bool current: index === control.currentIndex

                x: Theme.segmentedInset + index * control.segmentWidth
                y: Theme.segmentedInset
                width: control.segmentWidth
                height: track.height - 2 * Theme.segmentedInset

                Text {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 8)
                    text: segment.modelData
                    elide: Text.ElideRight
                    color: segment.current ? Colors.primaryForeground : Colors.foreground
                    font.family: Theme.fontFamily
                    font.pixelSize: control.fontSize
                    font.weight: Theme.fontWeight

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.crossfadeDuration
                            easing.type: Motion.crossfadeEasing
                        }
                    }
                }

                // Takes the press itself, so a click never reaches the island below.
                MouseArea {
                    objectName: "segmentHitArea"
                    anchors.fill: parent
                    enabled: control.interactive
                    acceptedButtons: Qt.LeftButton
                    hoverEnabled: true
                    preventStealing: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: control.choose(segment.index)
                }
            }
        }

        // Keyboard focus only arrives through Tab, so the ring never shows on a click.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -3
            radius: height / 2
            color: "transparent"
            border.width: 2
            border.color: Colors.primary
            visible: control.activeFocus
        }
    }
}
