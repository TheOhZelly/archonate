pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    spacing: 12

    SHeading {
        text: "Wallpaper"
    }
    SRicePicker {}
    SNote {
        text: "Images, gifs and videos in " + (App.edited?.assets ?? "") + " (wallpaper.* and the wallpapers/ folder). Click one to use it."
    }
    Flow {
        Layout.fillWidth: true
        spacing: 12

        Repeater {
            model: App.edited?.wallpapers ?? []

            Rectangle {
                id: wp

                required property string modelData
                required property int index
                readonly property bool chosen: index === App.edited.wallIndex
                readonly property bool still: /\.(png|jpe?g|webp|gif)$/i.test(modelData)

                width: 220
                height: 124
                radius: App.r(10)
                color: App.panel
                border.width: chosen ? 3 : 1
                border.color: chosen ? App.accent : App.line
                clip: true
                scale: wpPress.pressed ? 0.97 : 1

                Image {
                    anchors.fill: parent
                    anchors.margins: wp.border.width
                    visible: wp.still
                    source: wp.still ? "file://" + wp.modelData : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 440
                    asynchronous: true
                }
                SLabel {
                    anchors.centerIn: parent
                    visible: !wp.still
                    text: "▶ " + wp.modelData.split("/").pop()
                }
                MouseArea {
                    id: wpPress

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: App.exec(["python3", App.py, "wallpaper", App.edited.name, String(wp.index)])
                }
                SFocus {
                    inset: true
                    onActivated: App.exec(["python3", App.py, "wallpaper", App.edited.name, String(wp.index)])
                }
            }
        }
    }
    RowLayout {
        spacing: 8

        SChip {
            text: "Open wallpaper folder"
            onClicked: App.detached(["sh", "-c", "mkdir -p \"$1/wallpapers\" && xdg-open \"$1/wallpapers\"", "sh", App.edited.assets])
        }
        SChip {
            text: "Rescan"
            onClicked: {
                App.detached(["qs", "-p", App.home + "/.config/hypr/rices/" + App.edited.name + "/shell", "ipc", "call", "rice", "rescanWallpaper"]);
                App.refresh();
            }
        }
    }

    SSection {
        title: "Rotate"
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [[0, "Off"], [5, "5 min"], [15, "15 min"], [30, "30 min"], [60, "1 hour"]]

            SChip {
                required property var modelData

                text: modelData[1]
                selected: (App.edited?.wallpaperMinutes ?? 0) === modelData[0]
                onClicked: App.setRice("wallpaperMinutes", modelData[0])
            }
        }
    }
    SNote {
        text: "SUPER+SHIFT+W goes to the next one any time, add ALT to go back."
    }
}
