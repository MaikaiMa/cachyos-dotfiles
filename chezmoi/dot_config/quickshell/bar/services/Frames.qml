pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Frames presented per window over the last minute, in one-second buckets, for
// power debugging: quickshell ipc -c bar call bardebug frames 5
Singleton {
    id: root

    readonly property int span: 60
    // "screen window" -> { last: second, counts: [span] }
    property var counters: ({})

    function advance(counter: var, second: int) {
        for (let past = counter.last + 1; past <= second && past <= counter.last + span; past++)
            counter.counts[past % span] = 0;
        counter.last = Math.max(counter.last, second);
    }

    function count(screen: string, window: string) {
        const second = Math.floor(Date.now() / 1000);
        const key = screen + " " + window;
        if (!counters[key])
            counters[key] = {
                last: second,
                counts: new Array(span).fill(0)
            };
        advance(counters[key], second);
        counters[key].counts[second % span] += 1;
    }

    // The last whole seconds, before the current one.
    function report(seconds: int): string {
        const length = Math.max(1, Math.min(span - 1, seconds));
        const now = Math.floor(Date.now() / 1000);
        const screens = {};
        for (const key of Object.keys(counters).sort()) {
            const [screen, window] = key.split(" ");
            const counter = counters[key];
            advance(counter, now);
            let total = 0;
            for (let past = now - length; past < now; past++)
                total += counter.counts[past % span];
            (screens[screen] = screens[screen] ?? []).push(window + "=" + total);
        }
        return Object.keys(screens).map(screen => screen + " " + screens[screen].join(" ") + " (" + length + " s)").join("\n");
    }

    IpcHandler {
        target: "bardebug"

        // Frames each window presented in the last given seconds (at most 59).
        function frames(seconds: int): string {
            return root.report(seconds);
        }
    }
}
