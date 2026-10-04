pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Home: CPU load, CPU temperature and memory as three thin vertical bars. System
// only samples while Home is open; Shell sets System.active from the state.
Rectangle {
    id: tile

    radius: Theme.tileRadius
    color: Colors.surfaceContainerHigh

    readonly property real columnWidth: (width - 2 * Theme.homeTilePadding) / 3

    readonly property real meterHeight: height - 2 * Theme.homeTilePadding

    Row {
        x: Theme.homeTilePadding
        y: Theme.homeTilePadding

        Meter {
            objectName: "cpuMeter"
            width: tile.columnWidth
            height: tile.meterHeight
            label: Math.round(System.cpu * 100) + "%"
            level: System.cpu
            iconName: "memory"
            description: "CPU load"
        }

        Meter {
            objectName: "tempMeter"
            width: tile.columnWidth
            height: tile.meterHeight
            label: isNaN(System.temp) ? "–" : Math.round(System.temp) + "°"
            level: isNaN(System.temp) ? 0 : (System.temp - Theme.tempScaleMin) / (Theme.tempScaleMax - Theme.tempScaleMin)
            iconName: "device_thermostat"
            description: "CPU temperature"
        }

        Meter {
            objectName: "memoryMeter"
            width: tile.columnWidth
            height: tile.meterHeight
            label: Math.round(System.memory * 100) + "%"
            level: System.memory
            iconName: "memory_alt"
            description: "Memory"
        }
    }

    component Meter: Column {
        id: meter

        property string label: ""
        property real level: 0
        property string iconName: ""
        property string description: ""

        spacing: 6

        Accessible.role: Accessible.ProgressBar
        Accessible.name: description
        Accessible.description: label

        Text {
            id: value

            objectName: "meterLabel"
            anchors.horizontalCenter: parent.horizontalCenter
            text: meter.label
            color: Colors.foregroundVariant
            font.family: Theme.fontFamily
            font.pixelSize: Theme.secondaryFontSize
            font.weight: Theme.fontWeight
            font.features: ({
                    tnum: 1
                })
        }

        Rectangle {
            id: track

            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.meterWidth
            height: meter.height - value.height - Theme.iconSize - 2 * meter.spacing
            radius: width / 2
            color: Colors.surfaceContainer

            Rectangle {
                objectName: "meterFill"
                anchors.bottom: parent.bottom
                width: parent.width
                height: parent.height * Math.max(0, Math.min(1, meter.level))
                radius: width / 2
                color: Colors.primary

                Behavior on height {
                    NumberAnimation {
                        duration: 4 * Motion.crossfadeDuration
                        easing.type: Motion.crossfadeEasing
                    }
                }
            }
        }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: meter.iconName
            color: Colors.foregroundVariant
        }
    }
}
