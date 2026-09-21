import QtQuick
import Quickshell.Services.UPower
import qs.Common
import qs.Services
import qs.Widgets

DashboardCard {
    id: power

    readonly property int batteryPercent: Math.round(BatteryService.batteryLevel)
    readonly property bool lowBattery: BatteryService.isLowBattery

    title: I18n.trFor("dotfilesDashboard", "Power")
    spacing: Theme.spacingS

    Item {
        width: parent.width
        height: 20
        visible: BatteryService.batteryAvailable

        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Theme.spacingS

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: BatteryService.getBatteryIcon()
                size: Theme.iconSizeSmall + 2
                color: power.lowBattery ? Theme.error : Theme.primary
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: power.batteryPercent + "%"
                font.pixelSize: Theme.fontSizeMedium
                font.weight: Font.Bold
                color: Theme.surfaceText
            }

            StyledText {
                anchors.verticalCenter: parent.verticalCenter
                text: BatteryService.batteryStatus
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.surfaceVariantText
            }
        }

        StyledText {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            text: BatteryService.formatTimeRemaining()
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.surfaceVariantText
        }
    }

    Rectangle {
        width: parent.width
        height: 6
        radius: height / 2
        color: Theme.withAlpha(Theme.ccSliderTrackColor, Theme.ccSliderTrackOpacity)
        visible: BatteryService.batteryAvailable

        Rectangle {
            width: Math.max(0, Math.min(1, power.batteryPercent / 100)) * parent.width
            height: parent.height
            radius: parent.radius
            color: power.lowBattery ? Theme.error : Theme.primary

            Behavior on width {
                NumberAnimation {
                    duration: Theme.shortDuration
                    easing.type: Theme.standardEasing
                }
            }
        }
    }

    Row {
        id: profiles

        width: parent.width
        spacing: Theme.spacingS
        visible: PowerProfileWatcher.available
        topPadding: Theme.spacingXS

        readonly property real buttonWidth: (width - spacing * 2) / 3

        Repeater {
            model: [
                {
                    "profile": PowerProfile.PowerSaver,
                    "label": I18n.trFor("dotfilesDashboard", "Power Saver"),
                    "icon": "eco"
                },
                {
                    "profile": PowerProfile.Balanced,
                    "label": I18n.trFor("dotfilesDashboard", "Balanced"),
                    "icon": "balance"
                },
                {
                    "profile": PowerProfile.Performance,
                    "label": I18n.trFor("dotfilesDashboard", "Performance"),
                    "icon": "speed"
                }
            ]

            Rectangle {
                id: profileButton

                required property var modelData

                readonly property bool isActive: PowerProfileWatcher.currentProfile === modelData.profile
                readonly property bool isAvailable: PowerProfileWatcher.availableProfiles.indexOf(modelData.profile) !== -1

                width: profiles.buttonWidth
                height: 36
                radius: Theme.cornerRadius
                enabled: isAvailable
                opacity: isAvailable ? 1 : 0.4
                color: {
                    if (isActive)
                        return Theme.ccTileActiveBg;
                    return profileArea.containsMouse ? Theme.ccPillInactiveHoverBg : Theme.ccPillInactiveBg;
                }
                border.color: isActive ? Theme.ccTileRing : Theme.outlineMedium
                border.width: isActive ? 1 : Theme.layerOutlineWidth

                Row {
                    anchors.centerIn: parent
                    spacing: Theme.spacingXS

                    DankIcon {
                        anchors.verticalCenter: parent.verticalCenter
                        name: profileButton.modelData.icon
                        size: Theme.iconSizeSmall
                        color: profileButton.isActive ? Theme.ccTileActiveText : Theme.surfaceText
                    }

                    StyledText {
                        anchors.verticalCenter: parent.verticalCenter
                        text: profileButton.modelData.label
                        font.pixelSize: Theme.fontSizeMedium
                        color: profileButton.isActive ? Theme.ccTileActiveText : Theme.surfaceText
                    }
                }

                DankRipple {
                    id: profileRipple

                    cornerRadius: profileButton.radius
                }

                MouseArea {
                    id: profileArea

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onPressed: mouse => profileRipple.trigger(mouse.x, mouse.y)
                    onClicked: PowerProfileWatcher.applyProfile(profileButton.modelData.profile)
                }
            }
        }
    }
}
