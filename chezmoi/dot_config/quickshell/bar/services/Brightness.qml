pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Display backlight through brightnessctl; the Z13 has no ambient light sensor.
Singleton {
    id: root

    readonly property var steps: [25, 50, 75, 100]

    // 0..100, rounded; -1 until the first read.
    property int percentage: -1
    property string device: ""
    readonly property bool available: percentage >= 0

    function refresh() {
        reader.running = true;
    }

    // A slider drag sets faster than brightnessctl runs: only the newest value
    // waits, and it is written as soon as the running write ends.
    property int pendingValue: -1

    // Never 0: a black screen is not a brightness. The percentage follows at once,
    // so key repeats step from the new value and the OSD shows it.
    function set(value: int) {
        pendingValue = Math.max(1, Math.min(100, Math.round(value)));
        percentage = pendingValue;
        if (!writer.running)
            writePending();
    }

    function writePending() {
        writer.command = ["brightnessctl", "--class=backlight", "set", pendingValue + "%"];
        pendingValue = -1;
        writer.running = true;
    }

    // 25, 50, 75, 100, then back to 25.
    function cycle() {
        const next = steps.find(step => step > percentage + 2);
        set(next ?? steps[0]);
    }

    // brightnessctl -m prints: device,class,current,percent%,max
    function parse(line: string) {
        const fields = line.trim().split(",");
        const current = Number(fields[2]);
        const maximum = Number(fields[4]);
        if (fields.length < 5 || !(maximum > 0)) {
            console.warn("Brightness: unexpected brightnessctl output: " + line);
            return;
        }
        device = fields[0];
        percentage = Math.round(current / maximum * 100);
    }

    Process {
        id: reader

        command: ["brightnessctl", "--class=backlight", "-m"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.parse(text.split("\n")[0])
        }
    }

    Process {
        id: writer

        onRunningChanged: {
            if (running)
                return;
            if (root.pendingValue >= 0)
                root.writePending();
            else
                root.refresh();
        }
    }

    // Brightness keys and DMS change it behind our back.
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }
}
