pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.components

// Home: CPU load, CPU temperature and memory as three thin vertical bars. System
// only samples while Home is open; Shell sets System.active from the state.
Surface {
    id: tile

    readonly property real columnWidth: (width - 2 * Theme.homeTilePadding) / 3

    readonly property real meterHeight: height - 2 * Theme.homeTilePadding

    Row {
        x: Theme.homeTilePadding
        y: Theme.homeTilePadding

        Meter {
            width: tile.columnWidth
            height: tile.meterHeight
            text: Math.round(System.cpu * 100) + "%"
            level: System.cpu
            iconName: "memory"
            accessibleName: "CPU load"
        }

        Meter {
            width: tile.columnWidth
            height: tile.meterHeight
            text: isNaN(System.temperature) ? "–" : Math.round(System.temperature) + "°"
            level: System.temperatureLevel
            iconName: "device_thermostat"
            accessibleName: "CPU temperature"
        }

        Meter {
            width: tile.columnWidth
            height: tile.meterHeight
            text: Math.round(System.memory * 100) + "%"
            level: System.memory
            iconName: "memory_alt"
            accessibleName: "Memory"
        }
    }

    component Meter: Column {
        id: meter

        property string text: ""
        property real level: 0
        property string iconName: ""
        property string accessibleName: ""

        spacing: Theme.meterGap

        Accessible.role: Accessible.ProgressBar
        Accessible.name: accessibleName
        Accessible.description: text

        Label {
            id: valueLabel

            anchors.horizontalCenter: parent.horizontalCenter
            text: meter.text
            secondary: true
            numeric: true
        }

        FillTrack {
            anchors.horizontalCenter: parent.horizontalCenter
            width: Theme.meterWidth
            height: meter.height - valueLabel.height - Theme.iconSize - 2 * meter.spacing
            vertical: true
            value: meter.level
        }

        Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: meter.iconName
            color: Colors.foregroundVariant
        }
    }
}
