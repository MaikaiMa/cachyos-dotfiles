import QtQuick
import qs.Common
import qs.Services

Row {
    id: toggles

    property var dashboard: null

    readonly property real tileWidth: (width - spacing * 4) / 5

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
}
