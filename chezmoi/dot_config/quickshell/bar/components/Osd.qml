import QtQuick
import ".."
import "../services"

// The OSD body inside the collapsed island: an icon, a thin fill track and the
// value. Shell.osdKind says what it shows; the owner sets shown.
Item {
    id: osd

    property bool shown: false

    readonly property string kind: Shell.osdKind
    readonly property real value: {
        if (kind === "brightness")
            return Math.max(0, Brightness.percentage);
        if (kind === "mic")
            return Math.round(Audio.micVolume * 100);
        return Math.round(Audio.volume * 100);
    }
    readonly property bool muted: kind === "mic" ? Audio.micMuted : kind === "volume" ? Audio.muted : false
    readonly property string iconName: {
        if (kind === "brightness")
            return "brightness_medium";
        if (kind === "mic")
            return muted ? "mic_off" : "mic";
        return muted ? "volume_off" : "volume_up";
    }

    implicitWidth: Theme.osdWidth
    implicitHeight: Theme.islandHeight
    opacity: shown ? 1 : 0
    visible: opacity > 0

    Behavior on opacity {
        NumberAnimation {
            duration: osd.shown ? Motion.osdInDuration : Motion.osdOutDuration
            easing.type: osd.shown ? Motion.osdInEasing : Motion.osdOutEasing
        }
    }

    Accessible.role: Accessible.ProgressBar
    Accessible.name: kind === "brightness" ? "Brightness" : kind === "mic" ? "Microphone" : "Volume"
    Accessible.description: Math.round(value) + "%"

    Icon {
        id: icon

        objectName: "osdIcon"
        x: Theme.osdPadding
        anchors.verticalCenter: parent.verticalCenter
        name: osd.iconName
        fill: 1
    }

    FillTrack {
        objectName: "osdTrack"
        x: icon.x + icon.width + Theme.osdGap
        anchors.verticalCenter: parent.verticalCenter
        width: valueText.x - Theme.osdGap - x
        height: Theme.osdTrackHeight
        value: osd.value / 100
        trackColor: Colors.surfaceContainerHigh
        fillOpacity: osd.muted ? Theme.mutedOpacity : 1
        duration: Motion.osdInDuration
        easingType: Motion.osdInEasing
        // The first value arrives while the OSD fades in, still invisible.
        glideWhileHidden: true
    }

    Label {
        id: valueText

        objectName: "osdValue"
        x: osd.width - Theme.osdPadding - width
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.osdValueWidth
        horizontalAlignment: Text.AlignRight
        text: Math.round(osd.value) + "%"
        font.pixelSize: Theme.secondaryFontSize
        numeric: true
    }
}
