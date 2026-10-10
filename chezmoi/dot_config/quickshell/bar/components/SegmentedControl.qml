pragma ComponentBehavior: Bound

import QtQuick
import qs

// A pill of equal segments with a sliding accent under the current one. The owner
// keeps currentIndex and writes it on selected, so a service can drive it too.
Item {
    id: control

    property var model: []
    property int currentIndex: 0
    property string accessibleName: ""
    property int fontSize: Theme.secondaryFontSize
    // Off: clicks and keys do nothing; the control looks the same.
    property bool interactive: true
    // The pill under the segments; Display's rows sit on the panel, not on a tile.
    property color trackColor: Colors.surfaceContainer

    signal selected(int index)

    readonly property int count: model.length
    readonly property real segmentWidth: (width - 2 * Theme.segmentedInset) / Math.max(1, count)

    implicitHeight: Theme.segmentedHeight
    activeFocusOnTab: true

    Accessible.role: Accessible.PageTabList
    Accessible.name: accessibleName
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
        color: control.trackColor

        Rectangle {
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
                MorphAnimation {
                    durationOverride: Motion.segmentSlideDuration
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

                Label {
                    anchors.centerIn: parent
                    width: Math.min(implicitWidth, parent.width - 2 * Theme.segmentedLabelInset)
                    text: segment.modelData
                    color: segment.current ? Colors.primaryForeground : Colors.foreground
                    font.pixelSize: control.fontSize

                    Behavior on color {
                        ColorCrossfade {}
                    }
                }

                // Takes the press itself, so a click never reaches the island below.
                MouseArea {
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

        FocusRing {
            visible: control.activeFocus
        }
    }
}
