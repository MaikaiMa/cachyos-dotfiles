pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What the Display panel controls besides the panel backlight (`Brightness`):
// the night-light temperature and schedule through `dms ipc call night`
// (on and off stay in `Dms`), the keyboard backlight through brightnessctl and
// the rear window light through z13ctl and its state file. Read when the panel
// opens and after each write; the rear light's state file is watched.
Singleton {
    id: root

    readonly property bool panelOpen: Shell.centreState === "display"

    // DMS 1.6.2 `night setTargetTemp` takes 1000 to 6000 K, rounds to 500 K and
    // refuses a value above the day temperature (6500 K by default).
    readonly property int nightMinimum: 1000
    readonly property int nightStep: 500
    property int nightMaximum: 6000
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

    readonly property string z13State: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/z13ctl/state.json"
    // 0..3 from the state file, -1 without a lightbar.
    property int rearLevel: -1
    // RRGGBB, the theme colour sync-z13-window-color sets.
    property string rearColor: ""
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
        nightReader.running = true;
        keyboardReader.running = true;
        rearState.reload();
    }

    // A drag sends one call per step; only the newest waits while one runs.
    property int pendingTemperature: -1

    function setNightTemperature(kelvin: int) {
        pendingTemperature = Math.max(nightMinimum, Math.min(nightMaximum, Math.round(kelvin / nightStep) * nightStep));
        nightTemperature = pendingTemperature;
        if (!nightWriter.running)
            writeTemperature();
    }

    function writeTemperature() {
        nightWriter.command = ["dms", "ipc", "call", "night", "setTargetTemp", String(pendingTemperature)];
        pendingTemperature = -1;
        nightWriter.running = true;
    }

    function setKeyboardLevel(level: int) {
        keyboardLevel = Math.max(0, Math.min(3, level));
        keyboardWriter.command = ["brightnessctl", "-d", keyboardDevice, "set", String(keyboardLevel)];
        keyboardWriter.running = true;
    }

    // `z13ctl brightness` keeps the mode and colour; the theme sync keeps the level.
    function setRearLevel(level: int) {
        rearLevel = Math.max(0, Math.min(3, level));
        rearWriter.command = ["z13ctl", "brightness", levelNames[rearLevel], "--device", "lightbar"];
        rearWriter.running = true;
    }

    // "Night mode: disabled" / "Target night temperature: 4500K" from status,
    // then getDayTemp and getSchedule, in one run.
    function parseNight(text: string) {
        const parts = text.split("\n---night---\n");
        const target = /^Target night temperature: (\d+)K/m.exec(parts[0] ?? "");
        if (target)
            nightTemperature = Number(target[1]);
        const day = Number((parts[1] ?? "").trim());
        if (day > nightMinimum)
            nightMaximum = Math.min(6000, Math.floor(day / nightStep) * nightStep);
        schedule = (parts[2] ?? "").trim();
    }

    onPanelOpenChanged: {
        if (panelOpen)
            refresh();
    }

    Component.onCompleted: rearState.reload()

    Process {
        id: nightReader

        command: ["sh", "-c", "dms ipc call night status && printf '\\n---night---\\n' && dms ipc call night getDayTemp && printf '\\n---night---\\n' && dms ipc call night getSchedule"]
        stdout: StdioCollector {
            onStreamFinished: root.parseNight(text)
        }
    }

    Process {
        id: nightWriter

        onRunningChanged: {
            if (running)
                return;
            if (root.pendingTemperature >= 0)
                root.writeTemperature();
            else
                nightReader.running = true;
        }
    }

    // brightnessctl -m prints: device,class,current,percent%,max
    Process {
        id: keyboardReader

        command: ["brightnessctl", "-d", root.keyboardDevice, "-m"]
        stdout: StdioCollector {
            onStreamFinished: {
                const fields = text.trim().split(",");
                root.keyboardLevel = fields.length >= 5 && fields[0] === root.keyboardDevice ? Number(fields[2]) : -1;
            }
        }
    }

    Process {
        id: keyboardWriter

        onRunningChanged: {
            if (!running)
                keyboardReader.running = true;
        }
    }

    Process {
        id: rearWriter

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0)
                console.warn("Display: " + rearWriter.command.join(" ") + " exited with " + code);
            rearState.reload();
        }
    }

    // devices.lightbar: { enabled, color, brightness 0..3 }.
    FileView {
        id: rearState

        path: root.z13State
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
                console.warn("Display: cannot parse " + root.z13State + ": " + error);
            }
        }
    }
}
