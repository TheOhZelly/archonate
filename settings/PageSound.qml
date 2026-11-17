// Sound through PipeWire: default output/input, their volumes, and a mixer
// for apps that are playing.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Pipewire

ColumnLayout {
    id: page

    readonly property var nodes: Pipewire.nodes.values.filter(n => n.audio)
    readonly property var outputs: nodes.filter(n => n.isSink && !n.isStream)
    readonly property var inputs: nodes.filter(n => !n.isSink && !n.isStream)
    // Playback streams (Spotify, browsers...), not recording ones
    readonly property var apps: nodes.filter(n => n.isStream && (n.properties?.["media.class"] ?? "").startsWith("Stream/Output"))

    spacing: 12

    // Volumes are only live for tracked nodes
    PwObjectTracker {
        objects: page.nodes
    }

    function label(n: var): string {
        return n.description || n.nickname || n.name;
    }

    component VolumeRow: RowLayout {
        id: vrow

        required property var node

        Layout.fillWidth: true
        spacing: 12

        Text {
            text: vrow.node?.audio?.muted ? "volume_off" : "volume_up"
            font.family: "Material Symbols Rounded"
            font.pixelSize: 22
            color: vrow.node?.audio?.muted ? App.dim : App.accent

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: vrow.node.audio.muted = !vrow.node.audio.muted
            }
            SFocus {
                radius: App.r(8)
                onActivated: vrow.node.audio.muted = !vrow.node.audio.muted
            }
        }
        SSlider {
            Layout.fillWidth: true
            value: vrow.node?.audio?.volume ?? 0
            onMoved: v => {
                vrow.node.audio.muted = false;
                vrow.node.audio.volume = v;
            }
        }
        SLabel {
            Layout.preferredWidth: 42
            horizontalAlignment: Text.AlignRight
            text: Math.round((vrow.node?.audio?.volume ?? 0) * 100) + "%"
            font.pixelSize: 13
        }
    }

    SHeading {
        text: "Sound"
    }

    SSection {
        title: "Output"
    }
    SCard {
        VolumeRow {
            visible: Pipewire.defaultAudioSink !== null
            node: Pipewire.defaultAudioSink
        }
        Repeater {
            model: page.outputs

            SListItem {
                required property var modelData

                icon: modelData.properties?.["device.icon-name"]?.includes("headset") || page.label(modelData).match(/head(set|phone)/i) ? "headphones" : "speaker"
                title: page.label(modelData)
                active: Pipewire.defaultAudioSink === modelData
                onClicked: Pipewire.preferredDefaultAudioSink = modelData
            }
        }
    }

    SSection {
        title: "Input"
    }
    SCard {
        VolumeRow {
            visible: Pipewire.defaultAudioSource !== null
            node: Pipewire.defaultAudioSource
        }
        Repeater {
            model: page.inputs

            SListItem {
                required property var modelData

                icon: "mic"
                title: page.label(modelData)
                active: Pipewire.defaultAudioSource === modelData
                onClicked: Pipewire.preferredDefaultAudioSource = modelData
            }
        }
        SNote {
            visible: page.inputs.length === 0
            text: "No microphones found."
        }
    }

    SSection {
        title: "Apps"
    }
    SCard {
        SNote {
            visible: page.apps.length === 0
            text: "Nothing is playing sound right now."
        }
        Repeater {
            model: page.apps

            ColumnLayout {
                id: app

                required property var modelData

                Layout.fillWidth: true
                spacing: 2

                SLabel {
                    text: app.modelData.properties?.["application.name"] || page.label(app.modelData)
                    font.pixelSize: 13
                    color: App.dim
                }
                VolumeRow {
                    node: app.modelData
                }
            }
        }
    }
}
