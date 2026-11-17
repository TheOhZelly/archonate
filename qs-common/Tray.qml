// System tray icons, in a row or a column (`vertical`). Left click activates,
// right click opens the item's menu.
import QtQuick
import Quickshell
import Quickshell.Widgets
import Quickshell.Services.SystemTray

Grid {
    id: root

    required property var window
    property int iconSize: 16
    property bool mono: false
    property bool vertical: false

    columns: vertical ? 1 : Math.max(1, SystemTray.items.values.length)

    Repeater {
        model: SystemTray.items

        MouseArea {
            id: area

            required property SystemTrayItem modelData

            implicitWidth: root.iconSize
            implicitHeight: root.iconSize
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: event => {
                if (event.button === Qt.LeftButton && !modelData.onlyMenu) {
                    modelData.activate();
                } else if (modelData.hasMenu) {
                    const p = root.vertical ? area.mapToItem(null, root.iconSize + 10, 0) : area.mapToItem(null, 0, root.iconSize + 6);
                    modelData.display(root.window, p.x, p.y);
                }
            }

            IconImage {
                anchors.fill: parent
                source: area.modelData.icon
                asynchronous: true
                opacity: root.mono ? 0.85 : 1
            }
        }
    }
}
