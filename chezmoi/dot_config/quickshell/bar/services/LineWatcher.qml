import QtQuick
import Quickshell

// A long-running command that prints one state per line, run while `active`.
// It only exits when its source fails; it is started again after
// `retryInterval` instead of freezing the state. One that keeps exiting at
// once is warned about once, then retried quietly.
Scope {
    id: root

    property list<string> command
    property bool active: false
    property int retryInterval: 5000
    // Names the watcher in warnings.
    property string name: command.length > 0 ? command[0] : ""

    signal line(string text)
    signal stopped(int code)

    onActiveChanged: {
        if (active) {
            process.run();
        } else {
            retry.stop();
            process.stop();
        }
    }

    Component.onCompleted: {
        if (active)
            process.run();
    }

    QtObject {
        id: internal

        property real startedAt: 0
        property int quickExits: 0
        property bool warned: false
    }

    Command {
        id: process

        command: root.command
        lines: true
        onRunningChanged: {
            if (running)
                internal.startedAt = Date.now();
        }
        onLine: text => root.line(text)
        onFinished: code => {
            root.stopped(code);
            if (!root.active)
                return;
            internal.quickExits = Date.now() - internal.startedAt < 2 * root.retryInterval ? internal.quickExits + 1 : 0;
            if (internal.quickExits >= 3 && !internal.warned) {
                internal.warned = true;
                console.warn(root.name + ": " + root.command.join(" ") + " keeps exiting (last code " + code + "); retrying every " + root.retryInterval / 1000 + " s");
            }
            retry.start();
        }
    }

    Timer {
        id: retry

        interval: root.retryInterval
        onTriggered: {
            if (root.active)
                process.run();
        }
    }
}
