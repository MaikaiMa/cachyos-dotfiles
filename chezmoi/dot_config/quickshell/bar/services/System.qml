pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU load, CPU temperature and memory, sampled every 2 s while active is set.
Singleton {
    id: root

    // Set by Shell while the Home panel is open.
    property bool active: false

    readonly property int sampleInterval: 2000

    // 0..1 over the last sample interval.
    property real cpu: 0
    // °C from k10temp (Tctl); NaN when no k10temp hwmon exists.
    property real temperature: NaN
    // The temperature bar runs from empty at 30 °C to full at 95 °C.
    readonly property real temperatureMin: 30
    readonly property real temperatureMax: 95
    // 0..1 on that scale; 0 without a reading.
    readonly property real temperatureLevel: isNaN(temperature) ? 0 : Math.max(0, Math.min(1, (temperature - temperatureMin) / (temperatureMax - temperatureMin)))
    // 0..1 of MemTotal; used = total - available.
    property real memory: 0

    // hwmon numbers change between boots, so the directory is found by name.
    property string tempPath: ""
    property var previousCpu: null

    function sample() {
        statFile.reload();
        memFile.reload();
        if (tempPath !== "")
            tempFile.reload();
    }

    // First line: cpu user nice system idle iowait irq softirq steal ...
    function parseStat(text: string) {
        const fields = text.split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
        const idle = fields[3] + fields[4];
        const total = fields.reduce((sum, value) => sum + value, 0);
        if (previousCpu && total > previousCpu.total)
            cpu = 1 - (idle - previousCpu.idle) / (total - previousCpu.total);
        previousCpu = {
            idle: idle,
            total: total
        };
    }

    function parseMeminfo(text: string) {
        const total = Number((/^MemTotal:\s+(\d+)/m.exec(text) ?? [])[1]);
        const available = Number((/^MemAvailable:\s+(\d+)/m.exec(text) ?? [])[1]);
        if (!(total > 0) || isNaN(available))
            return;
        memory = (total - available) / total;
    }

    onActiveChanged: {
        if (active)
            sample();
        else
            previousCpu = null;
    }

    Timer {
        interval: root.sampleInterval
        repeat: true
        running: root.active
        onTriggered: root.sample()
    }

    // Keep the default preload: without it reload() does not read the file. The
    // first load at start is ignored, so the first CPU value covers 2 s, not the uptime.
    FileView {
        id: statFile

        path: "/proc/stat"
        onLoaded: if (root.active) root.parseStat(text())
    }

    FileView {
        id: memFile

        path: "/proc/meminfo"
        onLoaded: if (root.active) root.parseMeminfo(text())
    }

    FileView {
        id: tempFile

        path: root.tempPath === "" ? "" : root.tempPath + "/temp1_input"
        printErrors: false
        onLoaded: root.temperature = Number(text().trim()) / 1000
    }

    Command {
        command: ["sh", "-c", "for name in /sys/class/hwmon/*/name; do [ \"$(cat \"$name\")\" = k10temp ] && { dirname \"$name\"; exit 0; }; done; exit 1"]
        onFinished: (code, output) => {
            if (code === 0)
                root.tempPath = output.trim();
            else
                console.warn("System: no k10temp hwmon; CPU temperature unavailable");
        }
        Component.onCompleted: run()
    }
}
