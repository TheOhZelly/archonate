import QtQuick
import QtQuick.Layouts

// Which standalone rice the per-rice pages edit (• marks the active one)
Flow {
    Layout.fillWidth: true
    spacing: 8

    Repeater {
        model: App.standalone

        SChip {
            required property var modelData

            text: modelData.name + (modelData.name === App.info.rice ? "  •" : "")
            selected: App.edited?.name === modelData.name
            onClicked: App.editRice = modelData.name
        }
    }
}
