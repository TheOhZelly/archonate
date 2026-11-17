// Archonate's switch cover: a still of the desktop you're leaving, held over
// every screen while the rice swaps underneath, then faded away once the new
// desktop has drawn. lib/switch.sh starts it; the new shell (or a fallback
// timer) calls:  qs -p ~/.config/hypr/cover ipc call cover fade
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    property bool fading: false
    readonly property string dir: Quickshell.env("XDG_RUNTIME_DIR") || "/tmp"

    function fade(): void {
        if (fading)
            return;
        fading = true;
        quit.start();
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "archonate-cover"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: "transparent"
            mask: Region {} // never eats a click

            Image {
                anchors.fill: parent
                source: "file://" + root.dir + "/archonate-cover-" + modelData.name + ".png"
                cache: false
                opacity: root.fading ? 0 : 1
                scale: root.fading ? 1.03 : 1
                Behavior on opacity {
                    NumberAnimation {
                        duration: 520
                        easing.type: Easing.InOutQuad
                    }
                }
                Behavior on scale {
                    NumberAnimation {
                        duration: 620
                        easing.type: Easing.OutCubic
                    }
                }
            }
        }
    }

    IpcHandler {
        target: "cover"

        function fade(): void {
            root.fade();
        }
    }

    // Never outstay a broken switch
    Timer {
        running: true
        interval: 6000
        onTriggered: root.fade()
    }
    Timer {
        id: quit

        interval: 700
        onTriggered: Qt.quit()
    }
}
