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
Item {
    id: panel

    property bool shown: false

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

    implicitWidth: Theme.panelWidths.sound
    implicitHeight: 2 * Theme.panelPadding + Theme.controlRowHeight + Theme.gap + listHeight

    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    onShownChanged: {
        if (shown)
            list.contentY = 0;
    }

    onOutputKeysChanged: sync(outputModel, outputKeys)
    onInputKeysChanged: sync(inputModel, inputKeys)
    onAppKeysChanged: sync(appModel, appKeys)

    Component.onCompleted: {
        sync(outputModel, outputKeys);
        sync(inputModel, inputKeys);
        sync(appModel, appKeys);
    }

    function sectionHeight(count: int): real {
        return Theme.sectionHeaderHeight + count * Theme.listRowHeight + (count - 1) * Theme.listRowGap;
    }

    function nodeFor(nodes: var, key: string): var {
        return nodes.find(node => String(node.id) === key) ?? null;
    }

    // Patched by key, not replaced: a row keeps its delegate, so a capsule being
    // dragged is never rebuilt under the pointer.
    function sync(model: ListModel, keys: var) {
        for (let index = model.count - 1; index >= 0; index--) {
            if (!keys.includes(model.get(index).rowKey))
                model.remove(index);
        }
        keys.forEach((key, index) => {
            if (index < model.count && model.get(index).rowKey === key)
                return;
            for (let from = index + 1; from < model.count; from++) {
                if (model.get(from).rowKey === key) {
                    model.move(from, index, 1);
                    return;
                }
            }
            model.insert(index, {
                rowKey: key
            });
        });
    }

    // Tab can land on a row below the visible part.
    function reveal(item: Item) {
        const top = item.mapToItem(sections, 0, 0).y;
        if (top < list.contentY)
            list.contentY = top;
        else if (top + item.height > list.contentY + list.height)
            list.contentY = top + item.height - list.height;
    }

    ListModel {
        id: outputModel
    }

    ListModel {
        id: inputModel
    }

    ListModel {
        id: appModel
    }

    PanelControlRow {
        id: controls

        x: Theme.panelPadding
        y: Theme.panelPadding
        width: panel.width - 2 * Theme.panelPadding
        hasSwitch: false
        stateText: Audio.sink ? Audio.sinkLabel(Audio.sink) + " · " + (Audio.muted ? "muted" : Math.round(Audio.volume * 100) + "%") : "No output"
        actionLabel: "Open audio settings"
        // The settings window needs the keyboard, which the open panel holds.
        onActionTriggered: {
            Dms.openSettingsTab("audio");
            Shell.close();
        }
    }

    Flickable {
        id: list

        objectName: "soundList"
        x: Theme.panelPadding
        y: controls.y + controls.height + Theme.gap
        width: panel.width - 2 * Theme.panelPadding
        height: panel.listHeight
        contentHeight: sections.height
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
            id: sections

            width: list.width
            spacing: Theme.sectionGap

            Column {
                objectName: "outputSection"
                width: parent.width
                visible: outputModel.count > 0
                spacing: Theme.listRowGap

                SectionHeader {
                    iconName: "speaker"
                    text: "Output"
                }

                Repeater {
                    model: outputModel

                    NetworkRow {
                        id: outputRow

                        required property string rowKey
                        readonly property var node: panel.nodeFor(Audio.sinks, rowKey)

                        width: sections.width
                        iconName: node ? Audio.deviceIcon(node) : "speaker"
                        title: node ? Audio.sinkLabel(node) : ""
                        highlighted: node !== null && node === Audio.sink
                        onClicked: Audio.setDefaultSink(node)
                        onActiveFocusChanged: {
                            if (activeFocus)
                                panel.reveal(outputRow);
                        }
                    }
                }
            }

            Column {
                objectName: "inputSection"
                width: parent.width
                visible: inputModel.count > 0
                spacing: Theme.listRowGap

                SectionHeader {
                    iconName: "mic"
                    text: "Input"
                }

                Repeater {
                    model: inputModel

                    NetworkRow {
                        id: inputRow

                        required property string rowKey
                        readonly property var node: panel.nodeFor(Audio.sources, rowKey)

                        width: sections.width
                        iconName: node ? Audio.deviceIcon(node) : "mic"
                        title: node ? Audio.sinkLabel(node) : ""
                        highlighted: node !== null && node === Audio.source
                        level: highlighted ? (Audio.micMuted ? 0 : Audio.micLevel) : -1
                        onClicked: Audio.setDefaultSource(node)
                        onActiveFocusChanged: {
                            if (activeFocus)
                                panel.reveal(inputRow);
                        }
                    }
                }
            }

            Column {
                objectName: "appSection"
                width: parent.width
                visible: appModel.count > 0
                spacing: Theme.listRowGap

                SectionHeader {
                    iconName: "apps"
                    text: "Apps"
                }

                Repeater {
                    model: appModel

                    Item {
                        id: appRow

                        required property string rowKey
                        readonly property var group: Audio.appGroup(rowKey)
                        readonly property bool groupMuted: Audio.groupMuted(group)

                        objectName: "appRow"
                        width: sections.width
                        height: Theme.listRowHeight

                        Rectangle {
                            anchors.fill: parent
                            radius: Theme.listRowRadius
                            color: Colors.surfaceContainerHigh
                        }

                        Image {
                            id: appImage

                            x: Theme.listRowPadding - 1
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.appIconSize
                            height: Theme.appIconSize
                            visible: source.toString() !== "" && status === Image.Ready
                            source: appRow.group ? appRow.group.icon : ""
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

                        Text {
                            x: Theme.listRowPadding + Theme.toggleIconSize + Theme.listRowPadding
                            width: appSlider.x - Theme.gap - x
                            anchors.verticalCenter: parent.verticalCenter
                            text: appRow.group ? appRow.group.name : appRow.rowKey
                            elide: Text.ElideRight
                            color: Colors.foreground
                            font.family: Theme.fontFamily
                            font.pixelSize: Theme.fontSize
                            font.weight: Theme.fontWeight
                        }

                        CapsuleSlider {
                            id: appSlider

                            objectName: "appSlider"
                            x: parent.width - (Theme.listRowHeight - Theme.appSliderHeight) / 2 - width
                            anchors.verticalCenter: parent.verticalCenter
                            width: Theme.appSliderWidth
                            implicitHeight: Theme.appSliderHeight
                            iconZone: Theme.appSliderIconZone
                            valueZone: Theme.appSliderValueZone
                            iconSize: 14
                            trackColor: Colors.surfaceContainer
                            label: (appRow.group ? appRow.group.name : appRow.rowKey) + " volume"
                            available: appRow.group !== null && appRow.group.nodes.some(node => node.audio !== null)
                            value: Audio.groupVolume(appRow.group) * 100
                            muted: appRow.groupMuted
                            iconName: appRow.groupMuted ? "volume_off" : "volume_up"
                            onMoved: target => Audio.setGroupVolume(appRow.group, target / 100)
                            onIconClicked: Audio.toggleGroupMute(appRow.group)
                            onActiveFocusChanged: {
                                if (activeFocus)
                                    panel.reveal(appRow);
                            }
                        }
                    }
                }
            }
        }
    }

    // A thin scroll hint while the sections are taller than their window.
    Rectangle {
        visible: list.contentHeight > list.height
        x: list.x + list.width - width
        y: list.y + list.visibleArea.yPosition * list.height
        width: 4
        height: list.visibleArea.heightRatio * list.height
        radius: width / 2
        color: Qt.alpha(Colors.foreground, 0.25)
    }

    Text {
        x: list.x
        y: list.y
        width: list.width
        height: list.height
        visible: panel.contentHeight === 0
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: "No audio devices"
        color: Colors.foregroundVariant
        font.family: Theme.fontFamily
        font.pixelSize: Theme.homeDetailFontSize
        font.weight: Theme.fontWeight
    }

    // The notifications header's language: a small glyph and the section name.
    component SectionHeader: Item {
        id: header

        property string iconName: ""
        property string text: ""

        width: parent ? parent.width : 0
        // The column's row gap follows it; together they make the header token.
        height: Theme.sectionHeaderHeight - Theme.listRowGap

        Row {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                name: header.iconName
                size: 14
                color: Colors.foregroundVariant
            }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: header.text
                color: Colors.foregroundVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.secondaryFontSize
                font.weight: Theme.fontWeight
            }
        }
    }
}
