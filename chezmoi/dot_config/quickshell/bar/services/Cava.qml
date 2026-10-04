pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Audio levels for the orb and the top-edge wave: cava's raw ascii output,
// running only while it is enabled and something plays.
Singleton {
    id: root

    readonly property int bandCount: 24
    readonly property string configDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dotfiles-bar"
    readonly property string configPath: configDir + "/cava.conf"
    readonly property string config: ["[general]", "bars = " + bandCount, "framerate = 30", "autosens = 1", "sleep_timer = 1", "", "[input]", "method = pipewire", "source = auto", "", "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 100", "bar_delimiter = 59", "frame_delimiter = 10", "channels = mono", "mono_option = average", ""].join("\n")

    // Set by the widgets that draw levels (orb, wave).
    property bool enabled: false
    property bool configReady: false
    readonly property bool running: configReady && enabled && Music.playing

    // 0..1 each.
    property var bands: zeros()
    readonly property real level: bands.reduce((sum, band) => sum + band, 0) / bandCount
    readonly property real low: (bands[0] + bands[1] + bands[2] + bands[3]) / 4

    function zeros(): var {
        return new Array(bandCount).fill(0);
    }

    // One frame: "12;0;57;...;" with values 0..100.
    function parseFrame(line: string) {
        const values = line.split(";").filter(field => field !== "").map(field => Math.max(0, Math.min(1, Number(field) / 100 || 0)));
        if (values.length === bandCount)
            bands = values;
    }

    onRunningChanged: {
        if (!running)
            bands = zeros();
    }

    Process {
        command: ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/cava.conf\"", "sh", root.configDir, root.config]
        running: true
        // QProcess::ExitStatus is not exposed to qmllint.
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code === 0)
                root.configReady = true;
            else
                console.warn("Cava: cannot write " + root.configPath);
        }
    }

    Process {
        command: ["cava", "-p", root.configPath]
        running: root.running
        stdout: SplitParser {
            onRead: line => root.parseFrame(line)
        }
    }
}
