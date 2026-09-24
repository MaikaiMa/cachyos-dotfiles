import QtQuick
import Quickshell.Io

Item {
    id: watcher

    property var command: []

    signal line(string text)

    Process {
        id: process

        command: watcher.command
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: data => watcher.line(data.trim())
        }

        onExited: restart.start()
    }

    // The watch commands only exit when their monitor fails; retry instead of freezing the state.
    Timer {
        id: restart

        interval: 5000
        onTriggered: process.running = true
    }
}
