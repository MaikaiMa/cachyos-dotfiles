pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Microphone, camera and screen share in use, and the apps behind them.
// Structural checks, not name lists: a capture stream counts when it is linked
// from a microphone or camera device, a share when Niri reports an active cast.
// Apps that open the webcam directly (browsers, Electron) bypass PipeWire, so
// the webcam's USB power state gates a scan of /proc for /dev/video holders.
Singleton {
    id: root

    // Deduplicated display names.
    readonly property var micApps: unique(micStreams.map(node => appName(node)))
    readonly property var cameraApps: unique(cameraStreams.map(node => appName(node)).concat(cameraHolders.map(holder => holder.comm)))
    readonly property var shareApps: shareActive ? unique(activeCasts.reduce((names, cast) => names.concat(castApps(cast)), [])) : []
    readonly property bool micActive: micApps.length > 0
    readonly property bool cameraActive: cameraApps.length > 0
    // Follows activeCasts after 500 ms without change, so a short screencopy does not flash.
    property bool shareActive: false
    readonly property bool anyActive: micActive || cameraActive || shareActive

    // Inputs: the PipeWire graph and Niri's casts.
    readonly property var nodes: Pipewire.nodes.values
    readonly property var links: Pipewire.links.values
    readonly property var casts: Niri.casts

    readonly property var streams: nodes.filter(node => isCaptureOrCast(node))
    readonly property var liveLinks: links.filter(link => link.source && link.target && (link.state === PwLinkState.Active || link.state === PwLinkState.Paused))
    // A paused link counts: an app muted in its own UI keeps its stream open.
    readonly property var micStreams: streams.filter(node => (node.type & PwNodeType.AudioInStream) === PwNodeType.AudioInStream && !isMonitor(node) && liveLinks.some(link => link.target.id === node.id && isMicDevice(link.source)))
    readonly property var cameraStreams: streams.filter(node => (node.type & PwNodeType.Video) === PwNodeType.Video && liveLinks.some(link => link.target.id === node.id && isCameraDevice(link.source)))
    readonly property var activeCasts: casts.filter(cast => cast.is_active === true)
    readonly property bool shareWanted: activeCasts.length > 0

    // USB devices behind /dev/video*, their runtime power state, and who holds a node.
    property var cameraDevices: []
    property var deviceStatus: ({})
    readonly property bool cameraAwake: Object.values(deviceStatus).some(status => status !== "suspended")
    property var cameraHolders: []
    // Process names of the active casts' clients.
    property var commByPid: ({})
    // A camera plugged in later appears as a new device node; the USB devices
    // are probed again then.
    readonly property string cameraNodes: nodes.filter(node => isCameraDevice(node)).map(node => node.name).sort().join(" ")

    // Capture streams and Niri's cast output; playback streams are never bound.
    function isCaptureOrCast(node: var): bool {
        return node.isStream && (node.type & PwNodeType.AudioOutStream) !== PwNodeType.AudioOutStream;
    }

    function flag(node: var, key: string): bool {
        const properties = node.properties ?? {};
        return String(properties[key]) === "true";
    }

    // Peak meters, pavucontrol and cava read a sink monitor or flag themselves.
    function isMonitor(node: var): bool {
        return flag(node, "stream.monitor") || flag(node, "stream.capture.sink") || flag(node, "node.passive");
    }

    // A hardware or virtual source; a sink (its monitor) or another stream is not.
    function isMicDevice(node: var): bool {
        return !node.isStream && (node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource;
    }

    // WirePlumber's camera nodes; Niri's cast node is a stream and never matches.
    function isCameraDevice(node: var): bool {
        return !node.isStream && (node.type & PwNodeType.VideoSource) === PwNodeType.VideoSource && /^(v4l2|libcamera)_input\./.test(node.name);
    }

    function appName(node: var): string {
        const properties = node.properties ?? {};
        return properties["application.name"] || properties["media.name"] || node.description || node.name || "";
    }

    // The consumer linked from the cast's PipeWire node, else the client Niri names.
    function castApps(cast: var): var {
        const consumers = cast.pw_node_id === null || cast.pw_node_id === undefined ? [] : liveLinks.filter(link => link.source.id === cast.pw_node_id).map(link => appName(link.target));
        if (consumers.length > 0)
            return consumers;
        const comm = commByPid[cast.pid];
        return [comm ? comm : "Screen"];
    }

    function unique(names: var): var {
        return names.filter((name, index) => name !== "" && names.indexOf(name) === index);
    }

    function setDeviceStatus(device: string, status: string) {
        if (deviceStatus[device] === status)
            return;
        const next = Object.assign({}, deviceStatus);
        next[device] = status;
        deviceStatus = next;
    }

    // Lines of "pid comm"; PipeWire's own hold is the PipeWire path above.
    function parseHolders(text: string) {
        if (!cameraAwake)
            return;
        cameraHolders = text.split("\n").map(line => {
            const space = line.indexOf(" ");
            return {
                pid: Number(line.slice(0, space)),
                comm: line.slice(space + 1).trim()
            };
        }).filter(holder => holder.pid > 0 && holder.comm !== "" && holder.comm !== "pipewire" && holder.comm !== "wireplumber");
    }

    // Only the pids of current casts stay: pids are reused over a long session.
    function parseComms(text: string) {
        const pids = activeCasts.map(cast => String(cast.pid));
        const next = {};
        for (const pid of Object.keys(commByPid)) {
            if (pids.includes(pid))
                next[pid] = commByPid[pid];
        }
        for (const line of text.split("\n")) {
            const space = line.indexOf(" ");
            if (space > 0 && line.slice(space + 1).trim() !== "")
                next[Number(line.slice(0, space))] = line.slice(space + 1).trim();
        }
        commByPid = next;
    }

    function readComms() {
        const pids = activeCasts.map(cast => cast.pid).filter(pid => typeof pid === "number" && commByPid[pid] === undefined);
        if (pids.length === 0)
            return;
        if (commReader.running) {
            internal.commPending = true;
            return;
        }
        commReader.command = ["sh", "-c", "for pid; do printf '%s %s\\n' \"$pid\" \"$(cat \"/proc/$pid/comm\" 2>/dev/null)\"; done", "sh"].concat(pids.map(String));
        commReader.run();
    }

    onShareWantedChanged: shareDebounce.restart()
    onCameraNodesChanged: deviceProbe.refresh()
    onActiveCastsChanged: readComms()
    onCameraAwakeChanged: {
        if (!cameraAwake)
            cameraHolders = [];
    }

    // Properties and link states stay empty until bound.
    PwObjectTracker {
        objects: Pipewire.nodes.values.filter(node => root.isCaptureOrCast(node))
    }

    PwObjectTracker {
        objects: Pipewire.links.values
    }

    Timer {
        id: shareDebounce

        interval: 500
        onTriggered: root.shareActive = root.shareWanted
    }

    QtObject {
        id: internal

        property bool commPending: false
    }

    // Read at start.
    CommandReader {
        id: deviceProbe

        name: "Privacy"
        command: ["sh", "-c", "for node in /sys/class/video4linux/video*; do [ -e \"$node/device\" ] || continue; usb=$(readlink -f \"$node/device/..\"); [ -f \"$usb/idVendor\" ] && [ -f \"$usb/power/runtime_status\" ] && printf '%s\\n' \"$usb\"; done | sort -u"]
        onRead: text => root.cameraDevices = text.split("\n").filter(line => line !== "")
    }

    Instantiator {
        id: statusFiles

        model: root.cameraDevices

        FileView {
            required property string modelData

            path: modelData + "/power/runtime_status"
            printErrors: false
            onLoaded: root.setDeviceStatus(modelData, text().trim())
        }
    }

    // An in-process sysfs read; any open of the webcam wakes it within 2 s.
    Timer {
        interval: 2000
        repeat: true
        running: root.cameraDevices.length > 0
        onTriggered: {
            for (let index = 0; index < statusFiles.count; index++)
                statusFiles.objectAt(index).reload();
        }
    }

    Timer {
        interval: 4000
        repeat: true
        triggeredOnStart: true
        running: root.cameraAwake
        onTriggered: holderScan.running = true
    }

    Process {
        id: holderScan

        command: ["sh", "-c", "find /proc/[0-9]*/fd -lname '/dev/video*' 2>/dev/null | cut -d/ -f3 | sort -u | while read -r pid; do printf '%s %s\\n' \"$pid\" \"$(cat \"/proc/$pid/comm\" 2>/dev/null)\"; done"]
        stdout: StdioCollector {
            onStreamFinished: root.parseHolders(text)
        }
    }

    Command {
        id: commReader

        onFinished: (code, output) => {
            root.parseComms(output);
            if (internal.commPending) {
                internal.commPending = false;
                root.readComms();
            }
        }
    }
}
