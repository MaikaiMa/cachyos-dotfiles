pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Sound state of the centre island, opened from the Volume or Microphone
// capsule: a control row without a switch, then Output, Input and Apps, each
// only while it has rows. A click on an output or input makes it the default;
// the default input shows its live level; each application gets one row whose
// compact capsule moves all of its streams. Everything lives in `Audio`; the
// level and the app streams run only while this panel is open.
Panel {
    id: panel

    name: "sound"

    readonly property var outputKeys: Audio.sinks.map(node => String(node.id))
    readonly property var inputKeys: Audio.sources.map(node => String(node.id))
    readonly property var appKeys: Audio.appStreams.map(group => group.key)

    readonly property real contentHeight: {
        let height = 0;
        let sections = 0;
        for (const count of [outputKeys.length, inputKeys.length, appKeys.length]) {
            if (count === 0)
                continue;
            height += sectionHeight(count);
            sections++;
        }
        return height + Math.max(0, sections - 1) * Theme.sectionGap;
    }
    readonly property real listHeight: contentHeight > 0 ? Math.min(Theme.soundListMaxHeight, contentHeight) : Theme.listRowHeight

    implicitHeight: 2 * Theme.panelPadding + Theme.controlRowHeight + Theme.gap + listHeight

    onOpened: list.contentY = 0

    // Patched by key, not replaced: a row keeps its delegate, so a capsule being
    // dragged is never rebuilt under the pointer.
    onOutputKeysChanged: outputModel.sync(outputKeys)
    onInputKeysChanged: inputModel.sync(inputKeys)
    onAppKeysChanged: appModel.sync(appKeys)

    Component.onCompleted: {
        outputModel.sync(outputKeys);
        inputModel.sync(inputKeys);
        appModel.sync(appKeys);
    }

    function sectionHeight(count: int): real {
        return Theme.sectionHeaderHeight + count * Theme.listRowHeight + (count - 1) * Theme.listRowGap;
    }

    function nodeFor(nodes: var, key: string): var {
        return nodes.find(node => String(node.id) === key) ?? null;
    }

    function reveal(item: Item) {
        const top = item.mapToItem(sections, 0, 0).y;
        if (top < list.contentY)
            list.contentY = top;
        else if (top + item.height > list.contentY + list.height)
            list.contentY = top + item.height - list.height;
    }

    // The row of a section that holds item, or null.
    function rowOf(item: Item): Item {
        let row = item;
        while (row && row.parent && row.parent.parent !== sections)
            row = row.parent;
        return row && row.parent && row.parent.parent === sections ? row : null;
    }

    // Tab can land on a row below the visible part.
    Connections {
        target: panel.Window.window
        enabled: panel.shown

        function onActiveFocusItemChanged() {
            const row = panel.rowOf(panel.Window.activeFocusItem);
            if (row)
                panel.reveal(row);
        }
    }

    KeyedListModel {
        id: outputModel
    }

    KeyedListModel {
        id: inputModel
    }

    KeyedListModel {
        id: appModel
    }

    PanelControlRow {
        id: controls

        x: panel.contentX
        y: Theme.panelPadding
        width: panel.contentWidth
        hasSwitch: false
        text: Audio.sink ? Audio.nodeLabel(Audio.sink) + " · " + (Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%") : "No output"
        actionLabel: "Open audio settings"
        settingsTab: "audio"
    }

    Flickable {
        id: list

        objectName: "soundList"
        x: panel.contentX
        y: controls.y + controls.height + Theme.gap
        width: panel.contentWidth
        height: panel.listHeight
        contentHeight: sections.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sections

            width: list.width
            spacing: Theme.sectionGap

            SoundSection {
                objectName: "outputSection"
                rows: outputModel
                iconName: "speaker"
                title: "Output"

                delegate: ListRow {
                    required property string rowKey
                    readonly property var node: panel.nodeFor(Audio.sinks, rowKey)

                    width: sections.width
                    iconName: node ? Audio.deviceIcon(node) : "speaker"
                    title: node ? Audio.nodeLabel(node) : ""
                    highlighted: node !== null && node === Audio.sink
                    onClicked: Audio.setDefaultSink(node)
                }
            }

            SoundSection {
                objectName: "inputSection"
                rows: inputModel
                iconName: "mic"
                title: "Input"

                delegate: ListRow {
                    required property string rowKey
                    readonly property var node: panel.nodeFor(Audio.sources, rowKey)

                    width: sections.width
                    iconName: node ? Audio.deviceIcon(node) : "mic"
                    title: node ? Audio.nodeLabel(node) : ""
                    highlighted: node !== null && node === Audio.source
                    level: highlighted ? (Audio.micMuted ? 0 : Audio.micLevel) : -1
                    onClicked: Audio.setDefaultSource(node)
                }
            }

            SoundSection {
                objectName: "appSection"
                rows: appModel
                iconName: "apps"
                title: "Apps"

                delegate: AppVolumeRow {
                    required property string rowKey

                    width: sections.width
                    key: rowKey
                }
            }
        }
    }

    ScrollHint {
        view: list
    }

    Label {
        x: list.x
        y: list.y
        width: list.width
        height: list.height
        visible: panel.contentHeight === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "No audio devices"
        color: Colors.foregroundVariant
        font.pixelSize: Theme.fontSizeDetail
    }

    // A header over its rows, only while it has any. The column's row gap
    // follows the header; together they make the header token.
    component SoundSection: Column {
        id: section

        required property KeyedListModel rows
        property string iconName: ""
        property string title: ""
        property alias delegate: repeater.delegate

        width: parent ? parent.width : 0
        visible: rows.count > 0
        spacing: Theme.listRowGap

        SectionHeader {
            width: section.width
            height: Theme.sectionHeaderHeight - Theme.listRowGap
            iconName: section.iconName
            text: section.title
        }

        Repeater {
            id: repeater

            model: section.rows
        }
    }
}
