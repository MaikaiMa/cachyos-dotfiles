pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Settings state of the centre island: toggle grid, three capsule sliders and,
// when there are any, the notifications. implicitHeight is the settled height the
// island grows to; it drops as soon as a row starts leaving, so the island shrinks
// in one animation while the row collapses inside it.
Item {
    id: panel

    property bool shown: false

    readonly property real cellWidth: (width - 2 * Theme.panelPadding - (Theme.settingsColumns - 1) * Theme.tileGap) / Theme.settingsColumns

    // Rows that are animating out; the service drops them once they are gone.
    property var leavingIds: []
    property bool clearing: false
    readonly property int settledCount: clearing ? 0 : Notifications.items.filter(item => !leavingIds.includes(item.id)).length
    readonly property real settledListHeight: Math.min(Theme.notificationListMaxHeight, settledCount * Theme.notificationRowHeight + Math.max(0, settledCount - 1) * Theme.notificationRowGap)
    readonly property real notificationsHeight: settledCount > 0 ? Theme.notificationHeaderGap + Theme.notificationHeaderHeight + settledListHeight : 0

    implicitWidth: Theme.panelWidths.settings
    implicitHeight: 2 * Theme.panelPadding + Theme.settingsGridHeight + Theme.tileGap + Theme.settingsSlidersHeight + notificationsHeight

    opacity: shown ? 1 : 0
    visible: opacity > 0
    enabled: shown

    Behavior on opacity {
        NumberAnimation {
            duration: Motion.crossfadeDuration
            easing.type: Motion.crossfadeEasing
        }
    }

    function spanWidth(cells: int): real {
        return cells * cellWidth + (cells - 1) * Theme.tileGap;
    }

    function cellX(column: int): real {
        return Theme.panelPadding + column * (cellWidth + Theme.tileGap);
    }

    function nextProfile(): string {
        const profiles = Battery.profiles;
        return profiles[(profiles.indexOf(Battery.profile) + 1) % profiles.length];
    }

    // The settings window needs the keyboard, which the open panel holds.
    function openDmsSettings(tab: string) {
        Dms.openSettingsTab(tab);
        Shell.close();
    }

    function dismiss(id: string) {
        if (!leavingIds.includes(id))
            leavingIds = leavingIds.concat([id]);
    }

    function clearAll() {
        clearing = true;
        clearTimer.restart();
    }

    // The ListView keeps its delegates while items come and go: the model is
    // patched instead of replaced, so a leaving row can finish its animation.
    function syncModel() {
        const items = Notifications.items;
        const ids = items.map(item => item.id);
        for (let index = notificationModel.count - 1; index >= 0; index--) {
            if (!ids.includes(notificationModel.get(index).notificationId))
                notificationModel.remove(index);
        }
        items.forEach((item, index) => {
            const entry = {
                notificationId: item.id,
                appName: item.appName,
                summary: item.summary,
                body: item.body,
                appIcon: item.appIcon,
                image: item.image,
                desktopEntry: item.desktopEntry
            };
            if (index < notificationModel.count && notificationModel.get(index).notificationId === item.id)
                notificationModel.set(index, entry);
            else
                notificationModel.insert(index, entry);
        });
        const kept = leavingIds.filter(id => ids.includes(id));
        if (kept.length !== leavingIds.length)
            leavingIds = kept;
    }

    Connections {
        target: Notifications

        function onItemsChanged() {
            panel.syncModel();
        }
    }

    Component.onCompleted: syncModel()

    ListModel {
        id: notificationModel
    }

    Timer {
        id: clearTimer

        interval: Motion.crossfadeDuration + 20
        onTriggered: {
            Notifications.clearAll();
            panel.clearing = false;
            panel.leavingIds = [];
        }
    }

    // Two rows, no holes: Wi-Fi | Bluetooth, then Power profile | DND | Caffeine.
    // Declared in reading order, which is also the Tab order.
    Item {
        id: grid

        y: Theme.panelPadding
        width: panel.width
        height: Theme.settingsGridHeight

        Tile {
            objectName: "wifiTile"
            x: panel.cellX(0)
            y: 0
            width: panel.spanWidth(2)
            wide: true
            title: "Wi-Fi"
            active: Network.wifiEnabled
            iconName: {
                if (!Network.wifiEnabled)
                    return "wifi_off";
                if (!Network.wifiConnected)
                    return "signal_wifi_0_bar";
                if (Network.strength >= 75)
                    return "signal_wifi_4_bar";
                if (Network.strength >= 50)
                    return "network_wifi_3_bar";
                if (Network.strength >= 25)
                    return "network_wifi_2_bar";
                return "network_wifi_1_bar";
            }
            stateText: !Network.wifiEnabled ? "Off" : !Network.wifiConnected ? "Disconnected" : Network.weak ? "Weak · " + Network.ssid : Network.ssid
            onActivated: Network.toggleWifi()
            onSecondaryAction: panel.openDmsSettings("network_wifi")
        }

        Tile {
            objectName: "bluetoothTile"
            x: panel.cellX(2)
            y: 0
            width: panel.spanWidth(2)
            wide: true
            title: "Bluetooth"
            active: Bluetooth.btEnabled
            iconName: !Bluetooth.btEnabled ? "bluetooth_disabled" : Bluetooth.connectedDevices > 0 ? "bluetooth_connected" : "bluetooth"
            stateText: {
                if (!Bluetooth.available)
                    return "Unavailable";
                if (!Bluetooth.btEnabled)
                    return "Off";
                const devices = Bluetooth.connectedDevices;
                return devices === 0 ? "On" : devices === 1 ? "1 device" : devices + " devices";
            }
            onActivated: Bluetooth.toggleBluetooth()
            // DMS 1.6 has no Bluetooth settings tab; devices live in its control center.
            onSecondaryAction: panel.openDmsSettings("network")
        }

        Tile {
            objectName: "profileTile"
            x: panel.cellX(0)
            y: Theme.settingsTileHeight + Theme.tileGap
            width: panel.spanWidth(2)
            wide: true
            title: "Power profile"
            active: Battery.profile !== "balanced"
            iconName: Battery.profile === "power-saver" ? "battery_saver" : Battery.profile === "performance" ? "bolt" : "balance"
            stateText: Battery.profile === "power-saver" ? "Power saver" : Battery.profile === "performance" ? "Performance" : "Balanced"
            onActivated: Battery.setProfile(panel.nextProfile())
        }

        Tile {
            objectName: "dndTile"
            x: panel.cellX(2)
            y: Theme.settingsTileHeight + Theme.tileGap
            width: panel.spanWidth(1)
            title: "Do not disturb"
            active: Dms.doNotDisturb
            iconName: "do_not_disturb_on"
            onActivated: Dms.toggleDoNotDisturb()
        }

        Tile {
            objectName: "caffeineTile"
            x: panel.cellX(3)
            y: Theme.settingsTileHeight + Theme.tileGap
            width: panel.spanWidth(1)
            title: "Caffeine"
            active: Dms.caffeine
            iconName: "coffee"
            onActivated: Dms.toggleCaffeine()
        }
    }

    Column {
        id: sliders

        x: Theme.panelPadding
        y: grid.y + grid.height + Theme.tileGap
        width: panel.width - 2 * Theme.panelPadding
        spacing: Theme.sliderGap

        CapsuleSlider {
            objectName: "volumeSlider"
            width: parent.width
            label: "Volume"
            available: Audio.ready
            value: Audio.volume * 100
            muted: Audio.muted
            iconName: Audio.muted ? "volume_off" : "volume_up"
            onMoved: target => Audio.setVolume(target / 100)
            onIconClicked: Audio.toggleMute()
        }

        CapsuleSlider {
            objectName: "micSlider"
            width: parent.width
            label: "Microphone"
            available: Audio.source !== null
            value: Audio.micVolume * 100
            muted: Audio.micMuted
            iconName: Audio.micMuted ? "mic_off" : "mic"
            onMoved: target => Audio.setMicVolume(target / 100)
            onIconClicked: Audio.toggleMicMute()
        }

        CapsuleSlider {
            objectName: "brightnessSlider"
            width: parent.width
            label: "Brightness"
            available: Brightness.available
            minimum: 1
            value: Math.max(0, Brightness.percentage)
            iconName: "light_mode"
            onMoved: target => Brightness.set(target)
            onIconClicked: Brightness.cycle()
        }
    }

    Item {
        id: notifications

        objectName: "notifications"
        y: sliders.y + sliders.height
        width: panel.width
        height: Theme.notificationHeaderGap + Theme.notificationHeaderHeight + list.height
        visible: notificationModel.count > 0

        Item {
            id: header

            x: Theme.panelPadding
            y: Theme.notificationHeaderGap
            width: parent.width - 2 * Theme.panelPadding
            height: Theme.notificationHeaderHeight
            opacity: panel.settledCount > 0 ? 1 : 0

            Behavior on opacity {
                NumberAnimation {
                    duration: Motion.crossfadeDuration
                    easing.type: Motion.crossfadeEasing
                }
            }

            Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: "notifications"
                    size: 14
                    color: Colors.foregroundVariant
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "Notifications · " + panel.settledCount
                    color: Colors.foregroundVariant
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.secondaryFontSize
                    font.weight: Theme.fontWeight
                    font.features: ({
                            tnum: 1
                        })
                }
            }

            Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: clearLabel.implicitWidth + 16
                height: clearLabel.implicitHeight + 8
                radius: 10
                color: clearPointer.containsMouse ? Qt.alpha(Colors.foreground, 0.07) : "transparent"

                Behavior on color {
                    ColorAnimation {
                        duration: Motion.crossfadeDuration
                    }
                }

                Text {
                    id: clearLabel

                    anchors.centerIn: parent
                    text: "Clear all"
                    color: Colors.primary
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.secondaryFontSize
                    font.weight: Theme.fontWeight
                }

                MouseArea {
                    id: clearPointer

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    enabled: !panel.clearing
                    onClicked: panel.clearAll()
                }

                Accessible.role: Accessible.Button
                Accessible.name: "Clear all notifications"
            }
        }

        ListView {
            id: list

            x: Theme.panelPadding
            y: header.y + header.height
            width: parent.width - 2 * Theme.panelPadding
            height: Math.min(Theme.notificationListMaxHeight, contentHeight)
            clip: true
            spacing: Theme.notificationRowGap
            boundsBehavior: Flickable.StopAtBounds
            model: notificationModel

            delegate: NotificationRow {
                required property string notificationId

                width: ListView.view.width
                leaving: panel.clearing || panel.leavingIds.includes(notificationId)
                onDismissClicked: panel.dismiss(notificationId)
                // Clear all hands the whole list to the service at once.
                onGone: {
                    if (!panel.clearing)
                        Notifications.dismiss(notificationId);
                }
            }

            // A thin scroll hint while the list is longer than its window.
            Rectangle {
                visible: list.contentHeight > list.height
                x: list.width - width
                y: list.visibleArea.yPosition * list.height
                width: 4
                height: list.visibleArea.heightRatio * list.height
                radius: width / 2
                color: Qt.alpha(Colors.foreground, 0.25)
            }
        }
    }
}
