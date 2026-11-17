// Sound: output volume, which speakers/headphones, the mic, and each app.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Pipewire

ColumnLayout {
    id: page

    readonly property var svc: Arch.services
    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var sinks: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var sources: nodes.filter(n => !n.isSink && !n.isStream)
    readonly property var streams: nodes.filter(n => n.isSink && n.isStream)
    readonly property PwNode mic: Pipewire.defaultAudioSource

    width: 344
    spacing: 10

    PwObjectTracker {
        objects: [...page.sinks, ...page.sources, ...page.streams]
    }

    QHeader {
        Layout.fillWidth: true
        icon: "volume_up"
        title: "Sound"
    }

    QSlider {
        Layout.fillWidth: true
        icon: page.svc?.volumeIcon ?? "volume_up"
        value: page.svc?.muted ? 0 : (page.svc?.volume ?? 0)
        onMoved: v => page.svc.setVolume(v)
        onIconClicked: page.svc.toggleMute()
    }
    QSlider {
        Layout.fillWidth: true
        visible: page.mic !== null
        icon: page.mic?.audio?.muted ? "mic_off" : "mic"
        value: page.mic?.audio?.muted ? 0 : (page.mic?.audio?.volume ?? 0)
        onMoved: v => {
            page.mic.audio.muted = false;
            page.mic.audio.volume = v;
        }
        onIconClicked: page.mic.audio.muted = !page.mic.audio.muted
    }

    QText {
        text: Arch.caps("Output")
        dim: true
        size: (Arch.theme?.fontSize ?? 13) - 1
        topPadding: 4
    }
    Repeater {
        model: page.sinks

        QItem {
            required property var modelData

            Layout.fillWidth: true
            icon: modelData.name.includes("bluez") ? "headphones" : "speaker"
            title: modelData.description || modelData.nickname || modelData.name
            active: Pipewire.defaultAudioSink === modelData
            onClicked: Pipewire.preferredDefaultAudioSink = modelData
        }
    }

    QText {
        visible: page.streams.length > 0
        text: Arch.caps("Apps")
        dim: true
        size: (Arch.theme?.fontSize ?? 13) - 1
        topPadding: 4
    }
    Repeater {
        model: page.streams.slice(0, 5)

        ColumnLayout {
            required property var modelData

            Layout.fillWidth: true
            spacing: 0

            QText {
                Layout.fillWidth: true
                text: modelData.properties["application.name"] ?? modelData.description ?? modelData.name
                size: (Arch.theme?.fontSize ?? 13) - 1
            }
            QSlider {
                Layout.fillWidth: true
                icon: modelData.audio?.muted ? "volume_off" : "graphic_eq"
                value: modelData.audio?.muted ? 0 : (modelData.audio?.volume ?? 0)
                onMoved: v => {
                    modelData.audio.muted = false;
                    modelData.audio.volume = v;
                }
                onIconClicked: modelData.audio.muted = !modelData.audio.muted
            }
        }
    }

    QLink {
        Layout.fillWidth: true
        text: "Sound settings"
        page: "sound"
    }
}
