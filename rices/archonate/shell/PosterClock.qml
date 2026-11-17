// Desktop widget: a poster clock. Huge compressed hours, the minutes set small
// beside them, the date under a dotted rule. Top right, on the wallpaper.
import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "common"

Scope {
    id: root

    required property Theme theme
    property bool shown: true

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    Variants {
        model: root.shown ? Quickshell.screens : []

        PanelWindow {
            required property var modelData

            screen: modelData
            WlrLayershell.layer: WlrLayer.Bottom
            WlrLayershell.namespace: "rice-widget"
            exclusionMode: ExclusionMode.Normal
            anchors {
                top: true
                right: true
            }
            margins {
                top: 0
                right: 30
            }
            // room around the column for its shadow
            implicitWidth: col.implicitWidth + 2 * shade
            implicitHeight: col.implicitHeight + 2 * shade
            readonly property int shade: 26
            color: "transparent"
            mask: Region {}

            Column {
                id: col

                x: 26 // shade
                y: 26
                spacing: 0

                // a soft dark halo, so the clock and date read on light wallpapers too
                layer.enabled: true
                layer.effect: MultiEffect {
                    shadowEnabled: true
                    shadowColor: "#000000"
                    shadowOpacity: 0.85
                    shadowBlur: 1.0
                    blurMax: 32
                    shadowVerticalOffset: 2
                }

                Row {
                    anchors.right: parent.right
                    spacing: 10

                    Text {
                        id: hours

                        text: Qt.formatDateTime(clock.date, "HH")
                        color: root.theme.text
                        font.family: root.theme.displayFont
                        font.weight: Font.Black
                        font.pixelSize: root.theme.widgetClockSize
                    }
                    Text {
                        y: hours.height * 0.2
                        text: Qt.formatDateTime(clock.date, "mm")
                        color: root.theme.accent
                        font.family: root.theme.displayFont
                        font.weight: Font.Black
                        font.pixelSize: root.theme.widgetClockSize * 0.36
                    }
                }

                // dotted rule
                Row {
                    anchors.right: parent.right
                    spacing: 4
                    Repeater {
                        model: 26
                        Rectangle {
                            width: 3
                            height: 2
                            radius: 1
                            color: Qt.alpha(root.theme.accent, 0.8)
                        }
                    }
                }

                // the date on a card like the stats column's, so it reads on any wallpaper
                Item {
                    anchors.right: parent.right
                    width: dateRow.implicitWidth + 28
                    height: dateRow.implicitHeight + 16 + 10

                    Rectangle {
                        anchors.fill: parent
                        anchors.topMargin: 10
                        radius: root.theme.radius + 2
                        color: Qt.alpha(root.theme.bg, 0.86)
                        border.width: 1
                        border.color: Qt.alpha(root.theme.accent, 0.3)
                    }
                    Row {
                        id: dateRow

                        anchors.horizontalCenter: parent.horizontalCenter
                        y: 10 + 8
                        spacing: 10

                        Text {
                            id: weekday

                            text: Qt.formatDateTime(clock.date, "dddd").toLowerCase()
                            color: root.theme.accent
                            font.family: root.theme.font
                            font.pixelSize: 15
                            font.bold: true
                        }
                        Text {
                            text: Qt.formatDateTime(clock.date, "d MMMM yyyy").toUpperCase().split("").join(" ")
                            color: root.theme.text
                            font.family: root.theme.font
                            font.pixelSize: 13
                            anchors.baseline: weekday.baseline
                        }
                    }
                }
            }
        }
    }
}
