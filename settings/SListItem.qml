import QtQuick
import QtQuick.Layouts

// One row in a list: icon, title, subtitle, trailing controls; clickable
Rectangle {
    id: item

    property string icon
    property string title
    property string subtitle
    property bool active: false
    property bool clickable: true // false: Tab skips the row (its chips still get it)
    default property alias trailing: slot.data
    signal clicked

    Layout.fillWidth: true
    implicitHeight: 54
    radius: App.r(10)
    color: active ? Qt.alpha(App.accent, 0.16) : hover.containsMouse ? Qt.alpha(App.fg, 0.05) : "transparent"

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: item.clicked()
    }
    SFocus {
        enabled: item.clickable
        onActivated: item.clicked()
    }
    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 10
        spacing: 14

        Text {
            visible: item.icon !== ""
            text: item.icon
            font.family: "Material Symbols Rounded"
            font.pixelSize: 22
            color: item.active ? App.accent : App.dim
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 1

            SLabel {
                Layout.fillWidth: true
                text: item.title
                font.weight: item.active ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
            SLabel {
                Layout.fillWidth: true
                visible: text !== ""
                text: item.subtitle
                color: App.dim
                font.pixelSize: 12
                elide: Text.ElideRight
            }
        }
        RowLayout {
            id: slot

            spacing: 8
        }
    }
}
