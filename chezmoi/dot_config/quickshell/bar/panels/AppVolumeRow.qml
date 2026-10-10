pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.components

// One application in the Sound panel: its icon, its name and a compact
// capsule that moves all of its streams together. key is an Audio.appStreams
// group key.
Item {
    id: row

    required property string key
    readonly property var group: Audio.appGroup(key)
    readonly property bool groupMuted: Audio.groupMuted(group)
    readonly property string name: group ? group.name : key

    height: Theme.listRowHeight

    Rectangle {
        anchors.fill: parent
        radius: Theme.listRowRadius
        color: Colors.surfaceContainerHigh
    }

    Image {
        id: appImage

        // A pixel left of the fallback glyph: app icons carry their own margin.
        x: Theme.listRowPadding - 1
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.appIconSize
        height: Theme.appIconSize
        visible: source.toString() !== "" && status === Image.Ready
        source: row.group ? row.group.icon : ""
        sourceSize.width: 2 * width
        sourceSize.height: 2 * height
        asynchronous: true
        smooth: true
    }

    Icon {
        x: Theme.listRowPadding
        anchors.verticalCenter: parent.verticalCenter
        visible: !appImage.visible
        name: "graphic_eq"
        size: Theme.toggleIconSize
        color: Colors.foregroundVariant
    }

    Label {
        x: Theme.listRowPadding + Theme.toggleIconSize + Theme.listRowPadding
        width: slider.x - Theme.gap - x
        anchors.verticalCenter: parent.verticalCenter
        text: row.name
    }

    CapsuleSlider {
        id: slider

        x: parent.width - (Theme.listRowHeight - Theme.appSliderHeight) / 2 - width
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.appSliderWidth
        implicitHeight: Theme.appSliderHeight
        iconZone: Theme.appSliderIconZone
        valueZone: Theme.appSliderValueZone
        iconSize: Theme.smallIconSize
        trackColor: Colors.surfaceContainer
        accessibleName: row.name + " volume"
        available: row.group !== null && row.group.nodes.some(node => node.audio !== null)
        value: Audio.groupVolume(row.group) * 100
        muted: row.groupMuted
        iconName: row.groupMuted ? "volume_off" : "volume_up"
        onMoved: target => Audio.setGroupVolume(row.group, target / 100)
        onIconClicked: Audio.toggleGroupMute(row.group)
    }
}
