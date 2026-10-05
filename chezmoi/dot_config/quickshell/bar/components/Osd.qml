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
            easing.type: osd.shown ? Easing.OutCubic : Easing.InCubic
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

    Rectangle {
        id: track

        objectName: "osdTrack"
        x: icon.x + icon.width + Theme.osdGap
        anchors.verticalCenter: parent.verticalCenter
        width: valueText.x - Theme.osdGap - x
        height: Theme.osdTrackHeight
        radius: height / 2
        color: Colors.surfaceContainerHigh

        Rectangle {
            objectName: "osdFill"
            width: parent.width * Math.min(100, osd.value) / 100
            height: parent.height
            radius: parent.radius
            color: Colors.primary
            opacity: osd.muted ? 0.4 : 1

            Behavior on width {
                NumberAnimation {
                    duration: Motion.osdInDuration
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    Text {
        id: valueText

        objectName: "osdValue"
        x: osd.width - Theme.osdPadding - width
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.osdValueWidth
        horizontalAlignment: Text.AlignRight
        text: Math.round(osd.value) + "%"
        color: Colors.foreground
        font.family: Theme.fontFamily
        font.pixelSize: Theme.secondaryFontSize
        font.weight: Theme.fontWeight
        font.features: ({
                tnum: 1
            })
    }
}
