// OSD: volume (when the default sink's volume or mute changes) and
// announcements, e.g. "Night light on" when a switch flips anywhere.
// (No brightness: this machine has no backlight device.)
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property QtObject theme
    required property Services services
    property bool shown: false
    property bool armed: false // ignore the initial values on startup

    Timer {
        running: true
        interval: 1500
        onTriggered: root.armed = true
    }

    Timer {
        id: hide

        interval: 1400
        onTriggered: root.shown = false
    }

    Connections {
        target: root.services.sink?.audio ?? null

        function onVolumeChanged(): void {
            root.poke();
        }
        function onMutedChanged(): void {
            root.poke();
        }
    }

    property string msgIcon: ""
    property string msgText: ""

    function poke(): void {
        if (!armed)
            return;
        msgText = "";
        shown = true;
        hide.restart();
    }

    function announce(icon: string, text: string): void {
        msgIcon = icon;
        msgText = text;
        shown = true;
        hide.restart();
    }

    PanelWindow {
        visible: root.shown
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-osd"
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        margins.bottom: 120
        implicitWidth: root.msgText ? Math.max(220, msgRow.implicitWidth + 56) : 300
        implicitHeight: 56
        color: "transparent"
        mask: Region {}

        Rectangle {
            anchors.fill: parent
            readonly property bool liquid: root.theme.glass ?? false
            radius: liquid ? 22 : root.theme.radius
            color: liquid ? "transparent" : Qt.alpha(root.theme.bg, root.theme.panelAlpha)
            border.width: liquid ? 0 : root.theme.borderWidth
            border.color: root.theme.border

            LiquidGlass {
                anchors.fill: parent
                visible: parent.liquid
                radius: parent.radius
                tint: root.theme.bg
                tintOpacity: 0.4
                rimStrength: 0.8
            }

            Row {
                id: msgRow

                visible: root.msgText !== ""
                anchors.centerIn: parent
                spacing: 12

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.msgIcon
                    size: 22
                    color: root.theme.accent
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: root.theme.caps ? root.theme.caps(root.msgText) : root.msgText
                    color: root.theme.text
                    font.family: root.theme.font
                    font.pixelSize: root.theme.fontSize + 1
                }
            }

            Row {
                visible: root.msgText === ""
                anchors.centerIn: parent
                spacing: 14

                Icon {
                    anchors.verticalCenter: parent.verticalCenter
                    name: root.services.volumeIcon
                    size: 22
                    color: root.theme.accent
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 180
                    height: root.theme.osdBar
                    radius: height / 2 * (root.theme.radius > 0 ? 1 : 0)
                    color: root.theme.surfaceHi

                    Rectangle {
                        width: parent.width * (root.services.muted ? 0 : root.services.volume)
                        height: parent.height
                        radius: parent.radius
                        color: root.theme.accent
                    }
                }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: Math.round(root.services.volume * 100)
                    color: root.theme.text
                    font.family: root.theme.font
                    font.pixelSize: root.theme.fontSize
                }
            }
        }
    }
}
