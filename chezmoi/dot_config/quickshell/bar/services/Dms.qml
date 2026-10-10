pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// The actions DMS owns, through its public `dms ipc call` interface: idle
// inhibit (polled every 10 s, the right island shows it), its settings window
// and the calls of other services (night light in Display; theme mode and
// scheme in Appearance). One read-only internal dependency: `terminal` comes
// from DMS's session.json, which is not a public interface; without it the
// terminal fallbacks apply.
Singleton {
    id: root

    readonly property int pollInterval: 10000
    // DMS answers a call before it has applied some changes.
    readonly property int settleDelay: 400

    // Idle inhibit.
    property bool caffeine: false
    // DMS's terminalOverride session key (ghostty here); empty when unset.
    property string terminal: ""

    // settleDelay after the last call; the services that called re-read then.
    signal settled

    function refresh() {
        caffeineStatus.refresh();
    }

    function call(args: list<string>) {
        run(["dms", "ipc", "call"].concat(args));
    }

    function toggleCaffeine() {
        call(["inhibit", "toggle"]);
    }

    // A tab id from `dms ipc call settings tabs`, such as network_wifi. Through
    // the helper: with the DMS bar off, DMS never maps its settings window on
    // its own (docs/dms.md, Known limits).
    function openSettingsTab(tab: string) {
        run([Paths.localBin + "/dms-settings", tab]);
    }

    // One Command per call: calls are independent and none may be dropped.
    function run(argv: list<string>) {
        const command = callComponent.createObject(root, {
            command: argv
        }) as Command;
        command.run();
    }

    onSettled: refresh()

    Timer {
        id: afterCall

        interval: root.settleDelay
        onTriggered: root.settled()
    }

    Component {
        id: callComponent

        Command {
            id: dmsCall

            onFinished: code => {
                if (code !== 0)
                    console.warn("Dms: " + dmsCall.command.join(" ") + " exited with " + code);
                afterCall.restart();
                dmsCall.destroy();
            }
        }
    }

    FileView {
        path: Paths.dmsState + "/session.json"
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

    // "Idle inhibit is enabled" or "... disabled".
    CommandReader {
        id: caffeineStatus

        name: "Dms"
        command: ["dms", "ipc", "call", "inhibit", "status"]
        interval: root.pollInterval
        onRead: text => root.caffeine = /is enabled/.test(text)
    }
}
