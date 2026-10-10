import QtQuick
import Quickshell
import Quickshell.Io

// One run of a command at a time. finished(code, output) comes once per run,
// when both the exit and the whole stdout have arrived, in whatever order
// QProcess delivers them; a command that cannot start finishes with -1. With
// `lines` set, stdout arrives line by line through `line` and `output` is empty.
Scope {
    id: root

    property list<string> command
    property bool lines: false
    readonly property bool running: process.running

    signal finished(int code, string output)
    signal line(string text)

    // False when a run is still going; it is not restarted.
    function run(): bool {
        if (process.running)
            return false;
        internal.started = false;
        internal.code = null;
        internal.output = root.lines ? "" : null;
        process.running = true;
        return true;
    }

    function stop() {
        process.running = false;
    }

    QtObject {
        id: internal

        property bool started: false
        property var code: null
        property var output: null

        // Reported from runningChanged or a late stdout, never from exited:
        // a run started from a finished handler inside exited would race the
        // runningChanged that follows it.
        function settle() {
            if (process.running)
                return;
            if (!started) {
                code = -1;
                output = "";
            }
            if (code === null || output === null)
                return;
            const result = [code, output];
            code = null;
            output = null;
            started = false;
            root.finished(result[0], result[1]);
        }
    }

    Process {
        id: process

        command: root.command
        stdout: root.lines ? splitter : collector
        onStarted: internal.started = true
        // QProcess::ExitStatus is not exposed to qmllint.
        onExited: code => { // qmllint disable signal-handler-parameters
            internal.code = code;
        }
        onRunningChanged: {
            if (!running)
                internal.settle();
        }

        property StdioCollector collector: StdioCollector {
            onStreamFinished: {
                internal.output = text;
                internal.settle();
            }
        }

        property SplitParser splitter: SplitParser {
            onRead: data => root.line(data.trim())
        }
    }
}
