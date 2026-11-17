import QtQuick

// Pill button; `selected` fills it with the accent
Rectangle {
    id: chip

    property string text
    property bool selected: false
    property bool danger: false
    signal clicked

    implicitWidth: chipLabel.implicitWidth + 30
    implicitHeight: 34
    radius: App.r(17)
    color: selected ? App.accent : hover.pressed ? Qt.alpha(App.fg, 0.18) : hover.containsMouse ? Qt.alpha(App.fg, 0.1) : Qt.alpha(App.fg, 0.05)
    border.width: App.bw
    border.color: selected ? App.accent : danger ? Qt.alpha(App.danger, 0.6) : App.line
    scale: hover.pressed ? 0.96 : 1

    SLabel {
        id: chipLabel

        anchors.centerIn: parent
        text: chip.text
        color: chip.selected ? App.bg : chip.danger ? App.danger : App.fg
        font.weight: chip.selected ? Font.DemiBold : Font.Normal
        font.capitalization: App.capitalization
    }
    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: chip.clicked()
    }
    SFocus {
        onActivated: chip.clicked()
    }
}
