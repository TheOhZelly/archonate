import QtQuick

// Makes its parent reachable from the keyboard: Tab lands here, Space or Enter
// activates it, and an accent ring shows where you are. Put one inside any
// clickable control (last, so the ring draws on top).
Item {
    id: f

    property bool inset: false // the parent clips: draw the ring inside it
    property real radius: parent?.radius ?? App.r(10)
    signal activated

    anchors.fill: parent
    activeFocusOnTab: enabled
    Keys.onSpacePressed: activated()
    Keys.onReturnPressed: activated()
    Keys.onEnterPressed: activated()

    Rectangle {
        anchors.fill: parent
        anchors.margins: f.inset ? 2 : -4
        radius: f.inset ? Math.max(0, f.radius - 2) : f.radius + 4
        color: "transparent"
        border.width: 2
        border.color: App.accent
        visible: f.activeFocus
    }
}
