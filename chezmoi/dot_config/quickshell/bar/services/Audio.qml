pragma ComponentBehavior: Bound
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Default output and input volume from PipeWire, live and without polling. For
// the Sound panel also the outputs and inputs with the name of their active
// port ("Speakers", "Headphones"), which Quickshell does not expose, from
// `pactl -f json` read at start, on node changes and on pactl's own change
// events while the panel is open; the default input's level and the playback
// streams grouped per application, both only while the panel is open.
Singleton {
    id: root

    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property PwNode source: Pipewire.defaultAudioSource
    readonly property bool ready: Pipewire.ready && sink !== null

    // 0..1
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property real micVolume: source && source.audio ? source.audio.volume : 0
    readonly property bool micMuted: source && source.audio ? source.audio.muted : false

    readonly property bool panelOpen: Shell.centreState === "sound"

    readonly property var nodes: Pipewire.nodes.values ?? []
    // Hardware and virtual outputs and inputs, not application streams, in a
    // stable order so a click never moves a row.
    readonly property var sinks: nodes.filter(node => node.isSink && !node.isStream && node.audio !== null).sort(byLabel)
    readonly property var sources: nodes.filter(node => !node.isSink && !node.isStream && node.audio !== null && (node.type & PwNodeType.AudioSource) === PwNodeType.AudioSource).sort(byLabel)
    // Playback streams of applications. Capture streams (the bar's own cava
    // reads a sink monitor) and monitors are never here.
    readonly property var playbackStreams: nodes.filter(node => node.isStream && node.audio !== null && (node.type & PwNodeType.AudioOutStream) === PwNodeType.AudioOutStream && !isMonitor(node))

    // node name -> { label, portType } from pactl.
    property var ports: ({})

    // One entry per application: { key, name, icon, nodes }. Properties are only
    // bound while the tracker below holds the streams, that is while the panel is
    // open; until then every stream falls back to its node name.
    readonly property var appStreams: {
        const groups = [];
        for (const node of playbackStreams) {
            const properties = node.properties ?? {};
            const key = properties["application.name"] || properties["media.name"] || node.name;
            let group = groups.find(entry => entry.key === key);
            if (!group) {
                group = {
                    key: key,
                    name: appLabel(key),
                    icon: appIcon(properties),
                    nodes: []
                };
                groups.push(group);
            }
            group.nodes.push(node);
        }
        return groups.sort((a, b) => a.name.localeCompare(b.name));
    }

    // 0..1, the default input's peak on a -60..0 dB scale; 0 while the panel is closed.
    readonly property real micLevel: {
        const peak = peakMonitor.peak;
        if (!panelOpen || !(peak > 0))
            return 0;
        return clamp((20 * Math.log10(peak) + 60) / 60);
    }

    function flag(node: PwNode, key: string): bool {
        return String((node.properties ?? {})[key]) === "true";
    }

    function isMonitor(node: PwNode): bool {
        return flag(node, "stream.monitor") || flag(node, "stream.capture.sink");
    }

    function byLabel(a: PwNode, b: PwNode): int {
        return sinkLabel(a).localeCompare(sinkLabel(b)) || a.name.localeCompare(b.name);
    }

    // The active port's name when pactl knows the node; otherwise the device for
    // Bluetooth, a generic name for HDMI and the internal card, else PipeWire's
    // description.
    function sinkLabel(node: PwNode): string {
        if (!node)
            return "";
        const name = node.name ?? "";
        if (name.startsWith("bluez_"))
            return node.description || node.nickname || name;
        const port = ports[name];
        if (port && port.label)
            return port.label;
        if (/hdmi/i.test(name))
            return "HDMI / DisplayPort";
        if (name.startsWith("alsa_output.") && /analog/.test(name))
            return "Speakers";
        if (name.startsWith("alsa_input.") && /analog/.test(name))
            return "Microphone";
        return node.description || node.nickname || name;
    }

    // speaker, headphones, bluetooth_audio or tv for outputs; mic or headset_mic for inputs.
    function deviceIcon(node: PwNode): string {
        const name = node ? node.name ?? "" : "";
        const portType = (ports[name] ?? {}).portType ?? "";
        const bluetooth = name.startsWith("bluez_");
        if (node && !node.isSink)
            return bluetooth || portType === "Headset" ? "headset_mic" : "mic";
        if (bluetooth)
            return "bluetooth_audio";
        if (portType === "HDMI" || portType === "DisplayPort" || /hdmi/i.test(name))
            return "tv";
        if (portType === "Headphones" || portType === "Headset")
            return "headphones";
        return "speaker";
    }

    // ALSA clients through pipewire-alsa all call themselves "PipeWire ALSA [x]",
    // with the node name alsa_playback.x before the tracker binds their properties.
    function appLabel(key: string): string {
        const alsa = /^PipeWire ALSA \[(.+)\]$/.exec(key) ?? /^alsa_playback\.(.+)$/.exec(key);
        const name = alsa ? alsa[1] : key;
        return name.charAt(0).toUpperCase() + name.slice(1);
    }

    // A themed icon path or "" for the generic glyph.
    function appIcon(properties: var): string {
        const candidates = [properties["application.icon-name"], properties["application.process.binary"], String(properties["application.name"] ?? "").toLowerCase()];
        for (const candidate of candidates) {
            if (!candidate)
                continue;
            const path = Quickshell.iconPath(candidate, true);
            if (path)
                return path;
        }
        return "";
    }

    function appGroup(key: string): var {
        return appStreams.find(group => group.key === key) ?? null;
    }

    function groupVolume(group: var): real {
        if (!group)
            return 0;
        return group.nodes.reduce((highest, node) => Math.max(highest, node.audio ? node.audio.volume : 0), 0);
    }

    function groupMuted(group: var): bool {
        return group !== null && group.nodes.length > 0 && group.nodes.every(node => node.audio && node.audio.muted);
    }

    function setDefaultSink(node: PwNode) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
    }

    function setDefaultSource(node: PwNode) {
        if (node)
            Pipewire.preferredDefaultAudioSource = node;
    }

    function clamp(value: real): real {
        return Math.max(0, Math.min(1, value));
    }

    function setVolume(value: real) {
        if (sink && sink.audio)
            sink.audio.volume = clamp(value);
    }

    function toggleMute() {
        if (sink && sink.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    function setMicVolume(value: real) {
        if (source && source.audio)
            source.audio.volume = clamp(value);
    }

    function toggleMicMute() {
        if (source && source.audio)
            source.audio.muted = !source.audio.muted;
    }

    // Every stream of the application moves together.
    function setGroupVolume(group: var, value: real) {
        if (!group)
            return;
        for (const node of group.nodes) {
            if (node.audio)
                node.audio.volume = clamp(value);
        }
    }

    function toggleGroupMute(group: var) {
        if (!group)
            return;
        const mute = !groupMuted(group);
        for (const node of group.nodes) {
            if (node.audio)
                node.audio.muted = mute;
        }
    }

    function readPorts() {
        if (portReader.running)
            portReader.pending = true;
        else
            portReader.running = true;
    }

    // pactl -f json list sinks / sources: name, active_port, ports[].description and type.
    function parsePorts(sinksJson: string, sourcesJson: string) {
        const next = {};
        for (const text of [sinksJson, sourcesJson]) {
            let entries = [];
            try {
                entries = JSON.parse(text);
            } catch (error) {
                console.warn("Audio: cannot parse pactl output: " + error);
                continue;
            }
            for (const entry of entries) {
                const port = (entry.ports ?? []).find(candidate => candidate.name === entry.active_port);
                if (port)
                    next[entry.name] = {
                        label: port.description ?? "",
                        portType: port.type ?? ""
                    };
            }
        }
        ports = next;
    }

    Component.onCompleted: readPorts()
    onPanelOpenChanged: {
        if (panelOpen)
            readPorts();
    }

    Connections {
        target: Pipewire.nodes

        function onValuesChanged() {
            root.readPorts();
        }
    }

    // Both lists in one run, separated by a line pactl never prints.
    Process {
        id: portReader

        property bool pending: false

        command: ["sh", "-c", "pactl -f json list sinks && printf '\\n---ports---\\n' && pactl -f json list sources"]
        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("\n---ports---\n");
                if (parts.length === 2)
                    root.parsePorts(parts[0], parts[1]);
            }
        }
        onRunningChanged: {
            if (!running && pending) {
                pending = false;
                running = true;
            }
        }
    }

    // A jack plug moves the port without touching the nodes; pactl reports it.
    Process {
        command: ["pactl", "subscribe"]
        running: root.panelOpen
        stdout: SplitParser {
            onRead: data => {
                if (/on (sink|source|card) /.test(data))
                    portDebounce.restart();
            }
        }
    }

    Timer {
        id: portDebounce

        interval: 300
        onTriggered: root.readPorts()
    }

    PwNodePeakMonitor {
        id: peakMonitor

        node: root.source
        enabled: root.panelOpen && root.source !== null
    }

    // Volume, mute and properties of a node are only bound while a tracker holds
    // it: the defaults always, the playback streams while the panel is open.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node !== null).concat(root.panelOpen ? root.playbackStreams : [])
    }
}
