pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"
import "../components/RowActions.js" as RowActions

// The Bluetooth state of the centre island, opened from the Settings tile;
// what a click does is in docs/shell.md, "Wi-Fi and Bluetooth panels".
// Discovery, the attempts and the errors live in `Bluetooth`; the list
// holds which row is expanded.
Panel {
    id: panel

    name: "bluetooth"

    readonly property var devices: Bluetooth.devices
    readonly property var keys: devices.map(device => device.address)

    implicitHeight: 2 * Theme.panelPadding + Theme.controlRowHeight + (Bluetooth.powered ? Theme.gap + list.implicitHeight : 0)

    // Errors stay until the next attempt; only the expansion resets.
    onOpened: {
        list.collapse();
        list.positionAtBeginning();
    }
    onClosed: list.collapse()

    function activate(device: var) {
        if (device.connected || !device.paired) {
            list.toggle(device.address, "");
        } else {
            list.collapse();
            Bluetooth.startConnect(device);
        }
    }

    // Paired devices get Connect and Forget; the rest behave like a click.
    function activateSecondary(device: var) {
        if (device.paired && !device.connected)
            list.toggle(device.address, "");
        else
            activate(device);
    }

    function actionsFor(device: var): var {
        if (device.connected)
            return RowActions.connected();
        if (device.paired)
            return RowActions.saved();
        return RowActions.discovered();
    }

    function act(device: var, action: string) {
        list.collapse();
        if (action === "connect")
            Bluetooth.startConnect(device);
        else if (action === "pair")
            Bluetooth.startPair(device);
        else if (action === "disconnect")
            Bluetooth.disconnectDevice(device);
        else if (action === "forget")
            Bluetooth.forget(device);
    }

    PanelControlRow {
        id: controls

        x: panel.contentX
        y: Theme.panelPadding
        width: panel.contentWidth
        switchName: "Bluetooth"
        checked: Bluetooth.bluetoothEnabled
        switchEnabled: Bluetooth.available
        text: {
            if (!Bluetooth.available)
                return "Unavailable";
            if (!Bluetooth.bluetoothEnabled)
                return "Off";
            if (Bluetooth.scanning)
                return "Scanning…";
            return Bluetooth.connectedDevices > 0 ? "On · " + Bluetooth.connectedDevices + " connected" : "On";
        }
        // DMS 1.6.2 settings have no Bluetooth page (its control center, which
        // has one, cannot open while the own bar runs): the settings button
        // goes to the Network tab, the terminal button to bluetoothctl, which
        // also pairs devices that want a PIN or passkey.
        extraIcon: "terminal"
        extraLabel: "Open bluetoothctl in a terminal"
        actionLabel: "Open network settings"
        onToggled: Bluetooth.toggleBluetooth()
        settingsTab: "network"
        onExtraActivated: {
            Bluetooth.openTerminal();
            Shell.close();
        }
    }

    RowList {
        id: list

        objectName: "deviceList"
        x: panel.contentX
        y: controls.y + controls.height + Theme.gap
        width: panel.contentWidth
        height: implicitHeight
        visible: Bluetooth.powered
        keys: panel.keys
        errors: Bluetooth.errors
        emptyText: Bluetooth.discovering ? "Looking for devices" : "No devices"

        delegate: ListRow {
            required property string rowKey
            readonly property var device: Bluetooth.deviceFor(rowKey)

            width: ListView.view.width
            iconName: device ? Bluetooth.deviceIcon(device) : "bluetooth"
            title: device ? device.name : rowKey
            subtitle: device ? Bluetooth.detailText(device) : ""
            highlighted: device ? device.connected : false
            expanded: list.expandedKey === rowKey
            actions: device ? panel.actionsFor(device) : []
            errorText: Bluetooth.errors[rowKey] ?? ""
            onClicked: {
                if (device)
                    panel.activate(device);
            }
            onSecondaryActivated: {
                if (device)
                    panel.activateSecondary(device);
            }
            onActionActivated: action => {
                if (device)
                    panel.act(device, action);
            }
        }
    }
}
