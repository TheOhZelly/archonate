import QtQuick

// On/off switch. Emits toggled(); the owner flips `checked` from real state.
Rectangle {
    id: toggle

    property bool checked: false
    signal toggled

    implicitWidth: 46
    implicitHeight: 26
    radius: App.r(13)
    color: checked ? App.accent : Qt.alpha(App.fg, 0.15)

    Rectangle {
        x: toggle.checked ? parent.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 20
        height: 20
        radius: App.r(10)
        color: toggle.checked ? App.bg : App.fg
        Behavior on x {
            NumberAnimation {
                duration: 160
                easing.type: Easing.OutCubic
            }
        }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: toggle.toggled()
    }
    SFocus {
        onActivated: toggle.toggled()
    }
}
