// One icon in the floating layout's dock (Dock.qml): the app's icon, a dot per
// open window under it (accent when focused), dimmed when minimized.
import QtQuick

Item {
    id: item

    required property QtObject theme
    property int size: 48
    property string source: ""
    property int count: 0
    property bool active: false
    property bool dim: false

    signal clicked
    signal rightClicked
    signal hovered(bool on, real cx)

    width: size
    height: size

    Rectangle {
        anchors.fill: parent
        radius: Math.round((item.theme?.radius ?? 12) * 0.8)
        color: mouse.containsMouse ? Qt.alpha(item.theme?.text ?? "#fff", 0.1) : (item.active ? Qt.alpha(item.theme?.accent ?? "#888", 0.14) : "transparent")
    }

    Image {
        id: img

        anchors.centerIn: parent
        anchors.verticalCenterOffset: -2
        width: Math.round(item.size * 0.7)
        height: width
        sourceSize: Qt.size(width * 2, height * 2)
        source: item.source
        smooth: true
        opacity: item.dim ? 0.45 : 1
        scale: mouse.pressed ? 0.88 : (mouse.containsMouse ? 1.1 : 1)

        Behavior on scale {
            NumberAnimation {
                duration: 120
                easing.type: Easing.OutCubic
            }
        }
    }

    // a dot per window, up to three
    Row {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 2
        spacing: 3

        Repeater {
            model: Math.min(3, item.count)

            Rectangle {
                width: 4
                height: 4
                radius: 2
                color: item.active ? (item.theme?.accent ?? "#fff") : Qt.alpha(item.theme?.text ?? "#fff", 0.5)
            }
        }
    }

    MouseArea {
        id: mouse

        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        cursorShape: Qt.PointingHandCursor
        onEntered: item.hovered(true, item.mapToItem(null, item.width / 2, 0).x)
        onExited: item.hovered(false, 0)
        onClicked: m => m.button === Qt.RightButton ? item.rightClicked() : item.clicked()
    }
}
