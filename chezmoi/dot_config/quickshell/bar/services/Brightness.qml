pragma Singleton

import QtQuick
import Quickshell

// Display backlight through brightnessctl; the Z13 has no ambient light sensor.
Singleton {
    id: root

    // Set by Shell while the Settings or Display panel, the level's only
    // readers, is open; the keys go through set() and need no poll.
    property bool active: false
    // DMS and other tools change the level behind the bar's back.
    readonly property int pollInterval: 5000

    readonly property var steps: [25, 50, 75, 100]

    // 0..100, rounded; -1 until the first read and without a backlight.
    property int percentage: -1
    property string device: ""
    readonly property bool available: percentage >= 0

    function refresh() {
        reader.refresh();
    }

    // Never 0: a black screen is not a brightness. The percentage follows at once,
    // so key repeats step from the new value and the OSD shows it.
    function set(value: int) {
        percentage = Math.max(1, Math.min(100, Math.round(value)));
        writer.send(["brightnessctl", "--class=backlight", "set", percentage + "%"]);
    }

    // 25, 50, 75, 100, then back to 25.
    function cycle() {
        const next = steps.find(step => step > percentage + 2);
        set(next ?? steps[0]);
    }

    // brightnessctl -m prints: device,class,current,percent%,max. Without a
    // backlight (an external monitor only) it prints nothing: warned once.
    function parse(line: string) {
        const fields = line.trim().split(",");
        const current = Number(fields[2]);
        const maximum = Number(fields[4]);
        if (fields.length < 5 || !(maximum > 0)) {
            if (!internal.warnedEmpty)
                console.warn("Brightness: unexpected brightnessctl output: \"" + line + "\"; no backlight");
            internal.warnedEmpty = true;
            percentage = -1;
            return;
        }
        internal.warnedEmpty = false;
        device = fields[0];
        percentage = Math.round(current / maximum * 100);
    }

    QtObject {
        id: internal

        property bool warnedEmpty: false
    }

    // At start for the OSD keys, then while active.
    CommandReader {
        id: reader

        name: "Brightness"
        command: ["brightnessctl", "--class=backlight", "-m"]
        interval: root.pollInterval
        active: root.active
        onRead: text => root.parse(text.split("\n")[0])
        Component.onCompleted: refresh()
    }

    CommandWriter {
        id: writer

        name: "Brightness"
        onFinished: root.refresh()
    }
}
