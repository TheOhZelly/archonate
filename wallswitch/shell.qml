// Wallpaper switcher (SUPER+CTRL+W, `archonate wallpaper pick`): a carousel of
// this rice's wallpapers. ←/→ or scroll to browse, Enter/click to set, Esc to
// close. Runs as its own Quickshell instance; drawn in the rice's colours.
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property var data: ({ rice: "", current: 0, items: [], accent: "ffffff", bg: "000000", text: "ffffff" })
    readonly property color accent: "#" + data.accent
    readonly property color bg: "#" + data.bg
    readonly property string home: Quickshell.env("HOME")

    function apply(i: int): void {
        Quickshell.execDetached([home + "/.local/bin/archonate", "wallpaper", "set", String(i)]);
        Qt.quit();
    }

    Process {
        running: true
        command: ["python3", root.home + "/.config/hypr/lib/desktop.py", "walls"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.data = JSON.parse(text);
                strip.currentIndex = root.data.current;
                strip.positionViewAtIndex(root.data.current, ListView.Center);
            }
        }
    }

    PanelWindow {
        id: win

        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "archonate-wallswitch"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Qt.alpha(root.bg, 0.9)

        MouseArea {
            anchors.fill: parent
            onClicked: Qt.quit()
            onWheel: w => w.angleDelta.y < 0 ? strip.incrementCurrentIndex() : strip.decrementCurrentIndex()
        }

        Item {
            anchors.fill: parent
            focus: true
            Keys.onPressed: e => {
                if (e.key === Qt.Key_Escape)
                    Qt.quit();
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Space)
                    root.apply(strip.currentIndex);
                else if (e.key === Qt.Key_Left || e.key === Qt.Key_H)
                    strip.decrementCurrentIndex();
                else if (e.key === Qt.Key_Right || e.key === Qt.Key_L)
                    strip.incrementCurrentIndex();
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: strip.top
            anchors.bottomMargin: 40
            text: "Wallpaper  ·  " + root.data.rice
            color: "#" + root.data.text
            font.family: "Adwaita Sans"
            font.pixelSize: 26
            font.weight: Font.Light
        }

        ListView {
            id: strip

            readonly property real cardW: Math.min(760, win.width * 0.42)
            readonly property real cardH: cardW * 0.5625

            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: cardH + 70
            orientation: ListView.Horizontal
            spacing: -cardW * 0.12
            model: root.data.items
            highlightRangeMode: ListView.StrictlyEnforceRange
            preferredHighlightBegin: (width - cardW) / 2
            preferredHighlightEnd: (width + cardW) / 2
            highlightMoveDuration: 260
            boundsBehavior: Flickable.StopAtBounds
            cacheBuffer: 4000

            delegate: Item {
                id: card

                required property var modelData
                required property int index
                readonly property bool sel: ListView.isCurrentItem
                readonly property bool isCurrent: index === root.data.current

                width: strip.cardW
                height: strip.height
                z: sel ? 10 : 10 - Math.abs(index - strip.currentIndex)
                scale: sel ? 1 : 0.72
                opacity: sel ? 1 : Math.max(0.25, 0.75 - 0.2 * (Math.abs(index - strip.currentIndex) - 1))
                Behavior on scale {
                    NumberAnimation {
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 220
                    }
                }

                Rectangle {
                    id: frame

                    width: parent.width
                    height: strip.cardH
                    radius: 16
                    color: root.bg
                    border.width: card.sel ? 3 : 1
                    border.color: card.sel ? root.accent : Qt.rgba(1, 1, 1, 0.15)
                    clip: true

                    AnimatedImage {
                        anchors.fill: parent
                        anchors.margins: frame.border.width
                        visible: card.modelData.gif
                        source: visible ? "file://" + card.modelData.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        playing: card.sel
                        cache: false
                    }
                    Image {
                        anchors.fill: parent
                        anchors.margins: frame.border.width
                        visible: !card.modelData.gif
                        source: visible ? "file://" + card.modelData.thumb : ""
                        fillMode: Image.PreserveAspectCrop
                        sourceSize.width: 960
                        asynchronous: true
                        cache: false
                        smooth: true
                    }
                    Text {
                        visible: card.modelData.video
                        anchors.right: parent.right
                        anchors.bottom: parent.bottom
                        anchors.margins: 14
                        text: "▶ video"
                        color: "white"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 13
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.6)
                    }
                }

                Row {
                    anchors.top: frame.bottom
                    anchors.topMargin: 16
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 8
                    opacity: card.sel ? 1 : 0

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 9
                        height: 9
                        radius: 5
                        color: root.accent
                        visible: card.isCurrent
                    }
                    Text {
                        text: card.modelData.name + (card.isCurrent ? "  ·  showing now" : "")
                        color: "white"
                        font.family: "Adwaita Sans"
                        font.pixelSize: 16
                    }
                }

                MouseArea {
                    width: frame.width
                    height: frame.height
                    cursorShape: Qt.PointingHandCursor
                    onClicked: card.sel ? root.apply(card.index) : strip.currentIndex = card.index
                }
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: strip.bottom
            anchors.topMargin: 30
            text: (strip.currentIndex + 1) + " / " + root.data.items.length + "     ←/→ browse   ·   enter set   ·   esc close"
            color: Qt.rgba(1, 1, 1, 0.45)
            font.family: "Adwaita Sans"
            font.pixelSize: 13
        }
    }
}
