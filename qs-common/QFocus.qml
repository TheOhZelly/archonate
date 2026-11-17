// Makes its parent reachable from the keyboard inside a panel: Tab lands
// here, Space or Enter activates it, and a ring in the rice's accent shows
// where you are. Put one inside any clickable panel control, last.
import QtQuick

Item {
    id: f

    property real radius: parent?.radius ?? 8
    signal activated

    anchors.fill: parent
    activeFocusOnTab: enabled
    Keys.onSpacePressed: activated()
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()

    Rectangle {
        anchors.fill: parent
        anchors.margins: -3
        radius: f.radius + 3
        color: "transparent"
        border.width: 2
        border.color: Arch.theme?.accent ?? "#888"
        visible: f.activeFocus
    }
}
