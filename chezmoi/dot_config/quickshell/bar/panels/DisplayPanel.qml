pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Display state of the centre island, opened from the Brightness capsule:
// the night-light switch in the control row, then the night temperature with
// a read-only schedule line, brightness, the keyboard backlight (only while
// the cover is attached) and the rear window light with the theme colour it
// follows. Values live in `Display`, `Brightness` and `Dms`.
Item {
    id: panel

    property bool shown: false

    readonly property bool keyboardShown: Display.keyboardAvailable && !Tablet.detached
    readonly property bool rearShown: Display.rearAvailable
    readonly property var levelLabels: ["Off", "Low", "Medium", "High"]

    implicitWidth: Theme.panelWidths.display
    implicitHeight: 2 * Theme.panelPadding + Theme.controlRowHeight + Theme.gap + Theme.sliderHeight + Theme.scheduleLineHeight + Theme.sliderGap + Theme.sliderHeight + (keyboardShown ? Theme.sliderGap + Theme.sliderHeight : 0) + (rearShown ? Theme.sliderGap + Theme.sliderHeight : 0)

    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    // The DMS settings change these behind the bar's back; Brightness reads
    // itself when the panel opens.
    onShownChanged: {
        if (shown)
            Dms.refresh();
    }

    PanelControlRow {
        id: controls

        x: Theme.panelPadding
        y: Theme.panelPadding
        width: panel.width - 2 * Theme.panelPadding
        switchName: "Night light"
        checked: Dms.nightLight
        stateText: Dms.nightLight ? "On" + (Display.nightTemperature > 0 ? " · " + Display.nightTemperature + " K" : "") : "Off"
        actionLabel: "Open night light settings"
        onToggled: Dms.toggleNightLight()
        // The schedule can only be changed there; the window needs the keyboard.
        onActionTriggered: {
            Dms.openSettingsTab("display_gamma");
            Shell.close();
        }
    }

    Column {
        x: Theme.panelPadding
        y: controls.y + controls.height + Theme.gap
        width: panel.width - 2 * Theme.panelPadding

        CapsuleSlider {
            id: nightSlider

            objectName: "nightSlider"
            width: parent.width
            label: "Night light temperature"
            available: Display.nightTemperature > 0
            muted: !Dms.nightLight
            value: Display.nightFraction(Display.nightTemperature)
            snap: 100 * Display.nightStep / (Display.nightMaximum - Display.nightMinimum)
            stepSize: snap
            valueText: Display.nightKelvin(nightSlider.shownValue) + " K"
            iconName: "nightlight"
            onMoved: target => Display.setNightTemperature(Display.nightKelvin(target))
            onIconClicked: Dms.toggleNightLight()
        }

        Text {
            objectName: "scheduleLine"
            width: parent.width
            height: Theme.scheduleLineHeight
            leftPadding: Theme.sliderIconZone
            verticalAlignment: Text.AlignVCenter
            text: Display.scheduleText
            elide: Text.ElideRight
            color: Colors.foregroundVariant
            font.family: Theme.fontFamily
            font.pixelSize: Theme.secondaryFontSize
            font.weight: Theme.fontWeight
        }

        Item {
            width: 1
            height: Theme.sliderGap
        }

        CapsuleSlider {
            objectName: "displayBrightnessSlider"
            width: parent.width
            label: "Brightness"
            available: Brightness.available
            minimum: 1
            value: Math.max(0, Brightness.percentage)
            iconName: "light_mode"
            onMoved: target => Brightness.set(target)
            onIconClicked: Brightness.cycle()
        }

        LevelRow {
            objectName: "keyboardRow"
            shown: panel.keyboardShown
            iconName: "keyboard"
            title: "Keyboard"
            level: Display.keyboardLevel
            onChosen: level => Display.setKeyboardLevel(level)
        }

        LevelRow {
            objectName: "rearRow"
            shown: panel.rearShown
            iconName: "wb_iridescent"
            title: "Rear light"
            dotColor: Display.rearColor !== "" ? "#" + Display.rearColor : "transparent"
            level: Display.rearLevel
            onChosen: level => Display.setRearLevel(level)
        }
    }

    // An icon, a label and Off / Low / Medium / High, in a capsule's height.
    component LevelRow: Item {
        id: levelRow

        property bool shown: false
        property string iconName: ""
        property string title: ""
        // A read-only colour dot after the label; transparent for none.
        property color dotColor: "transparent"
        property int level: 0

        signal chosen(int level)

        width: parent ? parent.width : 0
        height: shown ? Theme.sliderGap + Theme.sliderHeight : 0
        visible: shown

        Icon {
            x: (Theme.sliderIconZone - width) / 2
            y: Theme.sliderGap + (Theme.sliderHeight - height) / 2
            name: levelRow.iconName
            color: Colors.foreground
        }

        Row {
            x: Theme.sliderIconZone
            y: Theme.sliderGap
            height: Theme.sliderHeight
            spacing: Theme.gap

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: levelRow.title
                color: Colors.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
            }

            Rectangle {
                objectName: "colorDot"
                anchors.verticalCenter: parent.verticalCenter
                visible: levelRow.dotColor.a > 0
                width: Theme.colorDotSize
                height: width
                radius: width / 2
                color: levelRow.dotColor
                border.width: 1
                border.color: Qt.alpha(Colors.foreground, 0.2)

                Accessible.role: Accessible.StaticText
                Accessible.name: "Follows the theme colour"
            }
        }

        SegmentedControl {
            x: Theme.displayLabelWidth
            y: Theme.sliderGap + (Theme.sliderHeight - height) / 2
            width: levelRow.width - x
            label: levelRow.title
            trackColor: Colors.surfaceContainerHigh
            model: panel.levelLabels
            currentIndex: levelRow.level
            onSelected: index => levelRow.chosen(index)
        }
    }
}
