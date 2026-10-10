import QtQuick
import Quickshell

// A command whose whole stdout is one reading. Reads when it becomes active
// (and at start when it already is), every `interval` ms while active (0: on
// demand only) and on refresh(). One run at a time: a refresh asked during a
// run runs once more after it. A failing command is warned about once until
// it succeeds again; `read` only carries successful output.
Scope {
    id: root

    property list<string> command
    property int interval: 0
    property bool active: true
    // Names the reader in warnings.
    property string name: command.length > 0 ? command[0] : ""
    readonly property bool running: process.running

    signal read(string text)
    signal failed(int code)

    function refresh() {
        if (!process.run())
            internal.again = true;
    }

    onActiveChanged: {
        if (active)
            refresh();
    }

    Component.onCompleted: {
        if (active)
            refresh();
    }

    QtObject {
        id: internal

        property bool again: false
        property bool warned: false
    }

    Command {
        id: process

        command: root.command
        onFinished: (code, output) => {
            if (code === 0) {
                internal.warned = false;
                root.read(output);
            } else {
                if (!internal.warned)
                    console.warn(root.name + ": " + root.command.join(" ") + " exited with " + code);
                internal.warned = true;
                root.failed(code);
            }
            if (internal.again) {
                internal.again = false;
                process.run();
            }
        }
    }

    Timer {
        interval: Math.max(1, root.interval)
        repeat: true
        running: root.active && root.interval > 0
        onTriggered: root.refresh()
    }
}
