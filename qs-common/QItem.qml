// A row in a panel list: icon, title, subtitle, trailing text/children.
import QtQuick

Rectangle {
    id: row

    property string icon: ""
    property string title: ""
    property string sub: ""
    property string trailing: ""
    property bool active: false
    property bool busy: false
    default property alias extra: tail.data
    signal clicked

    readonly property QtObject t: Arch.theme

    implicitWidth: 300
    implicitHeight: sub !== "" ? 48 : 38
    radius: Math.round((t?.radius ?? 10) * 0.6)
    color: active ? Qt.alpha(t?.accent ?? "#888", 0.2) : ma.containsMouse ? Qt.alpha(t?.text ?? "#fff", 0.07) : "transparent"

    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: row.clicked()
    }
    QFocus {
        z: 2
        onActivated: row.clicked()
    }

    Icon {
        id: ic

        x: 8
        anchors.verticalCenter: parent.verticalCenter
        visible: row.icon !== ""
        name: row.busy ? "progress_activity" : row.icon
        size: 18
        fill: row.active
        color: row.active ? (row.t?.accent ?? "#888") : (row.t?.textDim ?? "#999")
        RotationAnimation on rotation {
            running: row.busy
            loops: Animation.Infinite
            from: 0
            to: 360
            duration: 900
        }
    }
    Column {
        anchors.left: ic.visible ? ic.right : parent.left
        anchors.leftMargin: ic.visible ? 10 : 10
        anchors.right: tail.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter

        QText {
            width: parent.width
            text: row.title
            font.weight: row.active ? Font.DemiBold : Font.Normal
        }
        QText {
            width: parent.width
            visible: row.sub !== ""
            text: row.sub
            dim: true
            size: (row.t?.fontSize ?? 13) - 2
        }
    }
    Row {
        id: tail

        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        QText {
            visible: row.trailing !== ""
            anchors.verticalCenter: parent.verticalCenter
            text: row.trailing
            dim: true
            size: (row.t?.fontSize ?? 13) - 1
        }
    }
}
