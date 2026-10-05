pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

// Default output and input volume from PipeWire, live and without polling.
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

    // Hardware and virtual outputs, not application streams.
    readonly property var sinks: (Pipewire.nodes.values ?? []).filter(node => node.isSink && !node.isStream && node.audio !== null)

    function sinkLabel(node: PwNode): string {
        return node.nickname || node.description || node.name;
    }

    function setDefaultSink(node: PwNode) {
        if (node)
            Pipewire.preferredDefaultAudioSink = node;
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

    // Volume and mute of a node are only bound while a tracker holds it.
    PwObjectTracker {
        objects: [root.sink, root.source].filter(node => node !== null)
    }
}
