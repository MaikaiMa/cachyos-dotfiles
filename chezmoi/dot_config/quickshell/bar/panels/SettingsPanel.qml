pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Settings state of the centre island: toggle grid, three capsule sliders and,
// when there are any, the notifications. implicitHeight is the settled height the
// island grows to, with the list's settled height.
Panel {
    id: panel

    name: "settings"

    readonly property real cellWidth: (contentWidth - (Theme.settingsColumns - 1) * Theme.tileGap) / Theme.settingsColumns

    implicitHeight: 2 * Theme.panelPadding + Theme.settingsGridHeight + Theme.tileGap + Theme.settingsSlidersHeight + notifications.settledHeight

    // The notifications indicator opens Settings for the list: newest first, on top.
    // The rotation lock can change from a terminal, so it is read again too.
    onOpened: {
        notifications.positionAtBeginning();
        Tablet.refresh();
    }
    onClosed: notifications.reset()

    function spanWidth(cells: int): real {
        return cells * cellWidth + (cells - 1) * Theme.tileGap;
    }

    function cellX(column: int): real {
        return Theme.panelPadding + column * (cellWidth + Theme.tileGap);
    }

    // Two rows, no holes. Docked: Wi-Fi | DND | Caffeine, then Bluetooth | Power
    // profile. Detached, Bluetooth shrinks to one cell and the rotation lock takes
    // the other. Declared in reading order, which is also the Tab order.
    Item {
        id: grid

        readonly property real secondRow: Theme.settingsTileHeight + Theme.tileGap

        y: Theme.panelPadding
        width: panel.width
        height: Theme.settingsGridHeight

        GridTile {
            objectName: "wifiTile"
            x: panel.cellX(0)
            y: 0
            width: panel.spanWidth(2)
            wide: true
            title: "Wi-Fi"
            active: Network.wifiEnabled
            iconName: Network.statusIcon
            subtitle: !Network.wifiEnabled ? "Off" : !Network.wifiConnected ? "Disconnected" : Network.weak ? "Weak · " + Network.ssid : Network.ssid
            hasPanel: true
            onActivated: Network.toggleWifi()
            onPanelRequested: Shell.open("wifi", Shell.screenName)
        }

        GridTile {
            objectName: "dndTile"
            x: panel.cellX(2)
            y: 0
            width: panel.spanWidth(1)
            title: "Do not disturb"
            active: Notifications.doNotDisturb
            iconName: "do_not_disturb_on"
            onActivated: Notifications.toggleDoNotDisturb()
        }

        GridTile {
            objectName: "caffeineTile"
            x: panel.cellX(3)
            y: 0
            width: panel.spanWidth(1)
            title: "Caffeine"
            active: Dms.caffeine
            iconName: "coffee"
            onActivated: Dms.toggleCaffeine()
        }

        GridTile {
            objectName: "bluetoothTile"
            x: panel.cellX(0)
            y: grid.secondRow
            width: panel.spanWidth(Tablet.detached ? 1 : 2)
            wide: !Tablet.detached
            title: "Bluetooth"
            active: Bluetooth.bluetoothEnabled
            iconName: !Bluetooth.bluetoothEnabled ? "bluetooth_disabled" : Bluetooth.connectedDevices > 0 ? "bluetooth_connected" : "bluetooth"
            subtitle: {
                if (!Bluetooth.available)
                    return "Unavailable";
                if (!Bluetooth.bluetoothEnabled)
                    return "Off";
                const devices = Bluetooth.connectedDevices;
                return devices === 0 ? "On" : devices === 1 ? "1 device" : devices + " devices";
            }
            hasPanel: true
            onActivated: Bluetooth.toggleBluetooth()
            onPanelRequested: Shell.open("bluetooth", Shell.screenName)
        }

        // Grows out of the cell Bluetooth frees; Tab skips it while docked.
        GridTile {
            objectName: "rotationTile"
            x: panel.cellX(1)
            y: grid.secondRow
            width: panel.spanWidth(1)
            title: "Rotation lock"
            active: Tablet.rotationLocked
            iconName: Tablet.rotationLocked ? "screen_lock_rotation" : "screen_rotation"
            enabled: Tablet.detached
            opacity: Tablet.detached ? 1 : 0
            scale: Tablet.detached ? 1 : 0.85
            visible: opacity > 0
            onActivated: Tablet.toggleRotationLock()

            Behavior on opacity {
                MorphAnimation {}
            }
            Behavior on scale {
                MorphAnimation {}
            }
        }

        GridTile {
            objectName: "profileTile"
            x: panel.cellX(2)
            y: grid.secondRow
            width: panel.spanWidth(2)
            wide: true
            title: "Power profile"
            active: Battery.profile !== "balanced"
            iconName: Battery.profileIcon(Battery.profile)
            subtitle: Battery.profileLabel(Battery.profile)
            onActivated: Battery.cycleProfile()
        }
    }

    // The tiles move with the island's grow curve when the grid changes layout.
    component GridTile: Tile {
        Behavior on x {
            MorphAnimation {}
        }
        Behavior on width {
            MorphAnimation {}
        }
    }

    Column {
        id: sliders

        x: panel.contentX
        y: grid.y + grid.height + Theme.tileGap
        width: panel.contentWidth
        spacing: Theme.sliderGap

        CapsuleSlider {
            objectName: "volumeSlider"
            width: parent.width
            accessibleName: "Volume"
            available: Audio.ready
            value: Audio.volume * 100
            muted: Audio.muted
            iconName: Audio.muted ? "volume_off" : "volume_up"
            onMoved: target => Audio.setVolume(target / 100)
            onIconClicked: Audio.toggleMute()
            hasPanel: true
            onPanelRequested: Shell.open("sound", Shell.screenName)
        }

        CapsuleSlider {
            objectName: "micSlider"
            width: parent.width
            accessibleName: "Microphone"
            available: Audio.source !== null
            value: Audio.micVolume * 100
            muted: Audio.micMuted
            iconName: Audio.micMuted ? "mic_off" : "mic"
            onMoved: target => Audio.setMicVolume(target / 100)
            onIconClicked: Audio.toggleMicMute()
            hasPanel: true
            onPanelRequested: Shell.open("sound", Shell.screenName)
        }

        CapsuleSlider {
            objectName: "brightnessSlider"
            width: parent.width
            accessibleName: "Brightness"
            available: Brightness.available
            minimum: 1
            value: Math.max(0, Brightness.percentage)
            iconName: "light_mode"
            onMoved: target => Brightness.setPercentage(target)
            onIconClicked: Brightness.cycle()
            hasPanel: true
            onPanelRequested: Shell.open("display", Shell.screenName)
        }
    }

    NotificationList {
        id: notifications

        objectName: "notifications"
        y: sliders.y + sliders.height
        width: panel.width
    }
}
