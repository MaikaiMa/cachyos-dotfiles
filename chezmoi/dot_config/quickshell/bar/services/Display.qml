pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the Display panel controls besides the panel backlight (`Brightness`):
// night light, its temperature and schedule through `dms ipc call night`, the
// keyboard backlight through brightnessctl and the rear window light through
// z13ctl and its state file. Read when the panel opens and after each write;
// the rear light's state file is watched.
Singleton {
    id: root

    // Set by Shell while the Display panel is open.
    property bool active: false

    // DMS 1.6.2 `night setTargetTemp` takes 1000 to 6000 K, rounds to 500 K and
    // refuses a value above the day temperature (6500 K by default).
    readonly property int nightMinimum: 1000
    readonly property int nightCeiling: 6000
    readonly property int nightStep: 500
    property int nightMaximum: nightCeiling
    property bool nightLight: false
    // -1 until the first read.
    property int nightTemperature: -1
    // `getSchedule` as DMS prints it: "Automation disabled" or "Mode: ...\n...".
    property string schedule: ""
    readonly property string scheduleText: {
        if (schedule === "")
            return "";
        if (/^Automation disabled/.test(schedule))
            return "No schedule · set one in settings";
        const field = name => {
            const match = new RegExp("^" + name + ": (.+)$", "m").exec(schedule);
            return match ? match[1].trim() : "";
        };
        const mode = field("Mode");
        const next = field("Next transition");
        return "Schedule" + (mode ? " (" + mode + ")" : "") + (next ? " · next change " + next : "");
    }

    readonly property string keyboardDevice: "asus::kbd_backlight"
    readonly property var levelNames: ["off", "low", "medium", "high"]
    // 0..3, -1 when the LED is absent.
    property int keyboardLevel: -1
    readonly property bool keyboardAvailable: keyboardLevel >= 0

    readonly property string rearStatePath: Paths.state + "/z13ctl/state.json"
    // 0..3 from the state file, -1 without a lightbar.
    property int rearLevel: -1
    // RRGGBB, the theme colour sync-z13-window-color sets.
    property string rearColor: ""
    // The rear light's theme colour, transparent while there is none.
    readonly property color rearTint: rearColor !== "" ? "#" + rearColor : "transparent"
    readonly property bool rearAvailable: rearLevel >= 0

    // 0..100 on the capsule and back, in whole 500 K steps.
    function nightFraction(kelvin: int): real {
        return (kelvin - nightMinimum) / (nightMaximum - nightMinimum) * 100;
    }

    function nightKelvin(fraction: real): int {
        const kelvin = nightMinimum + fraction / 100 * (nightMaximum - nightMinimum);
        return Math.max(nightMinimum, Math.min(nightMaximum, Math.round(kelvin / nightStep) * nightStep));
    }

    function refresh() {
        readNight();
        keyboardReader.refresh();
        rearState.reload();
    }

    function readNight() {
        nightStatus.refresh();
        dayTemperature.refresh();
        nightSchedule.refresh();
    }

    // DMS answers before it has applied the switch; read again once Dms settled.
    function toggleNightLight() {
        Dms.call(["night", "toggle"]);
    }

    function setNightTemperature(kelvin: int) {
        nightTemperature = Math.max(nightMinimum, Math.min(nightMaximum, Math.round(kelvin / nightStep) * nightStep));
        nightWriter.send(["dms", "ipc", "call", "night", "setTargetTemp", String(nightTemperature)]);
    }

    function setKeyboardLevel(level: int) {
        keyboardLevel = Math.max(0, Math.min(3, level));
        keyboardWriter.send(["brightnessctl", "-d", keyboardDevice, "set", String(keyboardLevel)]);
    }

    // `z13ctl brightness` keeps the mode and colour; the theme sync keeps the level.
    function setRearLevel(level: int) {
        rearLevel = Math.max(0, Math.min(3, level));
        rearWriter.send(["z13ctl", "brightness", levelNames[rearLevel], "--device", "lightbar"]);
    }

    // "Night mode: enabled" or "Night mode: disabled", then
    // "Target night temperature: 4500K".
    function parseNight(text: string) {
        nightLight = /^Night mode: enabled/m.test(text);
        const target = /^Target night temperature: (\d+)K/m.exec(text);
        if (target)
            nightTemperature = Number(target[1]);
    }

    function parseDayTemperature(text: string) {
        const day = Number(text.trim());
        if (day > nightMinimum)
            nightMaximum = Math.min(nightCeiling, Math.floor(day / nightStep) * nightStep);
    }

    // brightnessctl -m prints: device,class,current,percent%,max
    function parseKeyboard(text: string) {
        const fields = text.trim().split(",");
        keyboardLevel = fields.length >= 5 && fields[0] === keyboardDevice ? Number(fields[2]) : -1;
    }

    onActiveChanged: {
        if (active)
            refresh();
    }

    Component.onCompleted: rearState.reload()

    Connections {
        target: Dms

        function onSettled() {
            if (root.active)
                root.readNight();
        }
    }

    CommandReader {
        id: nightStatus

        name: "Display"
        command: ["dms", "ipc", "call", "night", "status"]
        active: false
        onRead: text => root.parseNight(text)
    }

    CommandReader {
        id: dayTemperature

        name: "Display"
        command: ["dms", "ipc", "call", "night", "getDayTemp"]
        active: false
        onRead: text => root.parseDayTemperature(text)
    }

    CommandReader {
        id: nightSchedule

        name: "Display"
        command: ["dms", "ipc", "call", "night", "getSchedule"]
        active: false
        onRead: text => root.schedule = text.trim()
    }

    CommandWriter {
        id: nightWriter

        name: "Display"
        onFinished: root.readNight()
    }

    CommandReader {
        id: keyboardReader

        name: "Display"
        command: ["brightnessctl", "-d", root.keyboardDevice, "-m"]
        active: false
        onRead: text => root.parseKeyboard(text)
        onFailed: root.keyboardLevel = -1
    }

    CommandWriter {
        id: keyboardWriter

        name: "Display"
        onFinished: keyboardReader.refresh()
    }

    CommandWriter {
        id: rearWriter

        name: "Display"
        onFinished: rearState.reload()
    }

    // devices.lightbar: { enabled, color, brightness 0..3 }.
    FileView {
        id: rearState

        path: root.rearStatePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoadFailed: root.rearLevel = -1
        onLoaded: {
            try {
                const lightbar = (JSON.parse(text()).devices ?? {}).lightbar;
                if (!lightbar) {
                    root.rearLevel = -1;
                    return;
                }
                root.rearLevel = lightbar.enabled === false ? 0 : Math.max(0, Math.min(3, Number(lightbar.brightness ?? 3)));
                root.rearColor = String(lightbar.color ?? "");
            } catch (error) {
                console.warn("Display: cannot parse " + root.rearStatePath + ": " + error);
            }
        }
    }
}
