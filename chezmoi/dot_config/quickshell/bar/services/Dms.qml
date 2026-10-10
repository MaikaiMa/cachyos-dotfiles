pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The actions DMS owns, through its public `dms ipc call` interface only:
// night light, idle inhibit and its settings window. Theme mode and scheme
// are in Theming. Statuses are polled every 10 s and right after each change.
Singleton {
    id: root

    property bool nightLight: false
    // Idle inhibit.
    property bool caffeine: false
    // DMS's terminalOverride session key (ghostty here); empty when unset.
    property string terminal: ""

    function refresh() {
        nightStatus.running = true;
        caffeineStatus.running = true;
    }

    function call(args: var) {
        const process = callComponent.createObject(root, {
            command: ["dms", "ipc", "call"].concat(args)
        });
        process.running = true;
    }

    function toggleNightLight() {
        call(["night", "toggle"]);
    }

    function toggleCaffeine() {
        call(["inhibit", "toggle"]);
    }

    // A tab id from `dms ipc call settings tabs`, such as network_wifi. Through
    // the helper: with the DMS bar off, DMS never maps its settings window on
    // its own (docs/dms.md, Known limits).
    function openSettingsTab(tab: string) {
        runSettingsHelper([tab]);
    }

    function runSettingsHelper(args: var) {
        const process = callComponent.createObject(root, {
            command: [Quickshell.env("HOME") + "/.local/bin/dms-settings"].concat(args)
        });
        process.running = true;
    }

    Component.onCompleted: refresh()

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    // DMS answers before it has applied some changes; give it a moment.
    Timer {
        id: afterCall

        interval: 400
        onTriggered: root.refresh()
    }

    Component {
        id: callComponent

        Process {
            id: ipcCall

            // QProcess::ExitStatus is not exposed to qmllint.
            onExited: code => { // qmllint disable signal-handler-parameters
                if (code !== 0)
                    console.warn("Dms: " + ipcCall.command.join(" ") + " exited with " + code);
                afterCall.restart();
                ipcCall.destroy();
            }
        }
    }

    FileView {
        path: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/DankMaterialShell/session.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                const override = JSON.parse(text()).terminalOverride;
                root.terminal = typeof override === "string" ? override.trim() : "";
            } catch (error) {
                console.warn("Dms: cannot parse session.json: " + error);
            }
        }
    }

    // First line: "Night mode: enabled" or "Night mode: disabled".
    Process {
        id: nightStatus

        command: ["dms", "ipc", "call", "night", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.nightLight = /^Night mode: enabled/m.test(text)
        }
    }

    // "Idle inhibit is enabled" or "... disabled".
    Process {
        id: caffeineStatus

        command: ["dms", "ipc", "call", "inhibit", "status"]
        stdout: StdioCollector {
            onStreamFinished: root.caffeine = /is enabled/.test(text)
        }
    }
}
