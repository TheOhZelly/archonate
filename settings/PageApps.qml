// Default apps: what opens links, folders, images, video, music, text and PDFs.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: page

    property var cats: []

    spacing: 12

    function reload(): void {
        App.run(["python3", App.py, "apps"], (c, out) => page.cats = JSON.parse(out));
    }

    Component.onCompleted: reload()

    SHeading {
        text: "Default apps"
    }
    SNote {
        text: "What opens when you click a link, a folder or a file. Only apps that can open that kind of thing are listed."
    }

    Repeater {
        model: page.cats

        ColumnLayout {
            id: cat

            required property var modelData

            Layout.fillWidth: true
            spacing: 8

            SSection {
                title: cat.modelData.label
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8

                Repeater {
                    model: cat.modelData.options

                    Rectangle {
                        id: opt

                        required property var modelData
                        readonly property bool chosen: modelData.id === cat.modelData.current

                        implicitWidth: row.implicitWidth + 26
                        implicitHeight: 40
                        radius: App.r(12)
                        color: chosen ? Qt.alpha(App.accent, 0.22) : optHover.containsMouse ? Qt.alpha(App.fg, 0.08) : Qt.alpha(App.fg, 0.04)
                        border.width: App.bw
                        border.color: chosen ? App.accent : App.line
                        scale: optHover.pressed ? 0.96 : 1

                        Row {
                            id: row

                            anchors.centerIn: parent
                            spacing: 8

                            IconImage {
                                anchors.verticalCenter: parent.verticalCenter
                                implicitSize: 22
                                source: Quickshell.iconPath(opt.modelData.icon, "application-x-executable")
                            }
                            SLabel {
                                anchors.verticalCenter: parent.verticalCenter
                                text: opt.modelData.name
                                font.weight: opt.chosen ? Font.DemiBold : Font.Normal
                            }
                        }
                        MouseArea {
                            id: optHover

                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: App.run(["python3", App.py, "setapp", cat.modelData.key, opt.modelData.id], () => page.reload())
                        }
                        SFocus {
                            onActivated: App.run(["python3", App.py, "setapp", cat.modelData.key, opt.modelData.id], () => page.reload())
                        }
                    }
                }
            }
        }
    }
}
