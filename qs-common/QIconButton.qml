// Round (or square, per rice) icon button with an optional caption under it.
import QtQuick

Column {
    id: b

    property string icon: ""
    property string caption: ""
    property bool accent: false
    property real size: 44
    signal clicked

    readonly property QtObject t: Arch.theme
    spacing: 6

    Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: b.size
        height: b.size
        radius: (b.t?.radius ?? 8) > 0 ? b.size / 2 : 0
        color: b.accent ? (b.t?.accent ?? "#888") : ma.containsMouse ? Qt.alpha(b.t?.text ?? "#fff", 0.14) : Qt.alpha(b.t?.text ?? "#fff", 0.07)
        scale: ma.pressed ? 0.94 : 1
        Behavior on scale { NumberAnimation { duration: 90 } }

        Icon {
            anchors.centerIn: parent
            name: b.icon
            size: b.size * 0.46
            color: b.accent ? (b.t?.bg ?? "#000") : (b.t?.text ?? "#fff")
        }
        MouseArea {
            id: ma

            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: b.clicked()
        }
        QFocus {
            onActivated: b.clicked()
        }
    }
    QText {
        visible: b.caption !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        text: Arch.caps(b.caption)
        dim: true
        size: (b.t?.fontSize ?? 13) - 2
    }
}
