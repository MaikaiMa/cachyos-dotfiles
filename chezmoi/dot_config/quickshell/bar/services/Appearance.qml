pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import ".."

// Light / Dark / Auto and the matugen scheme: the theme state DMS owns, read
// and changed through `dms ipc call` and the desktop portal. The colours
// themselves arrive through Colors, from the file DMS writes.
Singleton {
    id: root

    // Light and Dark: the bar calls DMS this long after the click, once the
    // control has slid and the bar has recoloured, then asks Niri for a screen
    // transition whose delay covers DMS's render and its templates (about
    // 0.8 s from the call; measure with scripts/theme-switch-timings.sh).
    readonly property int crossfadeLead: 300
    readonly property int crossfadeDelay: 1400
    // How long the blank toast that makes DMS paint stays up; the colour
    // scheme is written after it, once DMS's own write has landed.
    readonly property int nudgeDuration: 400
    // DMS renders for a few seconds after an action and may report the old
    // state until then.
    readonly property int settleDuration: 2500

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
    // GTK 3 applications, and Electron ones such as the Claude app, take light
    // or dark from the GTK theme name, not from the portal colour scheme
    // (checked 2026-10-10: with the scheme at prefer-light the Claude app
    // stayed dark until the theme name changed). DMS only changes the name
    // when its own GTK theming is applied, so the bar sets it.
    readonly property string gtkThemeLight: "adw-gtk3"
    readonly property string gtkThemeDark: "adw-gtk3-dark"
    // Waiting actions, each a list of steps run in order: a `dms ipc call`
    // argument list, a `gsettings` command, "rerender" (Wallpapers.rerender),
    // "transition" (the Niri screen transition) or "wait" (a pause of
    // nudgeDuration).
    property var queue: []
    // light, dark or auto while that choice is queued or settling.
    property string pendingMode: ""

    // A poll answered while no action is pending.
    signal reported

    // Through the IPC, not the portal, with a second screen transition: why,
    // see the Theme panel in docs/shell.md.
    function setLight() {
        setMode("light");
    }

    function setDark() {
        setMode("dark");
    }

    function setMode(wanted: string) {
        if (busy && pendingMode === wanted) {
            console.info("Appearance: " + wanted + " is already pending, ignored");
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
            console.info("Appearance: auto is already pending, ignored");
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
        if (!runner.running && !pause.running && !internal.rerendering)
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
        if (step === "wait") {
            pause.restart();
            return;
        }
        // The re-render reads the wallpaper when it runs, not when it was queued.
        if (step === "rerender") {
            console.info("Appearance: theme call: wallpaper rerender");
            internal.rerendering = true;
            Wallpapers.rerender(Shell.resolveScreen(""));
            return;
        }
        if (step === "transition")
            runner.command = ["niri", "msg", "action", "do-screen-transition", "--delay-ms", String(root.crossfadeDelay)];
        else if (step[0] === "gsettings")
            runner.command = step;
        else
            runner.command = ["dms", "ipc", "call"].concat(step);
        console.info("Appearance: theme call: " + runner.command.join(" "));
        runner.run();
    }

    // Smart mode and the scheme; the mode needs no poll, Colors reads it from
    // the file DMS rewrites on every switch.
    function refresh() {
        schemeStatus.run();
        smartStatus.run();
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

        interval: root.crossfadeLead
        onTriggered: {
            const light = wanted === "light";
            const steps = [["theme", wanted]];
            if (Settings.crossfade && !Motion.reduceMotion)
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

        interval: root.nudgeDuration
        onTriggered: root.runNext()
    }

    QtObject {
        id: internal

        property bool rerendering: false
    }

    Connections {
        target: Wallpapers

        function onRerendered() {
            if (!internal.rerendering)
                return;
            internal.rerendering = false;
            root.runNext();
        }
    }

    Command {
        id: runner

        onFinished: (code, output) => {
            if (code !== 0 || output.startsWith("ERROR") || output.includes("FAILURE") || output.includes("INVALID"))
                console.warn("Appearance: " + runner.command.join(" ") + " (" + code + "): " + output.trim());
            Qt.callLater(root.runNext);
        }
    }

    // After an action DMS renders for a few seconds; until then it may still
    // report the old state, so the optimistic values stay and nothing is polled.
    Timer {
        id: settle

        interval: root.settleDuration
        onTriggered: {
            root.busy = false;
            root.pendingMode = "";
            root.refresh();
        }
    }

    // JSON: "scheme-tonal-spot".
    Command {
        id: schemeStatus

        command: ["dms", "ipc", "call", "settings", "get", "matugenScheme"]
        onFinished: (code, output) => {
            if (root.busy)
                return;
            try {
                const answer = JSON.parse(output);
                if (typeof answer === "string" && answer.startsWith("scheme-"))
                    root.scheme = answer;
            } catch (error) {
                console.warn("Appearance: unexpected matugenScheme answer (" + code + "): " + output.trim());
            }
        }
    }

    // JSON: true or false.
    Command {
        id: smartStatus

        command: ["dms", "ipc", "call", "settings", "get", "matugenSmartMode"]
        onFinished: (code, output) => {
            if (root.busy)
                return;
            root.smartMode = output.trim() === "true";
            root.reported();
        }
    }
}
