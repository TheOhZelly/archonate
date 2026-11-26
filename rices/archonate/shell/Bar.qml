// archonate bar: a notch hanging from the top edge, with curved shoulders, over a
// hairline that runs the width of the screen and ripples with the music.
// Inside, dense and terse: the A (menu), workspaces, cpu and memory, the
// clock, now playing, tray and status. Everything leads to a quick panel.
import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import "common"

PanelWindow {
    id: bar

    required property var modelData
    required property Theme theme
    required property Services services
    required property Notifs notifs
    required property Cava cava
    required property SysStats stats
    required property var cfg // the Desktop's Settings (riceVal); untyped: the typed form fails to cross the import
    property bool autoHide: false // gaming mode: hide over fullscreen windows

    // Settings > Bar (per rice, live)
    readonly property bool clock24: cfg.riceVal("barClock24", true)
    readonly property bool showSeconds: cfg.riceVal("barSeconds", false)
    readonly property bool showDate: cfg.riceVal("barDate", true)
    readonly property bool showStats: cfg.riceVal("barStats", true)
    readonly property bool showMedia: cfg.riceVal("barMedia", true)
    readonly property bool showTray: cfg.riceVal("barTray", true)
    readonly property bool showVolume: cfg.riceVal("barVolume", true)
    readonly property bool showWave: cfg.riceVal("barWave", true)
    readonly property bool wsNumbers: cfg.riceVal("barWsNumbers", false)
    readonly property string timeFormat: (clock24 ? "HH:mm" : "h:mm") + (showSeconds ? ":ss" : "") + (clock24 ? "" : " AP")

    readonly property int notchH: 32
    readonly property int shoulder: 14
    readonly property int lineY: 13 // where the hairline runs

    visible: !(autoHide && (Hyprland.monitorFor(modelData)?.activeWorkspace?.hasFullscreen ?? false))

    screen: modelData
    WlrLayershell.namespace: "rice-bar"
    anchors {
        top: true
        left: true
        right: true
    }
    implicitHeight: notchH + 14
    exclusiveZone: notchH + 6
    color: "transparent"
    mask: Region {
        item: notch
    }

    component Label: Text {
        anchors.verticalCenter: parent?.verticalCenter
        color: bar.theme.text
        font.family: bar.theme.font
        font.pixelSize: 12
    }
    component Glyph: Icon {
        anchors.verticalCenter: parent?.verticalCenter
        color: bar.theme.text
        size: 15
    }
    component Sep: Rectangle {
        anchors.verticalCenter: parent?.verticalCenter
        width: 1
        height: 14
        color: Qt.alpha(bar.theme.text, 0.14)
    }

    // ---- the hairline, rippling with the spectrum -------------------------------
    Canvas {
        id: wave

        anchors.left: parent.left
        anchors.right: parent.right
        y: 0
        height: bar.lineY * 2 + 4
        visible: bar.showWave
        renderStrategy: Canvas.Cooperative

        property color stroke: bar.theme.accent
        property var bars: bar.cava.bars
        onStrokeChanged: requestPaint()
        onBarsChanged: requestPaint()
        onWidthChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            const W = width, mid = bar.lineY, n = bars.length;
            const step = 12;
            // Mirrored: bass at both edges, treble meeting under the notch.
            // Alternating peaks, drawn through their midpoints: a soft ripple.
            const pts = [];
            for (let x = 0, i = 0; x <= W + step; x += step, i++) {
                const d = Math.min(1, Math.abs(x - W / 2) / (W / 2)); // 0 centre .. 1 edge
                const b = bars[Math.min(n - 1, Math.floor((1 - d) * (n - 1)))] ?? 0;
                const amp = Math.pow(b, 1.3) * 7 * (0.4 + 0.6 * d);
                pts.push([x, mid + (i % 2 ? -amp : amp)]);
            }
            ctx.beginPath();
            ctx.moveTo(0, mid);
            for (let i = 1; i < pts.length - 1; i++)
                ctx.quadraticCurveTo(pts[i][0], pts[i][1], (pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2);
            ctx.strokeStyle = Qt.alpha(stroke, 0.75);
            ctx.lineWidth = 1.2;
            ctx.lineJoin = "round";
            ctx.stroke();
        }
    }

    // ---- the notch --------------------------------------------------------------
    Item {
        id: notch

        anchors.horizontalCenter: parent.horizontalCenter
        width: row.implicitWidth + 2 * (bar.shoulder + 18)
        height: bar.notchH

        Behavior on width {
            NumberAnimation {
                duration: 260
                easing.type: Easing.OutCubic
            }
        }

        Canvas {
            id: shape

            anchors.fill: parent
            property color fillC: Qt.alpha(bar.theme.bg, 0.94)
            property color edgeC: Qt.alpha(bar.theme.accent, 0.45)
            onFillCChanged: requestPaint()
            onEdgeCChanged: requestPaint()
            onWidthChanged: requestPaint()

            onPaint: {
                const ctx = getContext("2d");
                ctx.reset();
                const W = width, H = height - 1, s = bar.shoulder, r = 12;
                ctx.beginPath();
                ctx.moveTo(0, 0);
                ctx.quadraticCurveTo(s, 0, s, s * 0.9);
                ctx.lineTo(s, H - r);
                ctx.quadraticCurveTo(s, H, s + r, H);
                ctx.lineTo(W - s - r, H);
                ctx.quadraticCurveTo(W - s, H, W - s, H - r);
                ctx.lineTo(W - s, s * 0.9);
                ctx.quadraticCurveTo(W - s, 0, W, 0);
                ctx.closePath();
                ctx.fillStyle = fillC;
                ctx.fill();
                ctx.strokeStyle = edgeC;
                ctx.lineWidth = 1;
                ctx.stroke();
            }
        }

        Row {
            id: row

            anchors.centerIn: parent
            anchors.verticalCenterOffset: -1
            spacing: 12

            // A: the menu. The logo's own A (as fastfetch shows it), in whole-pixel blocks
            LogoA {
                anchors.verticalCenter: parent.verticalCenter
                color: bar.theme.accent
                color2: bar.theme.hot
                cell: 1

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: Arch.cmd(["menu"])
                }
            }

            Workspaces {
                id: ws

                anchors.verticalCenter: parent.verticalCenter
                spacing: 5
                delegate: Item {
                    id: slot

                    required property int index
                    readonly property int wsId: index + 1
                    readonly property bool active: ws.isActive(wsId)
                    readonly property bool occupied: ws.isOccupied(wsId)

                    visible: ws.shown(wsId)
                    anchors.verticalCenter: parent?.verticalCenter
                    width: active ? 22 : bar.wsNumbers ? 16 : 12
                    height: 16

                    Behavior on width {
                        NumberAnimation {
                            duration: 220
                            easing.type: Easing.OutCubic
                        }
                    }
                    Rectangle {
                        anchors.centerIn: parent
                        visible: slot.active || !bar.wsNumbers
                        width: slot.active ? parent.width : slot.occupied ? 6 : 4
                        height: slot.active ? 16 : width
                        radius: slot.active ? 4 : width / 2
                        color: slot.active ? bar.theme.accent : ws.isUrgent(slot.wsId) ? bar.theme.urgent : slot.occupied ? bar.theme.text : Qt.alpha(bar.theme.textDim, 0.7)
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: slot.active || bar.wsNumbers
                        text: slot.wsId % 10
                        color: slot.active ? bar.theme.bg : ws.isUrgent(slot.wsId) ? bar.theme.urgent : slot.occupied ? bar.theme.text : bar.theme.textDim
                        font.family: bar.theme.font
                        font.pixelSize: 11
                        font.bold: true
                    }
                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -3
                        cursorShape: Qt.PointingHandCursor
                        onClicked: ws.goTo(slot.wsId)
                    }
                }
            }

            Sep {}

            // cpu and memory, terse
            Row {
                visible: bar.showStats
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Glyph {
                    name: "speed"
                    size: 14
                    color: bar.theme.textDim
                }
                Label {
                    text: String(Math.round(bar.stats.cpu * 100)).padStart(2, "0") + "%"
                }
            }
            Row {
                visible: bar.showStats
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Glyph {
                    name: "memory_alt"
                    size: 14
                    color: bar.theme.textDim
                }
                Label {
                    text: Math.round(bar.stats.mem * 100) + "%"
                }
            }

            Sep {
                visible: bar.showStats
            }

            // clock (the hook sits beside the Row: a filling child breaks a Row's layout)
            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: clockRow.implicitWidth
                implicitHeight: 20

                Row {
                    id: clockRow

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Label {
                        text: Qt.formatDateTime(clock.date, bar.timeFormat)
                        font.bold: true
                    }
                    Label {
                        visible: bar.showDate
                        text: Qt.formatDateTime(clock.date, "ddd d").toLowerCase()
                        color: bar.theme.textDim
                    }
                }
                PanelHook {
                    name: "calendar"
                }
            }

            Sep {
                visible: media.visible
            }

            // now playing: controls, title, a tiny live meter
            Row {
                id: media

                visible: bar.showMedia && bar.services.player !== null
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Glyph {
                    name: "skip_previous"
                    size: 14
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.services.media("prev")
                    }
                }
                Glyph {
                    name: bar.services.player?.isPlaying ? "pause" : "play_arrow"
                    size: 15
                    fill: true
                    color: bar.theme.accent
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.services.media("toggle")
                    }
                }
                Glyph {
                    name: "skip_next"
                    size: 14
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: bar.services.media("next")
                    }
                }
                Label {
                    width: Math.min(implicitWidth, 170)
                    text: bar.services.player?.trackTitle ?? ""
                    elide: Text.ElideRight

                    PanelHook {
                        name: "media"
                        onSecondary: bar.services.media("toggle")
                    }
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Repeater {
                        model: 4
                        Rectangle {
                            required property int index
                            anchors.bottom: parent?.bottom
                            width: 2
                            height: 3 + 9 * (bar.cava.bars[4 + index * 7] ?? 0)
                            radius: 1
                            color: bar.theme.accent
                        }
                    }
                }
            }

            Sep {}

            Tray {
                visible: bar.showTray
                anchors.verticalCenter: parent.verticalCenter
                window: bar
                spacing: 10
            }
            Glyph {
                visible: bar.services.updateCount > 0 || bar.services.rebootNeeded
                name: bar.services.rebootNeeded ? "restart_alt" : "system_update_alt"
                color: bar.theme.accent

                PanelHook {
                    name: "updates"
                }
            }
            Glyph {
                name: bar.services.netIcon

                PanelHook {
                    name: "network"
                }
            }
            Item {
                anchors.verticalCenter: parent.verticalCenter
                implicitWidth: volRow.implicitWidth
                implicitHeight: 20

                Row {
                    id: volRow

                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3

                    Glyph {
                        name: bar.services.volumeIcon
                        color: bar.services.muted ? bar.theme.textDim : bar.theme.text
                    }
                    Label {
                        visible: bar.showVolume
                        text: Math.round(bar.services.volume * 100) + "%"
                        color: bar.services.muted ? bar.theme.textDim : bar.theme.text
                    }
                }
                PanelHook {
                    name: "sound"
                    onSecondary: bar.services.toggleMute()
                    onWheel: w => bar.services.setVolume(bar.services.volume + (w.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
            Glyph {
                name: "tune"
                color: Arch.panels?.current === "control" ? bar.theme.accent : bar.theme.text

                PanelHook {
                    name: "control"
                }
            }
            Glyph {
                name: bar.notifs.count > 0 ? "notifications_unread" : "notifications"
                color: bar.notifs.count > 0 ? bar.theme.accent : bar.theme.textDim

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -6
                    cursorShape: Qt.PointingHandCursor
                    onClicked: bar.notifs.centerOpen = !bar.notifs.centerOpen
                }
            }
        }
    }

    SystemClock {
        id: clock

        precision: bar.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
    }
}
