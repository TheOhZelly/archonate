// Rice + mode picker overlay (SUPER+F9 / SUPER+F10). Runs as its own
// Quickshell instance, so it works from any rice.
//   ←/→ move   ↑/↓ or Tab switch row   Enter apply   Esc close
// PICKER_FOCUS=mode opens with the mode row selected.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property var data: ({ rice: "", mode: "", rices: [], modes: [], styles: [], style: "" })
    property int riceIndex: 0
    property int modeIndex: 0
    property int styleIndex: 0
    property bool onModes: Quickshell.env("PICKER_FOCUS") === "mode"
    // Rices with a look.json wear styles (downloaded themes and more): a row
    // of their own, following whichever of them is selected
    property bool onStyles: false
    // One rice (the shipped setup): there's nothing to pick there, so the
    // picker is about styles: a strip of their previews instead of rice cards
    readonly property bool solo: data.rices.length <= 1
    onSoloChanged: if (solo && !onModes)
        onStyles = true
    readonly property string selName: data.rices[riceIndex]?.name ?? ""
    readonly property var selStyled: data.styled?.[selName] ?? null
    readonly property var selStyles: selStyled?.styles ?? []
    readonly property string selStyle: selStyled?.style ?? ""
    readonly property bool stylesShown: selStyles.length > 0
    onSelNameChanged: styleIndex = Math.max(0, selStyles.findIndex(s => s.name === selStyle))

    readonly property var current: data.rices.find(r => r.name === data.rice) ?? { bg: "1a1a1a", accent: "ffffff", text: "ffffff" }
    readonly property color accent: "#" + current.accent
    readonly property string home: Quickshell.env("HOME")

    function apply(): void {
        if (onModes)
            Quickshell.execDetached([home + "/.local/bin/hypr-mode", data.modes[modeIndex]]);
        else if (onStyles && stylesShown)
            Quickshell.execDetached([home + "/.local/bin/archonate", "style", "set", selStyles[styleIndex].name, selName]);
        else
            Quickshell.execDetached([home + "/.local/bin/hypr-rice", data.rices[riceIndex].name]);
        Qt.quit();
    }

    Process {
        running: true
        command: ["python3", root.home + "/.config/hypr/lib/desktop.py", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.data = JSON.parse(text);
                root.riceIndex = Math.max(0, root.data.rices.findIndex(r => r.name === root.data.rice));
                root.modeIndex = Math.max(0, root.data.modes.indexOf(root.data.mode));
                root.styleIndex = Math.max(0, root.selStyles.findIndex(s => s.name === root.selStyle));
            }
        }
    }

    PanelWindow {
        id: win

        // Cards shrink to fit however many rices there are
        readonly property real cardW: Math.min(220, (width - 160 - 22 * Math.max(0, root.data.rices.length - 1)) / Math.max(1, root.data.rices.length))

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-picker"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Qt.rgba(0, 0, 0, 0.62)

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: event => {
                const n = root.onModes ? root.data.modes.length : root.onStyles ? root.selStyles.length : root.data.rices.length;
                if (event.key === Qt.Key_Escape)
                    Qt.quit();
                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
                    root.apply();
                else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Up || event.key === Qt.Key_Down) {
                    // rows: rices -> styles (rices that wear them) -> modes
                    const rows = root.solo ? (root.stylesShown ? ["styles", "modes"] : ["modes"]) : root.stylesShown ? ["rices", "styles", "modes"] : ["rices", "modes"];
                    const cur = root.onModes ? "modes" : root.onStyles ? "styles" : "rices";
                    const d = event.key === Qt.Key_Up ? -1 : 1;
                    const nxt = rows[(rows.indexOf(cur) + d + rows.length) % rows.length];
                    root.onModes = nxt === "modes";
                    root.onStyles = nxt === "styles";
                }
                else if (event.key === Qt.Key_Left || event.key === Qt.Key_Right) {
                    const d = event.key === Qt.Key_Left ? -1 : 1;
                    if (root.onModes)
                        root.modeIndex = (root.modeIndex + d + n) % n;
                    else if (root.onStyles)
                        root.styleIndex = (root.styleIndex + d + n) % n;
                    else
                        root.riceIndex = (root.riceIndex + d + n) % n;
                }
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 26

            // The stage: a real look at the selected rice (its screenshot from
            // `archonate theme preview`, else its wallpaper), crossfading as you move
            Item {
                id: stage

                readonly property var style: root.stylesShown && root.onStyles ? root.selStyles[root.styleIndex] : null
                readonly property var sel: style ?? root.data.rices[root.riceIndex] ?? null
                readonly property string src: sel ? (sel.shot || sel.wallpaper) : ""

                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(980, win.width * 0.52)
                height: width * 0.5625

                onSrcChanged: {
                    back.source = front.source;
                    back.opacity = 1;
                    front.source = src ? "file://" + src : "";
                    fadeBack.restart();
                }

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -3
                    radius: 18
                    color: "transparent"
                    border.width: 3
                    border.color: stage.sel ? "#" + stage.sel.accent : "transparent"
                    Behavior on border.color { ColorAnimation { duration: 260 } }
                }
                Rectangle {
                    id: stageClip

                    anchors.fill: parent
                    radius: 15
                    color: stage.sel ? "#" + stage.sel.bg : "black"
                    clip: true

                    Image {
                        id: front

                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        cache: false
                    }
                    Image {
                        id: back

                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        cache: false
                        NumberAnimation on opacity {
                            id: fadeBack

                            running: false
                            from: 1
                            to: 0
                            duration: 280
                            easing.type: Easing.InOutQuad
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: stage.sel !== null && !stage.sel.shot
                        text: "archonate theme preview  ·  to capture this rice"
                        color: Qt.rgba(1, 1, 1, 0.55)
                        font.family: "Adwaita Sans"
                        font.pixelSize: 12
                        anchors.verticalCenterOffset: parent.height / 2 - 24
                    }
                }
            }

            // Name + palette
            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 18

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: stage.style ? (root.solo ? stage.style.title : root.selName + " · " + stage.style.title) : (stage.sel?.name ?? "")
                    color: "white"
                    font.family: "Adwaita Sans"
                    font.pixelSize: 28
                    font.weight: Font.Light
                }
                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6

                    Repeater {
                        model: stage.sel?.swatches ?? []

                        Rectangle {
                            required property string modelData

                            width: 22
                            height: 22
                            radius: 11
                            color: "#" + modelData
                            border.width: 1
                            border.color: Qt.rgba(1, 1, 1, 0.25)
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: !root.solo
                spacing: 22

                Repeater {
                    model: root.data.rices

                    Item {
                        id: card

                        required property var modelData
                        required property int index
                        readonly property bool selected: !root.onModes && root.riceIndex === index
                        readonly property bool isCurrent: modelData.name === root.data.rice
                        readonly property color cAccent: "#" + modelData.accent

                        width: win.cardW
                        height: win.cardW * 0.5625 + 50
                        scale: selected ? 1.06 : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        Rectangle {
                            id: frame

                            width: parent.width
                            height: win.cardW * 0.5625
                            radius: 14
                            color: "#" + card.modelData.bg
                            border.width: card.selected ? 3 : 1
                            border.color: card.selected ? card.cAccent : Qt.rgba(1, 1, 1, 0.15)
                            clip: true

                            AnimatedImage {
                                anchors.fill: parent
                                anchors.margins: frame.border.width
                                source: card.modelData.shot ? "file://" + card.modelData.shot : card.modelData.wallpaper ? "file://" + card.modelData.wallpaper : ""
                                fillMode: Image.PreserveAspectCrop
                                playing: card.selected
                                asynchronous: true
                                cache: false
                                sourceSize.width: 480
                            }
                            // Accent strip, like a tiny bar in the rice's colours (no screenshot yet)
                            Rectangle {
                                visible: !card.modelData.shot
                                anchors.top: parent.top
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: frame.border.width
                                height: 14
                                color: Qt.alpha("#" + card.modelData.bg, 0.85)

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    x: 10
                                    width: 34
                                    height: 4
                                    radius: 2
                                    color: card.cAccent
                                }
                            }
                        }

                        Row {
                            anchors.top: frame.bottom
                            anchors.topMargin: 14
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 8

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: card.cAccent
                            }
                            Text {
                                text: card.modelData.name + (card.isCurrent ? "  ·  current" : "")
                                color: card.selected ? "white" : Qt.rgba(1, 1, 1, 0.7)
                                font.family: "Adwaita Sans"
                                font.pixelSize: 16
                                font.weight: card.selected ? Font.DemiBold : Font.Normal
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                root.onModes = false;
                                root.onStyles = false;
                                root.riceIndex = card.index;
                            }
                            onClicked: root.apply()
                        }
                    }
                }
            }

            // One rice: every style as a preview card, the selected one centred
            ListView {
                id: strip

                anchors.horizontalCenter: parent.horizontalCenter
                visible: root.solo && root.stylesShown
                width: Math.min(win.width - 120, 1600)
                height: 168
                orientation: ListView.Horizontal
                spacing: 16
                clip: true
                model: visible ? root.selStyles : []
                currentIndex: root.styleIndex
                highlightRangeMode: ListView.StrictlyEnforceRange
                preferredHighlightBegin: width / 2 - 100
                preferredHighlightEnd: width / 2 + 100
                highlightMoveDuration: 220
                boundsBehavior: Flickable.StopAtBounds
                onCurrentIndexChanged: if (currentIndex !== root.styleIndex && currentIndex >= 0)
                    root.styleIndex = currentIndex

                delegate: Item {
                    id: scard

                    required property var modelData
                    required property int index
                    readonly property bool selected: root.onStyles && root.styleIndex === index
                    readonly property bool isCurrent: modelData.name === root.selStyle

                    width: 200
                    height: strip.height
                    opacity: selected ? 1 : 0.72
                    Behavior on opacity {
                        NumberAnimation {
                            duration: 160
                        }
                    }

                    Rectangle {
                        id: sframe

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 8
                        width: parent.width
                        height: width * 0.5625
                        radius: 12
                        color: "#" + scard.modelData.bg
                        border.width: scard.selected ? 3 : 1
                        border.color: scard.selected ? "#" + scard.modelData.accent : Qt.rgba(1, 1, 1, 0.15)
                        clip: true
                        scale: scard.selected ? 1.05 : 1
                        Behavior on scale {
                            NumberAnimation {
                                duration: 180
                                easing.type: Easing.OutCubic
                            }
                        }

                        Image {
                            anchors.fill: parent
                            anchors.margins: sframe.border.width
                            source: scard.modelData.shot ? "file://" + scard.modelData.shot : scard.modelData.wallpaper ? "file://" + scard.modelData.wallpaper : ""
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                            sourceSize.width: 400
                        }
                    }
                    Row {
                        anchors.top: sframe.bottom
                        anchors.topMargin: 12
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 7

                        Rectangle {
                            anchors.verticalCenter: parent.verticalCenter
                            width: 9
                            height: 9
                            radius: 4.5
                            color: "#" + scard.modelData.accent
                        }
                        Text {
                            text: scard.modelData.title + (scard.isCurrent ? "  ·  on" : "")
                            color: scard.selected ? "white" : Qt.rgba(1, 1, 1, 0.7)
                            font.family: "Adwaita Sans"
                            font.pixelSize: 14
                            font.weight: scard.selected ? Font.DemiBold : Font.Normal
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onEntered: {
                            root.onModes = false;
                            root.onStyles = true;
                            root.styleIndex = scard.index;
                        }
                        onClicked: root.apply()
                    }
                }
            }

            // Styles for the selected rice, if it wears them
            Flow {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(win.width - 160, 1500)
                visible: root.stylesShown && !root.solo
                spacing: 8

                Repeater {
                    model: root.stylesShown ? root.selStyles : []

                    Rectangle {
                        id: schip

                        required property var modelData
                        required property int index
                        readonly property bool selected: root.onStyles && root.styleIndex === index
                        readonly property bool isCurrent: modelData.name === root.selStyle

                        width: srow.implicitWidth + 24
                        height: 32
                        radius: 16
                        color: isCurrent ? Qt.alpha("#" + modelData.accent, 0.3) : Qt.rgba(1, 1, 1, 0.07)
                        border.width: selected ? 2 : 1
                        border.color: selected ? "#" + modelData.accent : Qt.rgba(1, 1, 1, 0.15)

                        Row {
                            id: srow

                            anchors.centerIn: parent
                            spacing: 7

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: 10
                                height: 10
                                radius: 5
                                color: "#" + schip.modelData.accent
                            }
                            Text {
                                text: schip.modelData.title
                                color: "white"
                                font.family: "Adwaita Sans"
                                font.pixelSize: 13
                            }
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                root.onModes = false;
                                root.onStyles = true;
                                root.styleIndex = schip.index;
                            }
                            onClicked: root.apply()
                        }
                    }
                }
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 12

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: "mode"
                    color: Qt.rgba(1, 1, 1, 0.55)
                    font.family: "Adwaita Sans"
                    font.pixelSize: 14
                    rightPadding: 8
                }

                Repeater {
                    model: root.data.modes

                    Rectangle {
                        id: chip

                        required property string modelData
                        required property int index
                        readonly property bool selected: root.onModes && root.modeIndex === index
                        readonly property bool isCurrent: modelData === root.data.mode

                        width: chipText.implicitWidth + 30
                        height: 34
                        radius: 17
                        color: isCurrent ? Qt.alpha(root.accent, 0.3) : Qt.rgba(1, 1, 1, 0.08)
                        border.width: selected ? 2 : 1
                        border.color: selected ? root.accent : Qt.rgba(1, 1, 1, 0.15)

                        Text {
                            id: chipText

                            anchors.centerIn: parent
                            text: chip.modelData
                            color: "white"
                            font.family: "Adwaita Sans"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onEntered: {
                                root.onModes = true;
                                root.modeIndex = chip.index;
                            }
                            onClicked: root.apply()
                        }
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "←/→ choose   ·   ↑/↓ " + (root.solo ? "styles / modes" : "rices" + (root.stylesShown ? " / styles" : "") + " / modes") + "   ·   enter apply   ·   esc close"
                color: Qt.rgba(1, 1, 1, 0.4)
                font.family: "Adwaita Sans"
                font.pixelSize: 12
            }
        }
    }
}
