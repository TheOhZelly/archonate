// Drop inside any bar item to make it lead somewhere:
//   Icon { name: "wifi"; PanelHook { name: "network" } }
// Left click toggles that quick panel under (or beside) the item. Right click
// fires `secondary` (e.g. mute), the wheel fires the usual onWheel. The item
// is also registered so `archonate panel <name>` can open the panel there.
import QtQuick
import Quickshell

MouseArea {
    id: hook

    required property string name
    property Item target: parent
    property real grow: 6 // easier to hit than the glyph itself

    signal secondary
    readonly property var win: QsWindow.window

    anchors.fill: parent
    anchors.margins: -grow
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
    onClicked: m => {
        if (m.button === Qt.LeftButton)
            Arch.panels?.toggle(hook.name, hook.target, hook.win);
        else
            hook.secondary();
    }

    function reg(): void {
        if (Arch.panels && !registered) {
            Arch.panels.register(name, hook);
            registered = true;
        }
    }
    property bool registered: false
    Component.onCompleted: reg()
    Connections {
        target: Arch

        function onPanelsChanged(): void {
            hook.reg();
        }
    }
    Component.onDestruction: Arch.panels?.unregister(hook)
}
