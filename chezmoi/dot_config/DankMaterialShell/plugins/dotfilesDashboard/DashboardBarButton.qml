import QtQuick
import qs.Common
import qs.Services
import qs.Widgets

Item {
    id: button

    property int iconSize: Theme.iconSize
    property int textSize: Theme.fontSizeSmall
    property bool vertical: false

    readonly property bool showNetwork: SettingsData.controlCenterShowNetworkIcon && NetworkService.networkAvailable
    readonly property bool showBluetooth: SettingsData.controlCenterShowBluetoothIcon && BluetoothService.available && BluetoothService.enabled
    readonly property bool showAudio: SettingsData.controlCenterShowAudioIcon
    readonly property bool showAudioPercent: SettingsData.controlCenterShowAudioPercent && isFinite(AudioService.sink?.audio?.volume)
    readonly property bool hasIndicators: showNetwork || showBluetooth || showAudio

    function networkIconName() {
        if (NetworkService.wifiToggling)
            return "sync";
        switch (NetworkService.networkStatus) {
        case "ethernet":
            return "lan";
        case "cellular":
            return "network_cell";
        default:
            return NetworkService.wifiSignalIcon;
        }
    }

    function networkIconColor() {
        if (NetworkService.wifiToggling || (NetworkService.isConnecting && !NetworkService.ethernetConnected))
            return Theme.primary;
        return NetworkService.networkStatus !== "disconnected" ? Theme.primary : Theme.surfaceText;
    }

    implicitWidth: vertical ? iconSize : indicators.implicitWidth
    implicitHeight: vertical ? indicators.implicitHeight : iconSize

    Grid {
        id: indicators

        anchors.centerIn: parent
        columns: button.vertical ? 1 : 4
        spacing: Theme.spacingXS
        horizontalItemAlignment: Grid.AlignHCenter
        verticalItemAlignment: Grid.AlignVCenter

        DankIcon {
            name: button.networkIconName()
            size: button.iconSize
            color: button.networkIconColor()
            visible: button.showNetwork
        }

        DankIcon {
            name: BluetoothService.connected ? "bluetooth_connected" : "bluetooth"
            size: button.iconSize
            color: BluetoothService.connected || BluetoothService.connecting ? Theme.primary : Theme.surfaceText
            visible: button.showBluetooth
        }

        Row {
            spacing: Theme.spacingXXS
            visible: button.showAudio

            DankIcon {
                anchors.verticalCenter: parent.verticalCenter
                name: AudioService.sinkVolumeIconName
                size: button.iconSize
                color: AudioService.sinkSilent ? Theme.widgetInactiveIconColor : Theme.widgetIconColor
            }

            NumericText {
                anchors.verticalCenter: parent.verticalCenter
                visible: button.showAudioPercent && !button.vertical
                text: Math.round((AudioService.sink?.audio?.volume ?? 0) * 100) + "%"
                reserveText: "100%"
                font.pixelSize: button.textSize
                color: Theme.widgetTextColor
                width: visible ? implicitWidth : 0
            }
        }

        DankIcon {
            name: "dashboard"
            size: button.iconSize
            color: Theme.widgetIconColor
            visible: !button.hasIndicators
        }
    }
}
