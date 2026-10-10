pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Display state of the centre island, opened from the Brightness capsule:
// the night-light switch in the control row, then the night temperature with
// a read-only schedule line, brightness, the keyboard backlight (only while
// the cover is attached) and the rear window light with the theme colour it
// follows. Values live in `Display` and `Brightness`; both read themselves
// while the panel is open.
Panel {
    id: panel

    name: "display"

    readonly property bool keyboardShown: Display.keyboardAvailable && !Tablet.detached
    readonly property bool rearShown: Display.rearAvailable
    readonly property var levelLabels: ["Off", "Low", "Medium", "High"]

    implicitHeight: rows.y + rows.implicitHeight + Theme.panelPadding

    PanelControlRow {
        id: controls

        x: panel.contentX
        y: Theme.panelPadding
        width: panel.contentWidth
        switchName: "Night light"
        checked: Display.nightLight
        stateText: Display.nightLight ? "On" + (Display.nightTemperature > 0 ? " · " + Display.nightTemperature + " K" : "") : "Off"
        actionLabel: "Open night light settings"
        // The schedule can only be changed there.
        settingsTab: "display_gamma"
        onToggled: Display.toggleNightLight()
    }

    // A hidden row takes no room: the Column skips it with its gap.
    Column {
        id: rows

        x: panel.contentX
        y: controls.y + controls.height + Theme.gap
        width: panel.contentWidth
        spacing: Theme.sliderGap

        // The schedule line sits right under the slider it describes.
        Column {
            width: parent.width

            CapsuleSlider {
                id: nightSlider

                objectName: "nightSlider"
                width: parent.width
                label: "Night light temperature"
                available: Display.nightTemperature > 0
                muted: !Display.nightLight
                value: Display.nightFraction(Display.nightTemperature)
                snap: 100 * Display.nightStep / (Display.nightMaximum - Display.nightMinimum)
                stepSize: snap
                valueText: Display.nightKelvin(nightSlider.shownValue) + " K"
                iconName: "nightlight"
                onMoved: target => Display.setNightTemperature(Display.nightKelvin(target))
                onIconClicked: Display.toggleNightLight()
            }

            Label {
                objectName: "scheduleLine"
                width: parent.width
                height: Theme.scheduleLineHeight
                leftPadding: Theme.sliderIconZone
                verticalAlignment: Text.AlignVCenter
                text: Display.scheduleText
                secondary: true
            }
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
            dotColor: Display.rearTint
            level: Display.rearLevel
            onChosen: level => Display.setRearLevel(level)
        }
    }

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
        height: Theme.sliderHeight
        visible: shown

        Icon {
            x: (Theme.sliderIconZone - width) / 2
            y: (Theme.sliderHeight - height) / 2
            name: levelRow.iconName
            color: Colors.foreground
        }

        Row {
            x: Theme.sliderIconZone
            height: Theme.sliderHeight
            spacing: Theme.gap

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: levelRow.title
            }

            Rectangle {
                objectName: "colorDot"
                anchors.verticalCenter: parent.verticalCenter
                visible: levelRow.dotColor.a > 0
                width: Theme.colorDotSize
                height: width
                radius: width / 2
                color: levelRow.dotColor
                border.width: Theme.hairlineWidth
                border.color: Colors.dotOutline

                Accessible.role: Accessible.StaticText
                Accessible.name: "Follows the theme colour"
            }
        }

        SegmentedControl {
            x: Theme.displayLabelWidth
            y: (Theme.sliderHeight - height) / 2
            width: levelRow.width - x
            label: levelRow.title
            trackColor: Colors.surfaceContainerHigh
            model: panel.levelLabels
            currentIndex: levelRow.level
            onSelected: index => levelRow.chosen(index)
        }
    }
}
