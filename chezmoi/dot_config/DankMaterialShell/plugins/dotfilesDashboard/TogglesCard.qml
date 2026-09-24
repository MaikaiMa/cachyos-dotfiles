import QtQuick
import Quickshell
import Quickshell.Io
import qs.Common
import qs.Services

Row {
    id: toggles

    property var dashboard: null
    property bool popoutVisible: false
    property bool rotationLocked: false

    readonly property real tileWidth: (width - spacing * (children.length - 1)) / children.length
    readonly property string autoRotateCommand: Quickshell.env("HOME") + "/.local/bin/auto-rotate"

    function runRotationLock(action) {
        rotationLockProcess.command = [toggles.autoRotateCommand, "lock", action];
        rotationLockProcess.running = true;
    }

    // The lock can also change from a terminal, so it is re-read on every open.
    onPopoutVisibleChanged: {
        if (popoutVisible)
            runRotationLock("status");
    }
    Component.onCompleted: runRotationLock("status")

    spacing: Theme.spacingS

    ToggleTile {
        width: toggles.tileWidth
        iconName: "wallpaper"
        label: I18n.trFor("dotfilesDashboard", "Wallpaper")
        imagePath: SessionData.wallpaperPath.startsWith("#") ? "" : SessionData.wallpaperPath
        onClicked: toggles.dashboard?.openDashTab("wallpaper")
    }

    ToggleTile {
        width: toggles.tileWidth
        iconName: toggles.rotationLocked ? "screen_lock_rotation" : "screen_rotation"
        label: I18n.trFor("dotfilesDashboard", "Rotation lock")
        isActive: toggles.rotationLocked
        onClicked: toggles.runRotationLock("toggle")
    }

    ToggleTile {
        width: toggles.tileWidth
        iconName: NetworkService.wifiEnabled ? "wifi" : "wifi_off"
        label: I18n.trFor("dotfilesDashboard", "Wifi")
        isActive: NetworkService.wifiEnabled
        enabled: NetworkService.wifiAvailable
        onClicked: NetworkService.toggleWifiRadio()
    }

    ToggleTile {
        width: toggles.tileWidth
        iconName: BluetoothService.enabled ? "bluetooth" : "bluetooth_disabled"
        label: I18n.trFor("dotfilesDashboard", "Bluetooth")
        isActive: BluetoothService.enabled
        enabled: BluetoothService.available
        onClicked: BluetoothService.toggleBluetooth()
    }

    ToggleTile {
        width: toggles.tileWidth
        iconName: "local_cafe"
        label: I18n.trFor("dotfilesDashboard", "Caffeine")
        isActive: SessionService.idleInhibited
        onClicked: SessionService.toggleIdleInhibit()
    }

    ToggleTile {
        width: toggles.tileWidth
        iconName: SessionData.doNotDisturb ? "notifications_off" : "notifications"
        label: I18n.trFor("dotfilesDashboard", "Do not disturb")
        isActive: SessionData.doNotDisturb
        onClicked: SessionData.setDoNotDisturb(!SessionData.doNotDisturb)
    }

    Process {
        id: rotationLockProcess

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => toggles.rotationLocked = data.trim() === "locked"
        }
    }
}
