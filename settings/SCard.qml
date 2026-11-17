import QtQuick
import QtQuick.Layouts

// Rounded group box; children stack vertically
Rectangle {
    default property alias content: col.data
    property alias spacing: col.spacing

    Layout.fillWidth: true
    implicitHeight: col.implicitHeight + 28
    radius: App.r(14)
    color: App.card
    border.width: App.bw
    border.color: App.line

    ColumnLayout {
        id: col

        x: 18
        y: 14
        width: parent.width - 36
        spacing: 12
    }
}
