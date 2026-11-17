import QtQuick
import QtQuick.Layouts

// Label + note on the left, controls on the right
RowLayout {
    id: row

    property string label
    property string note
    default property alias content: slot.data

    Layout.fillWidth: true
    spacing: 16

    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2

        SLabel {
            text: row.label
            font.pixelSize: 15
        }
        SNote {
            visible: text !== ""
            text: row.note
        }
    }
    RowLayout {
        id: slot

        spacing: 8
    }
}
