// Material Symbols glyph by ligature name, e.g. Icon { name: "volume_up" }
import QtQuick

Text {
    property string name
    property real size: 16
    property bool fill: false

    text: name
    font.family: "Material Symbols Rounded"
    font.pixelSize: size
    font.variableAxes: ({ FILL: fill ? 1 : 0, wght: 400 })
    verticalAlignment: Text.AlignVCenter
}
