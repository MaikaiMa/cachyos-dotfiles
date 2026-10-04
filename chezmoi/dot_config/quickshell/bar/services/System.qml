pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// CPU load, CPU temperature and memory, sampled every 2 s while active is set.
Singleton {
    id: root

    // Set by the Home panel while it is open.
    property bool active: false

    // 0..1 over the last sample interval.
    property real cpu: 0
    // °C from k10temp (Tctl); NaN when no k10temp hwmon exists.
    property real temp: NaN
    // 0..1 of MemTotal; used = total - available.
    property real memory: 0
    property real memoryUsedGiB: 0
    property real memoryTotalGiB: 0

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
        memoryUsedGiB = (total - available) / 1048576;
        memoryTotalGiB = total / 1048576;
    }

    onActiveChanged: {
        if (active)
            sample();
        else
            previousCpu = null;
    }

    Timer {
        interval: 2000
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
        onLoaded: root.temp = Number(text().trim()) / 1000
    }

    Process {
        command: ["sh", "-c", "for name in /sys/class/hwmon/*/name; do [ \"$(cat \"$name\")\" = k10temp ] && { dirname \"$name\"; exit 0; }; done; exit 1"]
        running: true
        stdout: StdioCollector {
            onStreamFinished: root.tempPath = text.trim()
        }
        // QProcess::ExitStatus is not exposed to qmllint.
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0)
                console.warn("System: no k10temp hwmon; CPU temperature unavailable");
        }
    }
}
