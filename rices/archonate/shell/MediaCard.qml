// Desktop widget: what's playing. Cover art, title and artist, a wavy
// progress line that ripples while playing (click it to seek), and controls.
// Top left, under the windows; gone when no player is open.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "common"

Scope {
    id: root

    required property Theme theme
    required property Services services
    property bool shown: true

    readonly property MprisPlayer player: services.player
    readonly property bool playing: player?.isPlaying ?? false
    property real position: 0
    readonly property real length: player?.length ?? 0
    readonly property real progress: length > 0 ? Math.min(1, position / length) : 0

    function fmt(s: real): string {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    // MPRIS doesn't push the position; ask for it while playing
    Timer {
        running: root.shown && root.player !== null
        repeat: true
        triggeredOnStart: true
        interval: 1000
        onTriggered: {
            root.player.positionChanged();
            root.position = root.player.position;
        }
    }

    Variants {
        model: root.shown && root.player ? Quickshell.screens : []

        PanelWindow {
            required property var modelData

            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-card"
            exclusionMode: ExclusionMode.Normal
            anchors {
                top: true
                left: true
            }
            margins {
                top: 22
                left: 24
            }
            implicitWidth: 470
            implicitHeight: 172
            color: "transparent"

            Rectangle {
                anchors.fill: parent
                radius: root.theme.radius + 2
                color: Qt.alpha(root.theme.bg, 0.86)
                border.width: 1
                border.color: Qt.alpha(root.theme.accent, 0.3)

                // cover
                Rectangle {
                    id: cover

                    x: 14
                    y: 14
                    width: parent.height - 28
                    height: width
                    radius: root.theme.radius - 2
                    color: root.theme.surfaceHi
                    clip: true

                    Image {
                        anchors.fill: parent
                        source: root.player?.trackArtUrl ?? ""
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        sourceSize.width: 288
                        sourceSize.height: 288
                    }
                    Icon {
                        anchors.centerIn: parent
                        visible: !(root.player?.trackArtUrl)
                        name: "music_note"
                        size: 40
                        color: root.theme.textDim
                    }
                }

                Item {
                    anchors.left: cover.right
                    anchors.leftMargin: 16
                    anchors.right: parent.right
                    anchors.rightMargin: 16
                    anchors.top: cover.top
                    anchors.bottom: cover.bottom

                    Column {
                        width: parent.width
                        spacing: 3

                        Text {
                            width: parent.width
                            text: root.player?.trackTitle || "Nothing playing"
                            color: root.theme.text
                            font.family: root.theme.font
                            font.pixelSize: 16
                            font.bold: true
                            elide: Text.ElideRight
                        }
                        Text {
                            width: parent.width
                            text: root.player?.trackArtist ?? ""
                            color: root.theme.textDim
                            font.family: root.theme.font
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                    }

                    // wavy progress: a ripple for what's played, a hairline for the rest
                    Canvas {
                        id: wave

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: controls.top
                        anchors.bottomMargin: 8
                        height: 16

                        property real phase: 0
                        property real p: root.progress
                        property color a: root.theme.accent
                        property color dim: Qt.alpha(root.theme.text, 0.18)
                        onPChanged: requestPaint()
                        onPhaseChanged: requestPaint()
                        onAChanged: requestPaint()

                        NumberAnimation on phase {
                            running: root.playing && root.shown
                            from: 0
                            to: Math.PI * 2
                            duration: 1400
                            loops: Animation.Infinite
                        }

                        onPaint: {
                            const ctx = getContext("2d");
                            ctx.reset();
                            const mid = height / 2, end = width * p;
                            ctx.lineWidth = 2;
                            ctx.lineCap = "round";
                            ctx.beginPath();
                            ctx.moveTo(0, mid);
                            for (let x = 0; x <= end; x += 2)
                                ctx.lineTo(x, mid + Math.sin(x / 4.2 - phase) * (root.playing ? 3.2 : 1.2));
                            ctx.strokeStyle = a;
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.moveTo(end + 4, mid);
                            ctx.lineTo(width, mid);
                            ctx.strokeStyle = dim;
                            ctx.stroke();
                            ctx.beginPath();
                            ctx.arc(end, mid, 4, 0, Math.PI * 2);
                            ctx.fillStyle = a;
                            ctx.fill();
                        }

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: root.player?.canSeek ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: m => {
                                if (root.player?.canSeek && root.length > 0) {
                                    root.player.position = root.length * Math.max(0, Math.min(1, m.x / width));
                                    root.position = root.player.position;
                                }
                            }
                        }
                    }

                    Item {
                        id: controls

                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        height: 30

                        Text {
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            text: root.fmt(root.position) + " / " + root.fmt(root.length)
                            color: root.theme.textDim
                            font.family: root.theme.font
                            font.pixelSize: 11
                        }
                        Row {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 14

                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "skip_previous"
                                size: 20
                                color: root.theme.text
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.services.media("prev")
                                }
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 30
                                height: 30
                                radius: 15
                                color: root.theme.accent

                                Icon {
                                    anchors.centerIn: parent
                                    name: root.playing ? "pause" : "play_arrow"
                                    fill: true
                                    size: 20
                                    color: root.theme.bg
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.services.media("toggle")
                                }
                            }
                            Icon {
                                anchors.verticalCenter: parent.verticalCenter
                                name: "skip_next"
                                size: 20
                                color: root.theme.text
                                MouseArea {
                                    anchors.fill: parent
                                    anchors.margins: -4
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: root.services.media("next")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
