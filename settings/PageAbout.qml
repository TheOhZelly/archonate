// About this computer
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Io

ColumnLayout {
    id: page

    property var info: ({})

    spacing: 12

    Component.onCompleted: {
        App.run(["python3", App.py, "about"], (c, out) => page.info = JSON.parse(out));
        App.run([App.bin + "archonate", "version"], (c, out) => page.version = out.trim());
    }

    SHeading {
        text: "About"
    }

    // The Archonate logo, in this rice's accent
    SCard {
        SLogo {
            Layout.fillWidth: true
            Layout.topMargin: 6
            art: logo.text()
            color: App.accent
        }
        SLabel {
            Layout.alignment: Qt.AlignHCenter
            text: page.version
            color: App.dim
            font.pixelSize: 12
            topPadding: 6
        }
    }
    FileView {
        id: logo

        path: App.home + "/.config/hypr/lib/archonate/logo.txt"
        blockLoading: true
    }
    property string version: ""

    SCard {
        SLabel {
            text: page.info.host ?? ""
            font.pixelSize: 22
            font.weight: Font.DemiBold
        }
        SLabel {
            text: (page.info.os ?? "") + " · Hyprland " + (page.info.hyprland ?? "") + " · rice: " + (page.info.rice ?? "")
            color: App.dim
        }
    }

    SCard {
        GridLayout {
            columns: 2
            columnSpacing: 28
            rowSpacing: 10

            Repeater {
                model: [["Processor", "cpu"], ["Graphics", "gpu"], ["Memory", "memory"], ["Storage", "disk"], ["Motherboard", "board"], ["Kernel", "kernel"], ["Up for", "uptime"]]

                SLabel {
                    required property var modelData
                    required property int index

                    Layout.row: index
                    Layout.column: 0
                    text: modelData[0]
                    color: App.dim
                }
            }
            Repeater {
                model: ["cpu", "gpu", "memory", "disk", "board", "kernel", "uptime"]

                SLabel {
                    required property string modelData
                    required property int index

                    Layout.row: index
                    Layout.column: 1
                    text: page.info[modelData] ?? ""
                }
            }
        }
    }

    RowLayout {
        spacing: 8

        SChip {
            text: "Spin it in fetch"
            onClicked: App.detached(["kitty", "--hold", App.bin + "fetch"])
        }
    }
}
