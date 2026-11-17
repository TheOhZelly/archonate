// A small on/off switch in the rice's accent.
import QtQuick

Rectangle {
    id: sw

    property bool checked: false
    signal toggled

    readonly property QtObject t: Arch.theme
    readonly property bool round: (t?.radius ?? 8) > 0

    implicitWidth: 38
    implicitHeight: 22
    radius: round ? height / 2 : 0
    color: checked ? (t?.accent ?? "#888") : Qt.alpha(t?.text ?? "#fff", 0.15)
    Behavior on color { ColorAnimation { duration: 140 } }

    Rectangle {
        x: sw.checked ? sw.width - width - 3 : 3
        anchors.verticalCenter: parent.verticalCenter
        width: 16
        height: 16
        radius: sw.round ? 8 : 0
        color: sw.checked ? (sw.t?.bg ?? "#000") : (sw.t?.text ?? "#fff")
        Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: sw.toggled()
    }
    QFocus {
        onActivated: sw.toggled()
    }
}
