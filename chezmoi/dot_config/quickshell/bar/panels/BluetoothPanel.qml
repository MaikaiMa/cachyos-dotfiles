pragma ComponentBehavior: Bound

import QtQuick
import ".."
import "../components"
import "../services"

// The Bluetooth state of the centre island, opened from the Settings tile: the
// control row, then connected, paired and discovered devices. A click connects
// a paired device; on a connected one it expands into Disconnect and Forget, on
// a discovered one into Pair. A right click on a paired device offers Connect
// and Forget. Discovery, the attempts and the errors live in `Bluetooth`; this
// panel only holds which row is expanded. Pairing has no agent here, so a
// button left of the settings button opens bluetoothctl for PINs and passkeys.
Appear {
    id: panel

    property string expandedKey: ""

    readonly property var devices: Bluetooth.devices
    readonly property var keys: devices.map(device => device.address)

    implicitWidth: Theme.panelWidths.bluetooth
    implicitHeight: 2 * Theme.panelPadding + Theme.controlRowHeight + (Bluetooth.powered ? Theme.gap + list.implicitHeight : 0)

    // Errors stay until the next attempt; only the expansion resets.
    onShownChanged: {
        expandedKey = "";
        if (shown)
            list.positionAtBeginning();
    }

    function toggleExpanded(key: string) {
        expandedKey = expandedKey === key ? "" : key;
    }

    function activate(device: var) {
        if (device.connected || !device.paired) {
            toggleExpanded(device.address);
        } else {
            expandedKey = "";
            Bluetooth.startConnect(device);
        }
    }

    // Paired devices get Connect and Forget; the rest behave like a click.
    function activateSecondary(device: var) {
        if (device.paired && !device.connected)
            toggleExpanded(device.address);
        else
            activate(device);
    }

    function act(device: var, action: string) {
        expandedKey = "";
        if (action === "connect") {
            Bluetooth.startConnect(device);
        } else if (action === "pair") {
            Bluetooth.startPair(device);
        } else {
            Bluetooth.setError(device.address, "");
            if (action === "disconnect")
                Bluetooth.disconnectDevice(device);
            else if (action === "forget")
                Bluetooth.forget(device);
        }
    }

    PanelControlRow {
        id: controls

        x: Theme.panelPadding
        y: Theme.panelPadding
        width: panel.width - 2 * Theme.panelPadding
        switchName: "Bluetooth"
        checked: Bluetooth.btEnabled
        switchEnabled: Bluetooth.available
        stateText: {
            if (!Bluetooth.available)
                return "Unavailable";
            if (!Bluetooth.btEnabled)
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
        onExtraClicked: {
            Bluetooth.openTerminal();
            Shell.close();
        }
        // The settings window needs the keyboard, which the open panel holds.
        onActionTriggered: {
            Dms.openSettingsTab("network");
            Shell.close();
        }
    }

    RowList {
        id: list

        objectName: "deviceList"
        x: Theme.panelPadding
        y: controls.y + controls.height + Theme.gap
        width: panel.width - 2 * Theme.panelPadding
        height: implicitHeight
        visible: Bluetooth.powered
        keys: panel.keys
        expandedKey: panel.expandedKey
        errors: Bluetooth.errors
        emptyText: Bluetooth.discovering ? "Looking for devices" : "No devices"

        delegate: NetworkRow {
            required property string rowKey
            readonly property var device: Bluetooth.deviceFor(rowKey)

            width: ListView.view.width
            iconName: device ? Bluetooth.deviceIcon(device) : "bluetooth"
            title: device ? device.name : rowKey
            detail: device ? Bluetooth.detailText(device) : ""
            highlighted: device ? device.connected : false
            expanded: panel.expandedKey === rowKey
            actions: {
                if (!device)
                    return [];
                const forget = {
                    key: "forget",
                    label: "Forget",
                    danger: true
                };
                if (device.connected)
                    return [
                        {
                            key: "disconnect",
                            label: "Disconnect"
                        },
                        forget
                    ];
                if (device.paired)
                    return [
                        {
                            key: "connect",
                            label: "Connect",
                            accent: true
                        },
                        forget
                    ];
                return [
                    {
                        key: "pair",
                        label: "Pair",
                        accent: true
                    }
                ];
            }
            errorText: Bluetooth.errors[rowKey] ?? ""
            onClicked: {
                if (device)
                    panel.activate(device);
            }
            onSecondaryClicked: {
                if (device)
                    panel.activateSecondary(device);
            }
            onActionTriggered: action => {
                if (device)
                    panel.act(device, action);
            }
        }
    }
}
