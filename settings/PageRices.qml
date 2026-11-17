pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 12

    SHeading {
        text: "Rices & modes"
    }
    SNote {
        text: "Click a rice to switch the whole desktop to it. Same as SUPER+F9."
    }
    Flow {
        Layout.fillWidth: true
        spacing: 14

        Repeater {
            model: App.info.rices

            Rectangle {
                id: card

                required property var modelData
                readonly property bool isCurrent: modelData.name === App.info.rice

                width: 210
                height: 158
                radius: App.r(12)
                color: "#" + modelData.bg
                border.width: isCurrent ? 3 : 1
                border.color: isCurrent ? "#" + modelData.accent : App.line
                clip: true
                scale: press.pressed ? 0.97 : 1

                Image {
                    anchors.fill: parent
                    anchors.margins: card.border.width
                    anchors.bottomMargin: 40
                    source: card.modelData.wallpaper ? "file://" + card.modelData.wallpaper : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 420
                    asynchronous: true
                }
                Row {
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 12
                    spacing: 8

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: 10
                        height: 10
                        radius: App.r(5)
                        color: "#" + card.modelData.accent
                    }
                    Text {
                        text: card.modelData.name + (card.isCurrent ? "  ·  active" : "")
                        color: "#" + card.modelData.text
                        font.family: App.font
                        font.pixelSize: 14
                        font.weight: Font.DemiBold
                    }
                }
                MouseArea {
                    id: press

                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: App.exec([App.bin + "hypr-rice", card.modelData.name])
                }
                SFocus {
                    inset: true
                    onActivated: App.exec([App.bin + "hypr-rice", card.modelData.name])
                }
            }
        }
    }

    SSection {
        title: "Mode"
    }
    SNote {
        text: "normal changes nothing. gaming strips every effect and allows tearing. minimal keeps the layout but drops effects."
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: App.info.modes

            SChip {
                required property string modelData

                text: modelData
                selected: modelData === App.info.mode
                onClicked: App.exec([App.bin + "hypr-mode", modelData])
            }
        }
    }
}
