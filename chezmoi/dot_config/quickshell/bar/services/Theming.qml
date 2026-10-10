pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Light / Dark / Auto and the matugen scheme: the theme state DMS owns, read
// and changed through `dms ipc call` and the desktop portal. The colours
// themselves arrive through Colors, from the file DMS writes.
Singleton {
    id: root

    // dark or light: the mode in dms-colors.json, the optimistic choice while busy.
    property string mode: "dark"
    // matugenSmartMode: matugen picks light or dark from the wallpaper. The Theme
    // panel shows it as Auto; DMS turns it off on every manual light/dark switch.
    property bool smartMode: false
    // DMS's matugenScheme setting, such as scheme-tonal-spot.
    property string scheme: "scheme-tonal-spot"
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
    // A theme or scheme change is running or DMS is still rendering it (2.5 s
    // after the last call); the Theme panel keeps its own choice shown until then.
    property bool busy: false
    // Waiting actions, each a list of steps run in order: a `dms ipc call`
    // argument list, a `gsettings` command, "rerender", "transition" (the Niri
    // screen transition) or "wait" (a pause of Theme.themeNudgeDuration).
    // GTK 3 applications, and Electron ones such as the Claude app, take light
    // or dark from the GTK theme name, not from the portal colour scheme
    // (checked 2026-10-10: with the scheme at prefer-light the Claude app
    // stayed dark until the theme name changed). DMS only changes the name
    // when its own GTK theming is applied, so the bar sets it.
    readonly property string gtkThemeLight: "adw-gtk3"
    readonly property string gtkThemeDark: "adw-gtk3-dark"
    property var queue: []
    // light, dark or auto while that choice is queued or settling.
    property string pendingMode: ""

    // A poll answered while no action is pending.
    signal reported

    // Light and Dark call `dms ipc call theme light|dark`, which switches at
    // once and turns smart mode off. Not the desktop portal: DMS 1.6.2 polls
    // the portal colour scheme about every 10 s instead of listening, so a
    // switch through gsettings landed 0 to 10 s later, and a second click in
    // that window was applied as the earlier value and written back to
    // gsettings, reverting every application (journal, 2026-10-10). The IPC
    // starts DMS's own Niri screen transition with a 0 ms delay, which would
    // fade before the render is done; Niri replaces a pending transition on
    // the next request and captures the frozen frame as the new start, so the
    // bar requests a second one right after the call, with a delay that
    // covers DMS's render (see crossfade in docs/shell.md).
    function setLight() {
        setMode("light");
    }

    function setDark() {
        setMode("dark");
    }

    function setMode(wanted: string) {
        if (busy && pendingMode === wanted) {
            console.info("Theming: " + wanted + " is already pending, ignored");
            return;
        }
        busy = true;
        pendingMode = wanted;
        mode = wanted;
        smartMode = false;
        settle.stop();
        lead.wanted = wanted;
        lead.restart();
    }

    function setAuto() {
        if (busy && pendingMode === "auto") {
            console.info("Theming: auto is already pending, ignored");
            return;
        }
        pendingMode = "auto";
        smartMode = true;
        setAndRender("matugenSmartMode", "true");
    }

    // A scheme-* value from `schemes`; the colours follow through dms-colors.json.
    function setScheme(name: string) {
        scheme = name;
        setAndRender("matugenScheme", name);
    }

    // `settings set` assigns the key and saves it without DMS's onChange hook,
    // so nothing re-renders by itself. Setting the current wallpaper again does
    // (docs/dms.md, "Triggering a re-render"), without the side effect of a
    // light/dark switch, which turns smart mode off.
    function setAndRender(key: string, value: string) {
        enqueue([["settings", "set", key, value], "rerender"]);
    }

    // Runs the steps one at a time, each after the previous one exited, and
    // actions one after another.
    function enqueue(steps: var) {
        queue = queue.concat([steps]);
        busy = true;
        settle.stop();
        if (!runner.running)
            runNext();
    }

    function runNext() {
        if (queue.length === 0) {
            settle.restart();
            return;
        }
        const steps = queue[0];
        const step = steps[0];
        queue = steps.length > 1 ? [steps.slice(1)].concat(queue.slice(1)) : queue.slice(1);
        // The re-render step reads the wallpaper when it runs, not when it was queued.
        if (step === "wait") {
            pause.restart();
            return;
        }
        if (step === "rerender")
            runner.command = ["sh", "-c", "dms ipc call wallpaper set \"$(dms ipc call wallpaper get)\""];
        else if (step === "transition")
            runner.command = ["niri", "msg", "action", "do-screen-transition", "--delay-ms", String(Theme.themeCrossfadeDelay)];
        else if (step[0] === "gsettings")
            runner.command = step;
        else
            runner.command = ["dms", "ipc", "call"].concat(step);
        console.info("Theming: theme call: " + (step === "rerender" ? "dms ipc call wallpaper set (dms ipc call wallpaper get)" : runner.command.join(" ")));
        runner.running = true;
    }

    // Smart mode and the scheme; the mode needs no poll, Colors reads it from
    // the file DMS rewrites on every switch.
    function refresh() {
        schemeStatus.running = true;
        smartStatus.running = true;
    }

    Component.onCompleted: refresh()

    // RestoreNone: going busy must keep the optimistic mode setMode assigns.
    Binding {
        target: root
        property: "mode"
        value: Colors.mode
        when: !root.busy
        restoreMode: Binding.RestoreNone
    }

    // The call waits until the control has slid and the bar has recoloured
    // from the preview, so the frame DMS freezes already shows the new bar.
    // Under reduce motion DMS's own transition still runs; the bar adds none.
    Timer {
        id: lead

        property string wanted: "dark"

        interval: Theme.themeCrossfadeLead
        onTriggered: {
            const light = wanted === "light";
            const steps = [["theme", wanted]];
            if (Theme.themeCrossfade && !Motion.reduceMotion)
                steps.push("transition");
            // DMS 1.6.2 applies the mode through two 100 ms QML timers that
            // only advance while DMS paints a frame, and an idle DMS without
            // its bar paints none: the switch waited until something made it
            // draw (a panel opening, a toast; journal 2026-10-10). A blank
            // toast makes it paint, behind the frozen screen; the same nudge
            // the dms-settings helper uses (docs/dms.md, Known limits).
            steps.push(["toast", "info", " "]);
            steps.push("wait");
            steps.push(["toast", "hide"]);
            steps.push(["gsettings", "set", "org.gnome.desktop.interface", "gtk-theme", light ? root.gtkThemeLight : root.gtkThemeDark]);
            // DMS writes the colour scheme itself once its timers have run,
            // "default" for light; Chromium reads that as no preference. The
            // explicit value is written after DMS's write has landed.
            steps.push(["gsettings", "set", "org.gnome.desktop.interface", "color-scheme", light ? "prefer-light" : "prefer-dark"]);
            root.enqueue(steps);
        }
    }

    Timer {
        id: pause

        interval: Theme.themeNudgeDuration
        onTriggered: root.runNext()
    }

    Process {
        id: runner

        stdout: StdioCollector {
            onStreamFinished: {
                if (text.startsWith("ERROR") || text.includes("FAILURE") || text.includes("INVALID"))
                    console.warn("Theming: " + runner.command.join(" ") + ": " + text.trim());
            }
        }
        onRunningChanged: {
            if (!running)
                Qt.callLater(root.runNext);
        }
    }

    // After an action DMS renders for a few seconds; until then it may still
    // report the old state, so the optimistic values stay and nothing is polled.
    Timer {
        id: settle

        interval: 2500
        onTriggered: {
            root.busy = false;
            root.pendingMode = "";
            root.refresh();
        }
    }

    // JSON: "scheme-tonal-spot".
    Process {
        id: schemeStatus

        command: ["dms", "ipc", "call", "settings", "get", "matugenScheme"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (root.busy)
                    return;
                try {
                    const answer = JSON.parse(text);
                    if (typeof answer === "string" && answer.startsWith("scheme-"))
                        root.scheme = answer;
                } catch (error) {
                    console.warn("Theming: unexpected matugenScheme answer: " + text.trim());
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
                if (root.busy)
                    return;
                root.smartMode = text.trim() === "true";
                root.reported();
            }
        }
    }
}
