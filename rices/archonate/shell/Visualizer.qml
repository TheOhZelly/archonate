// Desktop widget: the spectrum as tall rounded bars in a dark card, bottom
// left, under the windows. Fades back when nothing is playing.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "common"

Scope {
    id: root

    required property Theme theme
    required property Cava cava
    required property Services services
    property bool shown: true
    readonly property bool playing: services.player?.isPlaying ?? false
    readonly property int bars: 36

    Variants {
        model: root.shown ? Quickshell.screens : []

        PanelWindow {
            required property var modelData

            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-widget"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                bottom: true
                left: true
            }
            margins {
                bottom: 18
                left: 18
            }
            implicitWidth: Math.round(modelData.width * 0.34)
            implicitHeight: Math.round(implicitWidth * 0.4)
            color: "transparent"
            mask: Region {}

            // Only while something plays: an idle card reads as a broken one
            Rectangle {
                anchors.fill: parent
                radius: root.theme.radius
                color: Qt.alpha(root.theme.bg, 0.86)
                border.width: 1
                border.color: Qt.alpha(root.theme.accent, 0.3)
                opacity: root.playing ? 1 : 0
                visible: opacity > 0

                Behavior on opacity {
                    NumberAnimation {
                        duration: 500
                        easing.type: Easing.InOutQuad
                    }
                }

                Row {
                    id: barsRow

                    anchors.fill: parent
                    anchors.margins: 14
                    anchors.bottomMargin: 12
                    spacing: Math.max(3, width / root.bars * 0.42)

                    Repeater {
                        model: root.bars

                        Rectangle {
                            required property int index
                            // spread 36 bars over cava's 48, skipping the top end
                            readonly property real v: root.cava.bars[Math.round(index * 40 / root.bars)] ?? 0

                            anchors.bottom: parent.bottom
                            width: (barsRow.width - barsRow.spacing * (root.bars - 1)) / root.bars
                            height: Math.max(4, v * barsRow.height)
                            radius: Math.min(3, width / 2)
                            gradient: Gradient {
                                GradientStop {
                                    position: 0
                                    color: root.theme.accent2
                                }
                                GradientStop {
                                    position: 1
                                    color: Qt.alpha(root.theme.accent, 0.85)
                                }
                            }

                            Behavior on height {
                                NumberAnimation {
                                    duration: 70
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
