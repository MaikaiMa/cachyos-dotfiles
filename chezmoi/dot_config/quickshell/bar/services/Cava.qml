pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import ".."

// Audio levels and the one animation clock for the orb, the music bar's rim
// and the top-edge wave. cava runs only while a player plays; the clock runs
// while a player exists or the wave is still fading out, never under reduce motion.
Singleton {
    id: root

    readonly property int bandCount: 24
    readonly property string configDir: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/dotfiles-bar"
    readonly property string configPath: configDir + "/cava.conf"
    readonly property string config: ["[general]", "bars = " + bandCount, "framerate = 30", "autosens = 1", "sleep_timer = 1", "", "[input]", "method = pipewire", "source = auto", "", "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 100", "bar_delimiter = 59", "frame_delimiter = 10", "channels = mono", "mono_option = average", ""].join("\n")

    property bool configReady: false
    readonly property bool running: configReady && Music.hasPlayer && Music.playing && !Motion.reduceMotion

    // Raw frames from cava, 0..1 each.
    property var bands: zeros()
    // Smoothed on every tick with the audio attack and release, 0..1.
    property var smoothBands: zeros()
    property real level: 0
    // Mean of the four lowest bands.
    property real low: 0

    // Shared by every orb and music bar: angles in degrees, rates in turns per
    // second. spin eases between 0 (paused, the rims stand still) and 1 (playing).
    property real spin: 0
    readonly property real spinEased: spin * spin * (3 - 2 * spin)
    property real orbLevelRate: 1000 / Motion.rimTurnRest
    property real barLevelRate: 1000 / Motion.barRimTurnRest
    property real playerLevelRate: 1000 / Motion.playerRimTurnRest
    readonly property real rimRate: orbLevelRate * spinEased
    readonly property real barRimRate: barLevelRate * spinEased
    readonly property real playerRimRate: playerLevelRate * spinEased
    property real rimAngle: 0
    property real barRimAngle: 0
    property real playerRimAngle: 0
    property real animatedBloom: Theme.bloomQuiet
    readonly property real bloom: animating ? animatedBloom : 0.2
    // The resting orb's ring breathes while paused: ringSwell runs 0 to 1 and back
    // once per period and carries its opacity and diameter. Reduce motion holds it
    // at the middle.
    property real ringPhase: 0
    readonly property real ringSwell: animating ? (1 - Math.cos(2 * Math.PI * ringPhase)) / 2 : 0.5
    readonly property real ringBreath: Theme.orbRingMin + (Theme.orbRingMax - Theme.orbRingMin) * ringSwell

    // The wave fades in while playback runs and out after it stops; every
    // screen's wave draws at this opacity.
    readonly property bool waveOn: Theme.topWaveEnabled && Music.hasPlayer && Music.playing && !Motion.reduceMotion
    property real waveOpacity: waveOn ? Theme.wavePeakOpacity : 0

    Behavior on waveOpacity {
        NumberAnimation {
            duration: root.waveOn ? Motion.waveInDuration : Motion.waveOutDuration
            easing.type: Easing.OutCubic
        }
    }

    readonly property bool animating: !Motion.reduceMotion && (Music.hasPlayer || waveOpacity > 0)
    readonly property bool fast: Music.playing || waveOpacity > 0

    // After each step; the wave repaints on it.
    signal tick(real dt)

    function zeros(): var {
        return new Array(bandCount).fill(0);
    }

    function approach(current: real, target: real, dt: real, tau: real): real {
        return tau <= 0 ? target : current + (target - current) * (1 - Math.exp(-dt / tau));
    }

    function follow(current: real, target: real, dt: real): real {
        return approach(current, target, dt, target > current ? Motion.audioAttack : Motion.audioRelease);
    }

    // One frame: "12;0;57;...;" with values 0..100.
    function parseFrame(line: string) {
        const values = line.split(";").filter(field => field !== "").map(field => Math.max(0, Math.min(1, Number(field) / 100 || 0)));
        if (values.length === bandCount)
            bands = values;
    }

    // Turns per second for a turn time at rest and one at full level.
    function levelRate(restMs: real, fullMs: real): real {
        return 1000 / restMs + (1000 / fullMs - 1000 / restMs) * level;
    }

    // dt in milliseconds.
    function step(dt: real) {
        const raw = bands;
        smoothBands = smoothBands.map((value, index) => follow(value, raw[index], dt));
        level = follow(level, raw.reduce((sum, band) => sum + band, 0) / bandCount, dt);
        low = follow(low, (raw[0] + raw[1] + raw[2] + raw[3]) / 4, dt);

        spin = Math.max(0, Math.min(1, spin + (Music.playing ? dt : -dt) / Motion.rimEaseDuration));
        orbLevelRate = approach(orbLevelRate, levelRate(Motion.rimTurnRest, Motion.rimTurnFull), dt, Motion.rimRateSettle);
        barLevelRate = approach(barLevelRate, levelRate(Motion.barRimTurnRest, Motion.barRimTurnFull), dt, Motion.rimRateSettle);
        rimAngle = (rimAngle + 360 * rimRate * dt / 1000) % 360;
        playerLevelRate = approach(playerLevelRate, levelRate(Motion.playerRimTurnRest, Motion.playerRimTurnFull), dt, Motion.rimRateSettle);
        barRimAngle = (barRimAngle + 360 * barRimRate * dt / 1000) % 360;
        playerRimAngle = (playerRimAngle + 360 * playerRimRate * dt / 1000) % 360;

        animatedBloom = follow(animatedBloom, Theme.bloomQuiet + (Theme.bloomLoud - Theme.bloomQuiet) * low, dt);
        ringPhase = (ringPhase + dt / Motion.orbRingBreathPeriod) % 1;
        tick(dt);
    }

    onRunningChanged: {
        if (!running)
            bands = zeros();
    }

    // Reduce motion stops the clock: a still rim, a steady bloom, no levels.
    onAnimatingChanged: {
        if (animating)
            return;
        smoothBands = zeros();
        level = 0;
        low = 0;
    }

    Timer {
        property real last: 0

        interval: root.fast ? Motion.audioFrameInterval : Motion.audioPausedInterval
        repeat: true
        running: root.animating
        onRunningChanged: last = Date.now()
        onTriggered: {
            const now = Date.now();
            // A stalled loop must not throw the rim forward.
            const dt = Math.min(250, Math.max(0, now - last));
            last = now;
            root.step(dt);
        }
    }

    Process {
        command: ["sh", "-c", "mkdir -p \"$1\" && printf '%s' \"$2\" > \"$1/cava.conf\"", "sh", root.configDir, root.config]
        running: true
        // QProcess::ExitStatus is not exposed to qmllint.
        onExited: code => { // qmllint disable signal-handler-parameters
            if (code === 0)
                root.configReady = true;
            else
                console.warn("Cava: cannot write " + root.configPath);
        }
    }

    Process {
        command: ["cava", "-p", root.configPath]
        running: root.running
        stdout: SplitParser {
            onRead: line => root.parseFrame(line)
        }
    }
}
