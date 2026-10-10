import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// The IPC targets `bar` and `notifications` for the Niri shortcuts. A plain
// Scope, not a singleton: singletons load lazily, so shell.qml creates this
// once beside the screens.
Scope {
    id: root

    function stepVolume(step: int) {
        Audio.setVolume((Math.round(Audio.volume * 100) + step) / 100);
        Shell.showOsd(Shell.ipcScreen(), "volume");
    }

    function stepBrightness(step: int) {
        if (Brightness.available)
            Brightness.setPercentage(Brightness.percentage + step);
        Shell.showOsd(Shell.ipcScreen(), "brightness");
    }

    // quickshell ipc -c bar call bar toggle home
    IpcHandler {
        target: "bar"

        function open(state: string): void {
            if (state === "hidden")
                Shell.setHidden(true);
            else
                Shell.open(state, Shell.ipcScreen());
        }

        // "hidden" hides or shows the whole bar.
        function toggle(state: string): void {
            if (state === "hidden")
                Shell.setHidden(!Shell.hidden);
            else
                Shell.toggle(state, Shell.ipcScreen());
        }

        function close(): void {
            Shell.close();
        }

        function osd(): void {
            Shell.showOsd(Shell.ipcScreen(), "volume");
        }

        // up, down (one slider step), mute, micmute.
        function volume(action: string): void {
            if (action === "up" || action === "down") {
                root.stepVolume(action === "up" ? Theme.sliderStep : -Theme.sliderStep);
            } else if (action === "mute") {
                Audio.toggleMute();
                Shell.showOsd(Shell.ipcScreen(), "volume");
            } else if (action === "micmute") {
                Audio.toggleMicMute();
                Shell.showOsd(Shell.ipcScreen(), "mic");
            } else {
                console.warn("BarIpc: unknown volume action " + action);
            }
        }

        // up or down, one slider step.
        function brightness(action: string): void {
            if (action === "up" || action === "down")
                root.stepBrightness(action === "up" ? Theme.sliderStep : -Theme.sliderStep);
            else
                console.warn("BarIpc: unknown brightness action " + action);
        }

        // next, prev, playpause, play, pause.
        function media(action: string): void {
            if (action === "next")
                Music.next();
            else if (action === "prev")
                Music.previous();
            else if (action === "playpause")
                Music.togglePlaying();
            else if (action === "play")
                Music.play();
            else if (action === "pause")
                Music.pause();
            else
                console.warn("BarIpc: unknown media action " + action);
        }

        function state(): string {
            return Shell.centreState + " on " + Shell.screenName;
        }

        // on, off or toggle the top-edge wave; kept across restarts. Returns the new state.
        function wave(action: string): string {
            if (action === "on" || action === "off")
                Settings.setWaveEnabled(action === "on");
            else if (action === "toggle")
                Settings.setWaveEnabled(!Settings.waveEnabled);
            else
                console.warn("BarIpc: unknown wave action " + action);
            return Settings.waveEnabled ? "on" : "off";
        }

        // on, off or toggle reduce motion: every duration 0, no music motion,
        // no peeks of the playing track; kept across restarts. Returns the new state.
        function reduceMotion(action: string): string {
            if (action === "on" || action === "off")
                Settings.setReduceMotion(action === "on");
            else if (action === "toggle")
                Settings.setReduceMotion(!Settings.reduceMotion);
            else
                console.warn("BarIpc: unknown reduceMotion action " + action);
            return Settings.reduceMotion ? "on" : "off";
        }
    }

    // quickshell ipc -c bar call notifications openList
    IpcHandler {
        target: "notifications"

        // Settings scrolled to the list, as the bell's click; also while the stack shows.
        function openList(): void {
            Shell.toggle("settings", Shell.ipcScreen());
        }

        // The list, the rows and the blobs, nothing left counted.
        function clearAll(): void {
            Notifications.clearAll();
        }

        // Returns the new state, on or off.
        function toggleDnd(): string {
            Notifications.toggleDoNotDisturb();
            return Notifications.doNotDisturb ? "on" : "off";
        }

        function dnd(): string {
            return Notifications.doNotDisturb ? "on" : "off";
        }
    }
}
