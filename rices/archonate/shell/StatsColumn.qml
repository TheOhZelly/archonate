// Desktop widget: a column of system numbers, bottom right, straight on the
// wallpaper. Accent ticks, a network sparkline, a disk bar.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "common"

Scope {
    id: root

    required property Theme theme
    required property SysStats stats
    property bool shown: true

    function uptime(s: real): string {
        const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
        return (d ? d + "d " : "") + h + "h " + String(m).padStart(2, "0") + "m";
    }

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
                right: true
            }
            margins {
                bottom: 18
                right: 18
            }
            implicitWidth: 268
            implicitHeight: col.implicitHeight + 28
            color: "transparent"
            mask: Region {}

            // a card like the media card's, so the numbers read on any wallpaper
            Rectangle {
                anchors.fill: parent
                radius: root.theme.radius + 2
                color: Qt.alpha(root.theme.bg, 0.86)
                border.width: 1
                border.color: Qt.alpha(root.theme.accent, 0.3)
            }

            component Stat: Item {
                id: st

                property string label
                property string value
                property color tick: root.theme.accent

                width: parent?.width ?? 0
                height: 18

                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 2
                    height: 11
                    color: st.tick
                }
                Text {
                    x: 10
                    anchors.verticalCenter: parent.verticalCenter
                    text: st.label
                    color: root.theme.text
                    opacity: 0.8
                    font.family: root.theme.font
                    font.pixelSize: 11
                    style: Text.Raised
                    styleColor: Qt.alpha("#000000", 0.5)
                }
                Text {
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    text: st.value
                    color: root.theme.text
                    font.family: root.theme.font
                    font.pixelSize: 11
                    font.bold: true
                    style: Text.Raised
                    styleColor: Qt.alpha("#000000", 0.5)
                }
            }
            component Gap: Item {
                width: 1
                height: 12
            }

            Column {
                id: col

                x: 16
                y: 14
                width: parent.width - 32

                Stat {
                    label: "CPU"
                    value: Math.round(root.stats.cpu * 100) + "%"
                }
                Stat {
                    visible: root.stats.cpuTemp > 0
                    label: "CPU temp"
                    value: Math.round(root.stats.cpuTemp) + " °C"
                }
                Stat {
                    visible: root.stats.gpu >= 0
                    label: "GPU"
                    value: Math.round(root.stats.gpu * 100) + "%"
                }
                Stat {
                    visible: root.stats.gpuTemp > 0
                    label: "GPU temp"
                    value: Math.round(root.stats.gpuTemp) + " °C"
                }
                Stat {
                    label: "Memory"
                    value: root.stats.memUsedGiB.toFixed(1) + " / " + Math.round(root.stats.memTotalGiB) + " GiB"
                }

                Gap {}

                // network sparkline
                Canvas {
                    id: spark

                    width: parent.width
                    height: 46
                    property var h: root.stats.netHist
                    property color a: root.theme.accent
                    onHChanged: requestPaint()
                    onAChanged: requestPaint()

                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        if (h.length < 2)
                            return;
                        const max = Math.max(1024, ...h);
                        const dx = width / (root.stats.histLen - 1);
                        const x0 = width - (h.length - 1) * dx;
                        ctx.beginPath();
                        h.forEach((v, i) => {
                            const x = x0 + i * dx, y = height - 2 - v / max * (height - 6);
                            i ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
                        });
                        ctx.strokeStyle = a;
                        ctx.lineWidth = 1.3;
                        ctx.stroke();
                        ctx.lineTo(width, height);
                        ctx.lineTo(x0, height);
                        ctx.closePath();
                        ctx.fillStyle = Qt.alpha(a, 0.14);
                        ctx.fill();
                    }
                }
                Stat {
                    label: "Download"
                    value: root.stats.human(root.stats.rxRate) + "/s"
                    tick: root.theme.accent2
                }
                Stat {
                    label: "Upload"
                    value: root.stats.human(root.stats.txRate) + "/s"
                    tick: root.theme.accent2
                }

                Gap {}

                // disk
                Item {
                    width: parent.width
                    height: 10
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: 4
                        radius: 2
                        color: Qt.alpha(root.theme.text, 0.15)
                    }
                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width * (root.stats.diskTotal ? root.stats.diskUsed / root.stats.diskTotal : 0)
                        height: 4
                        radius: 2
                        color: root.theme.accent
                    }
                }
                Stat {
                    label: "Disk"
                    value: root.stats.human(root.stats.diskUsed) + " / " + root.stats.human(root.stats.diskTotal)
                    tick: root.theme.hot
                }
                Stat {
                    label: "Uptime"
                    value: root.uptime(root.stats.uptime)
                    tick: root.theme.hot
                }
            }
        }
    }
}
