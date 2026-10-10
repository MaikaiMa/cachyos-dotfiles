import QtQuick
import Quickshell

// Writes a value through a command. While one write runs, only the newest
// send() waits and runs after it, so a slider drag never loses its last value
// and never queues the steps in between. `finished` comes once the newest
// value is written; a non-zero exit is warned about.
Scope {
    id: root

    // Names the writer in warnings.
    property string name: ""
    readonly property bool running: process.running

    signal finished(int code)

    function send(argv: list<string>) {
        internal.pending = argv;
        if (!process.running)
            internal.next();
    }

    QtObject {
        id: internal

        property var pending: null

        function next() {
            process.command = pending;
            pending = null;
            process.run();
        }
    }

    Command {
        id: process

        onFinished: code => {
            if (code !== 0)
                console.warn(root.name + ": " + process.command.join(" ") + " exited with " + code);
            if (internal.pending !== null)
                internal.next();
            else
                root.finished(code);
        }
    }
}
