import QtQuick
import qs.Common
import qs.Services

DashboardCard {
    id: displayAudio

    readonly property string brightnessDevice: DisplayService.currentDevice || DisplayService.getDefaultDevice()
    readonly property var brightnessDeviceInfo: DisplayService.devices.find(device => device.name === displayAudio.brightnessDevice) ?? null
    readonly property int brightnessValue: {
        DisplayService.brightnessVersion;
        return displayAudio.brightnessDevice ? DisplayService.getDeviceBrightness(displayAudio.brightnessDevice) : 0;
    }

    readonly property var sink: AudioService.sink
    readonly property var source: AudioService.source

    title: I18n.trFor("dotfilesDashboard", "Display & audio")
    spacing: Theme.spacingM

    SliderRow {
        width: parent.width
        iconName: "brightness_6"
        label: I18n.trFor("dotfilesDashboard", "Brightness")
        available: DisplayService.brightnessAvailable && displayAudio.brightnessDevice.length > 0
        minimum: DisplayService.brightnessMinimum(displayAudio.brightnessDeviceInfo)
        maximum: DisplayService.brightnessMaximum(displayAudio.brightnessDeviceInfo)
        unit: DisplayService.brightnessUnit(displayAudio.brightnessDeviceInfo)
        value: displayAudio.brightnessValue
        onMoved: newValue => DisplayService.setBrightness(newValue, displayAudio.brightnessDevice, true)
    }

    Row {
        width: parent.width
        spacing: Theme.spacingL

        readonly property real columnWidth: (width - spacing) / 2

        SliderRow {
            width: parent.columnWidth
            iconName: AudioService.volumeIconName(displayAudio.sink)
            label: I18n.trFor("dotfilesDashboard", "Output")
            available: displayAudio.sink?.audio != null
            muted: displayAudio.sink?.audio?.muted ?? false
            showMuteButton: true
            muteIconName: displayAudio.sink?.audio?.muted ? "volume_off" : "volume_up"
            maximum: AudioService.sinkMaxVolume
            value: displayAudio.sink?.audio ? Math.round(displayAudio.sink.audio.volume * 100) : 0
            onMoved: newValue => {
                if (!displayAudio.sink?.audio)
                    return;
                SessionData.suppressOSDTemporarily();
                displayAudio.sink.audio.volume = newValue / 100;
                if (newValue > 0 && displayAudio.sink.audio.muted)
                    displayAudio.sink.audio.muted = false;
                AudioService.playVolumeChangeSoundIfEnabled();
            }
            onMuteToggled: {
                if (!displayAudio.sink?.audio)
                    return;
                SessionData.suppressOSDTemporarily();
                displayAudio.sink.audio.muted = !displayAudio.sink.audio.muted;
            }
        }

        SliderRow {
            width: parent.columnWidth
            iconName: displayAudio.source?.audio && !displayAudio.source.audio.muted ? "mic" : "mic_off"
            label: I18n.trFor("dotfilesDashboard", "Input")
            available: displayAudio.source?.audio != null
            muted: displayAudio.source?.audio?.muted ?? false
            showMuteButton: true
            muteIconName: displayAudio.source?.audio?.muted ? "mic_off" : "mic"
            value: displayAudio.source?.audio ? Math.round(displayAudio.source.audio.volume * 100) : 0
            onMoved: newValue => {
                if (!displayAudio.source?.audio)
                    return;
                SessionData.suppressOSDTemporarily();
                displayAudio.source.audio.volume = newValue / 100;
                if (newValue > 0 && displayAudio.source.audio.muted)
                    displayAudio.source.audio.muted = false;
            }
            onMuteToggled: {
                if (!displayAudio.source?.audio)
                    return;
                SessionData.suppressOSDTemporarily();
                displayAudio.source.audio.muted = !displayAudio.source.audio.muted;
            }
        }
    }
}
