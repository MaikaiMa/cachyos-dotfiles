pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower

// Battery and power profile from UPower, no subprocess.
Singleton {
    id: root

    // The display device aggregates all batteries; health and design capacity
    // only exist on the laptop battery itself.
    readonly property UPowerDevice device: UPower.displayDevice
    readonly property UPowerDevice laptopBattery: UPower.devices.values.find(candidate => candidate.isLaptopBattery) ?? null
    readonly property bool available: laptopBattery !== null

    // 0..100; Quickshell reports 0..1.
    readonly property real percentage: device ? device.percentage * 100 : 0
    // charging, discharging, full or unknown.
    readonly property string state: {
        if (!device)
            return "unknown";
        switch (device.state) {
        case UPowerDeviceState.Charging:
        case UPowerDeviceState.PendingCharge:
            return "charging";
        case UPowerDeviceState.Discharging:
        case UPowerDeviceState.PendingDischarge:
        case UPowerDeviceState.Empty:
            return "discharging";
        case UPowerDeviceState.FullyCharged:
            return "full";
        default:
            return "unknown";
        }
    }
    readonly property bool onBattery: UPower.onBattery
    // Seconds; 0 when UPower has no estimate.
    readonly property real timeToEmpty: device ? device.timeToEmpty : 0
    readonly property real timeToFull: device ? device.timeToFull : 0
    // Full capacity against design capacity, 0..100; 0 when not supported.
    readonly property real healthPercentage: laptopBattery && laptopBattery.healthSupported ? laptopBattery.healthPercentage : 0
    // Wh at full charge today.
    readonly property real energyCapacity: laptopBattery ? laptopBattery.energyCapacity : 0
    readonly property bool isLow: available && percentage < 15

    // power-saver, balanced or performance, the names powerprofilesctl uses.
    readonly property string profile: profileName(PowerProfiles.profile)
    readonly property var profiles: PowerProfiles.hasPerformanceProfile ? ["power-saver", "balanced", "performance"] : ["power-saver", "balanced"]

    function profileName(value: int): string {
        switch (value) {
        case PowerProfile.PowerSaver:
            return "power-saver";
        case PowerProfile.Performance:
            return "performance";
        default:
            return "balanced";
        }
    }

    function setProfile(name: string) {
        if (!profiles.includes(name)) {
            console.warn("Battery: unknown power profile " + name);
            return;
        }
        PowerProfiles.profile = name === "power-saver" ? PowerProfile.PowerSaver : name === "performance" ? PowerProfile.Performance : PowerProfile.Balanced;
    }
}
