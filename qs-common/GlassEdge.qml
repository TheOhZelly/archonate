// 1px highlight along the top of a glass surface, like light catching the
// material. Only drawn for rices whose Theme sets `glass: true`.
import QtQuick

Rectangle {
    required property QtObject theme
    property real radius: 0

    visible: theme.glass ?? false
    anchors.top: parent.top
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: radius * 0.8
    anchors.rightMargin: radius * 0.8
    height: 1
    color: Qt.rgba(1, 1, 1, 0.22)
}
