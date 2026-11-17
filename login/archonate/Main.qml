// ARCHONATE login screen (SDDM, Qt 6). Dressed in the rice you last used:
// lib/desktop.py writes theme.conf.user (colours, font, wallpaper) on every
// switch. Blurred wallpaper, the ARCHONATE logo in the rice's accent, a big
// clock, your name and password, sessions and power along the bottom.
import QtQuick
import QtQuick.Effects
import "logo.js" as Logo

Rectangle {
    id: root

    readonly property color bg: config.bg || "#1a1a1a"
    readonly property color surface: config.surface || "#262626"
    readonly property color accent: config.accent || "#8f9a5a"
    readonly property color fg: config.text || "#f1ece2"
    readonly property color dim: config.textDim || "#a39c90"
    readonly property color bad: config.error || "#cf5a32"
    readonly property string font: config.font || "Rubik"
    readonly property int radius: parseInt(config.radius || "16")
    readonly property string glyphs: "JetBrainsMono Nerd Font"

    property int session: sessionModel.lastIndex >= 0 ? sessionModel.lastIndex : 0
    property int userIndex: userModel.lastIndex >= 0 ? userModel.lastIndex : 0
    property string userName: userModel.lastUser || ""
    property string realName: ""
    property bool busy: false

    width: 1920
    height: 1080
    color: bg

    // Look up the chosen user's details from the model
    Repeater {
        model: userModel

        Item {
            required property int index
            required property string name
            required property string realName

            Component.onCompleted: {
                if (name === root.userName || (root.userName === "" && index === 0)) {
                    root.userName = name;
                    root.realName = realName;
                }
            }
        }
    }

    Connections {
        target: sddm

        function onLoginFailed(): void {
            root.busy = false;
            pass.text = "";
            err.text = "that's not it";
            shake.restart();
            pass.forceActiveFocus();
        }
        function onLoginSucceeded(): void {
            fadeOut.start();
        }
    }

    function login(): void {
        if (busy || pass.text === "")
            return;
        busy = true;
        err.text = "";
        sddm.login(userName, pass.text, session);
    }

    // ---- background: the rice's wallpaper, blurred and dimmed --------------
    Image {
        id: wall

        anchors.fill: parent
        source: config.background ? "file://" + config.background : ""
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    MultiEffect {
        anchors.fill: parent
        source: wall
        blurEnabled: true
        blur: 0.55
        blurMax: 40
        saturation: 0
    }
    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(root.bg, 0.38)
    }
    // Darker toward the edges, so the middle reads
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(root.bg, 0.35) }
            GradientStop { position: 0.45; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.alpha(root.bg, 0.6) }
        }
    }

    // ---- the logo ---------------------------------------------------------
    Canvas {
        id: logo

        property var rows: []
        readonly property int cols: Math.max(1, ...rows.map(r => r.length))
        readonly property int cell: Math.max(2, Math.floor(Math.min(root.width * 0.42, 1100) / cols))

        anchors.horizontalCenter: parent.horizontalCenter
        y: root.height * 0.16
        width: cell * cols
        height: cell * 2 * rows.length

        // Qt 6 won't let a greeter read local files, so the logo is built in
        Component.onCompleted: {
            rows = Logo.rows;
            requestPaint();
        }
        onPaint: {
            const g = getContext("2d");
            g.reset();
            g.fillStyle = root.accent;
            const s = cell;
            for (let y = 0; y < rows.length; y++)
                for (let x = 0; x < rows[y].length; x++) {
                    const ch = rows[y][x];
                    if (ch === "█")
                        g.fillRect(x * s, y * 2 * s, s, 2 * s);
                    else if (ch === "▀")
                        g.fillRect(x * s, y * 2 * s, s, s);
                    else if (ch === "▄")
                        g.fillRect(x * s, y * 2 * s + s, s, s);
                }
        }
    }

    // ---- clock --------------------------------------------------------------
    Column {
        id: clockCol

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: logo.bottom
        anchors.topMargin: root.height * 0.035
        spacing: 2

        Text {
            id: clock

            anchors.horizontalCenter: parent.horizontalCenter
            color: root.fg
            font.family: root.font
            font.pixelSize: Math.round(root.height * 0.085)
            font.weight: Font.Light
            text: Qt.formatTime(new Date(), "HH:mm")
        }
        Text {
            id: date

            anchors.horizontalCenter: parent.horizontalCenter
            color: root.dim
            font.family: root.font
            font.pixelSize: Math.round(root.height * 0.02)
            text: Qt.formatDate(new Date(), "dddd, d MMMM").toLowerCase()
        }
        Timer {
            running: true
            repeat: true
            interval: 1000
            onTriggered: {
                clock.text = Qt.formatTime(new Date(), "HH:mm");
                date.text = Qt.formatDate(new Date(), "dddd, d MMMM").toLowerCase();
            }
        }
    }

    // ---- who + password -----------------------------------------------------
    Column {
        id: card

        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: clockCol.bottom
        anchors.topMargin: root.height * 0.05
        spacing: 14

        transform: Translate {
            id: shakeX
        }
        SequentialAnimation {
            id: shake

            NumberAnimation { target: shakeX; property: "x"; to: -14; duration: 50 }
            NumberAnimation { target: shakeX; property: "x"; to: 12; duration: 70 }
            NumberAnimation { target: shakeX; property: "x"; to: -8; duration: 70 }
            NumberAnimation { target: shakeX; property: "x"; to: 0; duration: 60 }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.realName || root.userName
            color: root.fg
            font.family: root.font
            font.pixelSize: 18
        }

        // Password
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 340
            height: 50
            radius: Math.min(root.radius, 25)
            color: Qt.alpha(root.surface, 0.85)
            border.width: pass.activeFocus ? 2 : 1
            border.color: err.text ? root.bad : pass.activeFocus ? root.accent : Qt.alpha(root.fg, 0.15)

            TextInput {
                id: pass

                anchors.fill: parent
                anchors.leftMargin: 20
                anchors.rightMargin: 52
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                passwordCharacter: "•"
                color: root.fg
                font.family: root.font
                font.pixelSize: 18
                font.letterSpacing: 3
                selectionColor: root.accent
                clip: true
                focus: true
                enabled: !root.busy
                Keys.onReturnPressed: root.login()
                Keys.onEnterPressed: root.login()
                onTextChanged: if (text !== "")
                    err.text = ""

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: pass.text === ""
                    text: root.busy ? "signing in…" : "password"
                    color: Qt.alpha(root.dim, 0.8)
                    font.family: root.font
                    font.pixelSize: 16
                    font.letterSpacing: 0
                }
            }
            // Go
            Rectangle {
                anchors.right: parent.right
                anchors.rightMargin: 7
                anchors.verticalCenter: parent.verticalCenter
                width: 36
                height: 36
                radius: root.radius > 0 ? 18 : 0
                color: pass.text !== "" ? root.accent : Qt.alpha(root.fg, 0.08)

                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "󰔟" : "󰁔"
                    color: pass.text !== "" ? root.bg : root.dim
                    font.family: root.glyphs
                    font.pixelSize: 18
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.login()
                }
            }
        }
        Text {
            id: err

            anchors.horizontalCenter: parent.horizontalCenter
            height: 18
            color: root.bad
            font.family: root.font
            font.pixelSize: 14
            text: keyboard.capsLock ? "caps lock is on" : ""
        }
    }

    // ---- bottom: session, power ---------------------------------------------
    Row {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.margins: 32
        spacing: 10

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: "󰍹"
            color: root.dim
            font.family: root.glyphs
            font.pixelSize: 18
        }
        Repeater {
            model: sessionModel

            Text {
                required property int index
                required property string name

                visible: index === root.session
                anchors.verticalCenter: parent?.verticalCenter
                text: name.toLowerCase() + (sessionModel.rowCount() > 1 ? "  ›" : "")
                color: root.fg
                font.family: root.font
                font.pixelSize: 15

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -8
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.session = (root.session + 1) % sessionModel.rowCount()
                }
            }
        }
    }

    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 28
        spacing: 12

        Repeater {
            model: [["󰒲", "sleep", sddm.canSuspend], ["󰜉", "restart", sddm.canReboot], ["󰐥", "shut down", sddm.canPowerOff]]

            Rectangle {
                id: pw

                required property var modelData

                visible: modelData[2]
                width: 44
                height: 44
                radius: root.radius > 0 ? 22 : 0
                color: pm.containsMouse ? Qt.alpha(root.fg, 0.14) : Qt.alpha(root.fg, 0.06)

                Text {
                    anchors.centerIn: parent
                    text: pw.modelData[0]
                    color: root.fg
                    font.family: root.glyphs
                    font.pixelSize: 20
                }
                MouseArea {
                    id: pm

                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: pw.modelData[1] === "sleep" ? sddm.suspend() : pw.modelData[1] === "restart" ? sddm.reboot() : sddm.powerOff()
                }
            }
        }
    }

    // Fade to black as the session starts
    Rectangle {
        id: curtain

        anchors.fill: parent
        color: "black"
        opacity: 0
        NumberAnimation on opacity {
            id: fadeOut

            running: false
            to: 1
            duration: 400
        }
    }

    Component.onCompleted: pass.forceActiveFocus()
}
