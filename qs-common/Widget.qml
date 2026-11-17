// Desktop widget: clock, date and now playing, drawn on the wallpaper (below
// windows). Placement and style come from the rice's Theme:
//   widgetPos "top-left" | "top-right" | "bottom-left" | "bottom-right" | "center"
//   widgetClockSize, widgetClockColor, widgetItalic, widgetCard (glass card behind it),
//   widgetClockFormat (default "HH:mm"), widgetClockOnly (hide date and now playing)
import QtQuick
import Quickshell
import Quickshell.Wayland

Scope {
    id: root

    required property QtObject theme
    required property Services services
    property bool shown: true

    property string pos: theme.widgetPos ?? "bottom-left"
    readonly property bool top: pos.startsWith("top")
    readonly property bool bottom: pos.startsWith("bottom")
    readonly property bool left: pos.endsWith("left")
    readonly property bool right: pos.endsWith("right")
    readonly property int align: left ? Text.AlignLeft : right ? Text.AlignRight : Text.AlignHCenter

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
                top: root.top
                bottom: root.bottom
                left: root.left
                right: root.right
            }
            margins {
                top: 70
                bottom: 90
                left: 80
                right: 80
            }
            implicitWidth: card.width
            implicitHeight: card.height
            color: "transparent"
            mask: Region {}

            Rectangle {
                id: card

                // Glass rices get Liquid Glass; other card rices a plain tinted card
                readonly property bool liquid: (root.theme.glass ?? false) && (root.theme.widgetCard ?? false)

                width: col.implicitWidth + (root.theme.widgetCard ? 2 * (liquid ? 34 : 28) : 0)
                height: col.implicitHeight + (root.theme.widgetCard ? 2 * (liquid ? 26 : 22) : 0)
                radius: liquid ? 30 : root.theme.radius + 6
                color: root.theme.widgetCard && !liquid ? Qt.alpha(root.theme.surface, 0.55) : "transparent"
                border.width: root.theme.widgetCard && !liquid ? 1 : 0
                border.color: root.theme.border

                LiquidGlass {
                    anchors.fill: parent
                    visible: card.liquid
                    radius: card.radius
                    tintOpacity: 0.07
                    rimStrength: 0.85
                }

                Column {
                    id: col

                    anchors.centerIn: parent
                    spacing: 2

                    Text {
                        width: Math.max(implicitWidth, col.width)
                        horizontalAlignment: root.align
                        text: Qt.formatDateTime(clock.date, root.theme.widgetClockFormat ?? "HH:mm")
                        color: root.theme.widgetClockColor ?? root.theme.text
                        font.family: root.theme.displayFont
                        font.pixelSize: root.theme.widgetClockSize ?? 110
                        font.weight: root.theme.lockClockWeight
                        font.letterSpacing: (root.theme.widgetClockSize ?? 110) * (root.theme.displayTracking ?? 0)
                        font.italic: root.theme.widgetItalic ?? false
                        style: Text.Raised
                        styleColor: Qt.alpha("#000000", 0.35)
                    }
                    Text {
                        width: Math.max(implicitWidth, col.width)
                        horizontalAlignment: root.align
                        visible: !(root.theme.widgetClockOnly ?? false)
                        text: root.theme.caps(Qt.formatDateTime(clock.date, root.theme.longDate))
                        color: root.theme.accent
                        font.family: root.theme.font
                        font.pixelSize: root.theme.fontSize + 5
                        font.letterSpacing: root.theme.tracking
                        style: Text.Raised
                        styleColor: Qt.alpha("#000000", 0.35)
                    }
                    Text {
                        width: Math.max(implicitWidth, col.width)
                        visible: text !== "" && !(root.theme.widgetClockOnly ?? false)
                        topPadding: 10
                        horizontalAlignment: root.align
                        text: root.services.nowPlaying !== "" ? "♪  " + root.services.nowPlaying : ""
                        color: root.theme.textDim
                        font.family: root.theme.font
                        font.pixelSize: root.theme.fontSize + 1
                        elide: Text.ElideRight
                        style: Text.Raised
                        styleColor: Qt.alpha("#000000", 0.35)
                    }
                }
            }
        }
    }
}
