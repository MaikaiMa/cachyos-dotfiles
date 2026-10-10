pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The actions DMS owns, through its public `dms ipc call` interface only.
// Statuses are polled every 10 s and right after each change.
Singleton {
    id: root

    property bool nightLight: false
    // Idle inhibit.
    property bool caffeine: false
    // dark or light.
    property string themeMode: "dark"
    // matugenSmartMode: matugen picks light or dark from the wallpaper. The Theme
    // panel shows it as Auto; DMS turns it off on every manual light/dark switch.
    property bool smartMode: false
    // DMS's matugenScheme setting, such as scheme-tonal-spot.
    property string matugenScheme: "scheme-tonal-spot"
    // The values DMS 1.6 accepts, in its own order (its _matugenSchemeDefs);
    // scheme-smart is DMS's own: it picks a variant from the wallpaper.
    readonly property var schemes: [
        {
            value: "scheme-tonal-spot",
            label: "Tonal spot"
        },
        {
            value: "scheme-vibrant",
            label: "Vibrant"
        },
        {
            value: "scheme-content",
            label: "Content"
        },
        {
            value: "scheme-expressive",
            label: "Expressive"
        },
        {
            value: "scheme-fidelity",
            label: "Fidelity"
        },
        {
            value: "scheme-fruit-salad",
            label: "Fruit salad"
        },
        {
            value: "scheme-monochrome",
            label: "Monochrome"
        },
        {
            value: "scheme-neutral",
            label: "Neutral"
        },
        {
            value: "scheme-rainbow",
            label: "Rainbow"
        },
        {
            value: "scheme-smart",
            label: "Smart"
        }
    ]
    // DMS's terminalOverride session key (ghostty here); empty when unset.
    property string terminal: ""
    // A theme or scheme change is running or still settling (re-polls at
    // 300 ms, 1 s and 2.5 s after it); the Theme panel keeps its own choice
    // shown until then.
    property bool themeBusy: false
    // How long themeBusy lasts after the last call has exited.
    readonly property int settleDuration: settle.delays[settle.delays.length - 1]
    // Waiting theme actions, each a list of `dms ipc call` argument lists run in order.
    property var themeQueue: []
    // light, dark or auto while that choice is queued or settling.
    property string pendingMode: ""

    // A theme poll answered while no theme action is pending.
    signal themeReported

    function refresh() {
        nightStatus.running = true;
        caffeineStatus.running = true;
        themeStatus.running = true;
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

    // Light and Dark go through the portal, not `dms ipc call theme`: that IPC
    // always switches with a Niri screen transition that reveals a
    // half-rendered state. With smart mode off and syncModeWithPortal on, DMS
    // follows the GNOME colour scheme after its settle timer and switches
    // without one. Smart mode goes off first (only when on): while on, DMS
    // ignores the portal and re-resolves the mode from the wallpaper.
    // `settings set` only stores it. The bar then runs its own transition,
    // timed to cover DMS's render (see crossfade).
    function setLight() {
        setMode("light");
    }

    function setDark() {
        setMode("dark");
    }

    function setMode(mode: string) {
        if (themeBusy && pendingMode === mode) {
            console.info("Dms: " + mode + " is already pending, ignored");
            return;
        }
        const steps = [];
        if (smartMode)
            steps.push(["settings", "set", "matugenSmartMode", "false"]);
        steps.push(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", mode === "light" ? "default" : "prefer-dark"]);
        pendingMode = mode;
        themeMode = mode;
        smartMode = false;
        queueTheme(steps);
        if (Theme.themeCrossfade && !Motion.reduceMotion)
            crossfade.restart();
    }

    // Runs the steps one at a time, each after the previous one exited, and
    // actions one after another.
    function queueTheme(steps: var) {
        themeQueue = themeQueue.concat([steps]);
        themeBusy = true;
        settle.stop();
        settle.step = settle.delays.length;
        if (!themeRunner.running)
            runNextTheme();
    }

    function runNextTheme() {
        if (themeQueue.length === 0) {
            settle.begin();
            return;
        }
        const steps = themeQueue[0];
        const step = steps[0];
        themeQueue = steps.length > 1 ? [steps.slice(1)].concat(themeQueue.slice(1)) : themeQueue.slice(1);
        // The re-render step reads the wallpaper when it runs, not when it was queued.
        if (step === "rerender")
            themeRunner.command = ["sh", "-c", "dms ipc call wallpaper set \"$(dms ipc call wallpaper get)\""];
        else if (step[0] === "gsettings")
            themeRunner.command = step;
        else
            themeRunner.command = ["dms", "ipc", "call"].concat(step);
        console.info("Dms: theme call: " + (step === "rerender" ? "dms ipc call wallpaper set (dms ipc call wallpaper get)" : themeRunner.command.join(" ")));
        themeRunner.running = true;
    }

    // Read on demand (the Theme panel opening), not in the 10 s poll.
    function refreshTheme() {
        schemeStatus.running = true;
        smartStatus.running = true;
        themeStatus.running = true;
    }

    // `settings set` assigns the key and saves it without DMS's onChange hook,
    // so nothing re-renders by itself. Setting the current wallpaper again does
    // (docs/dms.md, "Triggering a re-render"), without the side effect of a
    // light/dark switch, which turns smart mode off.
    function setAndRender(key: string, value: string) {
        queueTheme([["settings", "set", key, value], "rerender"]);
    }

    function setAuto() {
        if (themeBusy && pendingMode === "auto") {
            console.info("Dms: auto is already pending, ignored");
            return;
        }
        pendingMode = "auto";
        smartMode = true;
        setAndRender("matugenSmartMode", "true");
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

    // A scheme-* value from `Theme.schemes`; the colours follow through dms-colors.json.
    function setScheme(name: string) {
        matugenScheme = name;
        setAndRender("matugenScheme", name);
    }

    Component.onCompleted: {
        refresh();
        refreshTheme();
    }

    Timer {
        interval: 10000
        repeat: true
        running: true
        onTriggered: root.refresh()
    }

    // Starts once the control has slid and the bar has recoloured, well before
    // DMS picks up the portal change, so Niri freezes the old desktop with the
    // new bar and cross-fades once DMS and its templates are done. Scheme
    // changes have no such lead (DMS renders within 200 ms) and get none.
    Timer {
        id: crossfade

        interval: Theme.themeCrossfadeLead
        onTriggered: {
            transition.command = ["niri", "msg", "action", "do-screen-transition", "--delay-ms", String(Theme.themeCrossfadeDelay)];
            transition.running = true;
        }
    }

    Process {
        id: transition

        onExited: code => { // qmllint disable signal-handler-parameters
            if (code !== 0)
                console.warn("Dms: " + transition.command.join(" ") + " exited with " + code);
        }
    }

    Process {
        id: themeRunner

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.startsWith("ERROR") || text.includes("FAILURE") || text.includes("INVALID"))
                    console.warn("Dms: " + themeRunner.command.join(" ") + ": " + text.trim());
            }
        }
        onRunningChanged: {
            if (!running)
                Qt.callLater(root.runNextTheme);
        }
    }

    // After a theme action DMS renders for a few seconds; poll at these delays
    // instead of waiting for the 10 s poll.
    Timer {
        id: settle

        readonly property var delays: [300, 1000, 2500]
        property int step: delays.length
        property int elapsed: 0

        function begin() {
            step = 0;
            elapsed = 0;
            interval = delays[0];
            restart();
        }

        // Only the last poll's answers are adopted: until then DMS may still
        // report the old mode, and the optimistic values stay.
        onTriggered: {
            elapsed = delays[step];
            step = step + 1;
            if (step < delays.length) {
                interval = delays[step] - elapsed;
                restart();
            } else {
                root.themeBusy = false;
                root.pendingMode = "";
            }
            root.refresh();
            root.refreshTheme();
        }
    }

    // DMS answers before it has applied some changes; give it a moment.
    Timer {
        id: afterCall

        interval: 400
        onTriggered: {
            root.refresh();
            root.refreshTheme();
        }
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

    // JSON: "scheme-tonal-spot".
    Process {
        id: schemeStatus

        command: ["dms", "ipc", "call", "settings", "get", "matugenScheme"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.themeBusy)
                    return;
                try {
                    const scheme = JSON.parse(text);
                    if (typeof scheme === "string" && scheme.startsWith("scheme-"))
                        root.matugenScheme = scheme;
                } catch (error) {
                    console.warn("Dms: unexpected matugenScheme answer: " + text.trim());
                }
            }
        }
    }

    // JSON: true or false.
    Process {
        id: smartStatus

        command: ["dms", "ipc", "call", "settings", "get", "matugenSmartMode"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.themeBusy)
                    return;
                root.smartMode = text.trim() === "true";
                root.themeReported();
            }
        }
    }

    // "dark" or "light".
    Process {
        id: themeStatus

        command: ["dms", "ipc", "call", "theme", "getMode"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.themeBusy)
                    return;
                const mode = text.trim();
                if (mode === "dark" || mode === "light")
                    root.themeMode = mode;
                root.themeReported();
            }
        }
    }
}
