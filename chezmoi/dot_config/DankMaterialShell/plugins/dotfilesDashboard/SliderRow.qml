import QtQuick
import qs.Common
import qs.Widgets

Column {
    id: row

    property string iconName: ""
    property string label: ""
    property int value: 0
    property int minimum: 0
    property int maximum: 100
    property string unit: "%"
    property bool available: true
    property bool muted: false
    property bool showMuteButton: false
    property string muteIconName: ""

    signal moved(int newValue)
    signal muteToggled

    spacing: Theme.spacingXS

    Item {
        width: parent.width
        height: 32

        DankIcon {
            id: labelIcon

            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            name: row.iconName
            size: Theme.iconSizeSmall + 2
            color: row.available && !row.muted ? Theme.primary : Theme.surfaceVariantText
        }

        StyledText {
            anchors.left: labelIcon.right
            anchors.leftMargin: Theme.spacingS
            anchors.right: valueLabel.left
            anchors.rightMargin: Theme.spacingS
            anchors.verticalCenter: parent.verticalCenter
            text: row.label
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Bold
            color: Theme.surfaceText
            elide: Text.ElideRight
        }

        StyledText {
            id: valueLabel

            anchors.right: row.showMuteButton ? muteButton.left : parent.right
            anchors.rightMargin: row.showMuteButton ? Theme.spacingS : 0
            anchors.verticalCenter: parent.verticalCenter
            text: row.available ? row.value + row.unit : "--"
            font.pixelSize: Theme.fontSizeMedium
            color: row.muted ? Theme.error : Theme.surfaceVariantText
        }

        DankActionButton {
            id: muteButton

            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            visible: row.showMuteButton
            circular: false
            iconName: row.muteIconName
            iconSize: Theme.iconSizeSmall + 2
            iconColor: row.muted ? Theme.error : Theme.surfaceText
            backgroundColor: Theme.ccPillInactiveBg
            onClicked: row.muteToggled()
        }
    }

    DankSlider {
        id: slider

        width: parent.width
        height: 20
        enabled: row.available
        minimum: row.minimum
        maximum: row.maximum
        showValue: false
        unit: row.unit
        thumbOutlineColor: Theme.surfaceContainer
        trackColor: Theme.ccSliderTrackColor
        trackOpacity: Theme.ccSliderTrackOpacity
        onSliderValueChanged: newValue => row.moved(newValue)
    }

    Binding {
        target: slider
        property: "value"
        value: row.value
        when: !slider.isDragging
    }
}
