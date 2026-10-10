pragma ComponentBehavior: Bound

import QtQuick
import qs
import qs.services
import qs.components

// Home: charge, state, a read-only charge capsule, time, health and capacity,
// and the power profile as a segmented control.
Surface {
    id: tile

    readonly property string subtitle: {
        if (!Battery.available)
            return "No battery";
        switch (Battery.state) {
        case "charging":
            return "Charging";
        case "discharging":
            return "Discharging";
        case "full":
            return "Fully charged";
        default:
            return "";
        }
    }

    // "4 h 10 min", "35 min"; "–" without an estimate.
    function duration(seconds: real): string {
        if (!(seconds > 0))
            return "–";
        const minutes = Math.round(seconds / 60);
        const hours = Math.floor(minutes / 60);
        const rest = minutes % 60;
        return hours > 0 ? hours + " h " + (rest < 10 ? "0" : "") + rest + " min" : rest + " min";
    }

    Column {
        x: Theme.homeTilePadding
        y: Theme.homeTilePadding
        width: parent.width - 2 * Theme.homeTilePadding
        spacing: Theme.homeSectionGap

        Row {
            height: Theme.powerHeadHeight
            spacing: Theme.gap

            BatteryIcon {
                anchors.verticalCenter: parent.verticalCenter
                size: Theme.powerIconSize
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.available ? Math.round(Battery.percentage) + "%" : "–"
                strong: true
                numeric: true
                font.pixelSize: Theme.homeLargeFontSize
            }

            Label {
                anchors.verticalCenter: parent.verticalCenter
                text: tile.subtitle
                color: Colors.foregroundVariant
            }
        }

        // The Settings slider language without a handle.
        FillTrack {
            width: parent.width
            height: Theme.chargeCapsuleHeight
            capsuleClip: true
            value: Battery.available ? Battery.percentage / 100 : 0
            fillColor: Battery.isLow ? Colors.error : Colors.primary

            Behavior on fillColor {
                ColorCrossfade {}
            }

            Accessible.role: Accessible.ProgressBar
            Accessible.name: "Battery charge"
            Accessible.description: Math.round(Battery.percentage) + "%"
        }

        Item {
            width: parent.width
            height: Theme.powerStatsHeight

            Stat {
                anchors.left: parent.left
                title: Battery.state === "charging" ? "To full" : "Remaining"
                value: !Battery.available || Battery.state === "full" ? "–" : tile.duration(Battery.state === "charging" ? Battery.timeToFull : Battery.timeToEmpty)
            }

            Stat {
                anchors.horizontalCenter: parent.horizontalCenter
                alignment: Text.AlignHCenter
                title: "Health"
                value: Battery.healthPercentage > 0 ? Math.round(Battery.healthPercentage) + "%" : "–"
            }

            Stat {
                anchors.right: parent.right
                alignment: Text.AlignRight
                title: "Capacity"
                value: Battery.energyCapacity > 0 ? Battery.energyCapacity.toFixed(1) + " Wh" : "–"
            }
        }

        SegmentedControl {
            width: parent.width
            accessibleName: "Power profile"
            model: Battery.profiles.map(name => Battery.profileLabel(name))
            currentIndex: Battery.profiles.indexOf(Battery.profile)
            onSelected: index => Battery.setProfile(Battery.profiles[index])
        }
    }

    component Stat: Column {
        id: stat

        property string title: ""
        property string value: ""
        property int alignment: Text.AlignLeft

        width: Math.max(titleText.implicitWidth, valueText.implicitWidth)

        Accessible.role: Accessible.StaticText
        Accessible.name: title + " " + value

        Label {
            id: titleText

            width: stat.width
            horizontalAlignment: stat.alignment
            text: stat.title
            secondary: true
        }

        Label {
            id: valueText

            width: stat.width
            horizontalAlignment: stat.alignment
            text: stat.value
            strong: true
            numeric: true
        }
    }
}
