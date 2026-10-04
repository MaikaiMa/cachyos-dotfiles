pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../services"

// Home: charge, state, a read-only charge capsule, time, health and capacity,
// and the power profile as a segmented control.
Rectangle {
    id: tile

    radius: Theme.tileRadius
    color: Colors.surfaceContainerHigh

    readonly property var profileLabels: ({
            "power-saver": "Power saver",
            "balanced": "Balanced",
            "performance": "Performance"
        })

    readonly property string stateText: {
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

            Text {
                objectName: "batteryPercentage"
                anchors.verticalCenter: parent.verticalCenter
                text: Battery.available ? Math.round(Battery.percentage) + "%" : "–"
                color: Colors.foreground
                font.family: Theme.fontFamily
                font.pixelSize: Theme.homeLargeFontSize
                font.weight: Font.DemiBold
                font.features: ({
                        tnum: 1
                    })
            }

            Text {
                objectName: "batteryState"
                anchors.verticalCenter: parent.verticalCenter
                text: tile.stateText
                color: Colors.foregroundVariant
                font.family: Theme.fontFamily
                font.pixelSize: Theme.fontSize
                font.weight: Theme.fontWeight
            }
        }

        // The Settings slider language without a handle: the clip is square, the
        // fill inside it is the whole capsule, so the left end stays round.
        Rectangle {
            id: capsule

            width: parent.width
            height: Theme.chargeCapsuleHeight
            radius: height / 2
            color: Colors.surfaceContainer

            Accessible.role: Accessible.ProgressBar
            Accessible.name: "Battery charge"
            Accessible.description: Math.round(Battery.percentage) + "%"

            Item {
                objectName: "chargeFill"
                width: Battery.available ? capsule.width * Math.max(0, Math.min(100, Battery.percentage)) / 100 : 0
                height: capsule.height
                clip: true

                Behavior on width {
                    NumberAnimation {
                        duration: 4 * Motion.crossfadeDuration
                        easing.type: Motion.crossfadeEasing
                    }
                }

                Rectangle {
                    width: capsule.width
                    height: capsule.height
                    radius: capsule.radius
                    color: Battery.isLow ? Colors.error : Colors.primary

                    Behavior on color {
                        ColorAnimation {
                            duration: Motion.crossfadeDuration
                            easing.type: Motion.crossfadeEasing
                        }
                    }
                }
            }
        }

        Item {
            width: parent.width
            height: Theme.powerStatsHeight

            Stat {
                objectName: "timeStat"
                anchors.left: parent.left
                title: Battery.state === "charging" ? "To full" : "Remaining"
                value: !Battery.available || Battery.state === "full" ? "–" : tile.duration(Battery.state === "charging" ? Battery.timeToFull : Battery.timeToEmpty)
            }

            Stat {
                objectName: "healthStat"
                anchors.horizontalCenter: parent.horizontalCenter
                alignment: Text.AlignHCenter
                title: "Health"
                value: Battery.healthPercentage > 0 ? Math.round(Battery.healthPercentage) + "%" : "–"
            }

            Stat {
                objectName: "capacityStat"
                anchors.right: parent.right
                alignment: Text.AlignRight
                title: "Capacity"
                value: Battery.energyCapacity > 0 ? Battery.energyCapacity.toFixed(1) + " Wh" : "–"
            }
        }

        SegmentedControl {
            objectName: "profileTabs"
            width: parent.width
            label: "Power profile"
            model: Battery.profiles.map(name => tile.profileLabels[name])
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

        Text {
            id: titleText

            objectName: "statTitle"
            width: stat.width
            horizontalAlignment: stat.alignment
            text: stat.title
            color: Colors.foregroundVariant
            font.family: Theme.fontFamily
            font.pixelSize: Theme.secondaryFontSize
            font.weight: Theme.fontWeight
        }

        Text {
            id: valueText

            objectName: "statValue"
            width: stat.width
            horizontalAlignment: stat.alignment
            text: stat.value
            color: Colors.foreground
            font.family: Theme.fontFamily
            font.pixelSize: Theme.fontSize
            font.weight: Font.DemiBold
            font.features: ({
                    tnum: 1
                })
        }
    }
}
