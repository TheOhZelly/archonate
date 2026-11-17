// Workspace strip, horizontal (default) or `vertical`. The rice supplies
// `delegate` (gets `index`; wsId = index + 1) and asks this object for state:
// isActive(id), isOccupied(id), isUrgent(id), shown(id); clicking should call goTo(id).
import QtQuick
import Quickshell
import Quickshell.Hyprland

Item {
    id: root

    property int count: 10
    property bool vertical: false
    property real spacing: 0
    property Component delegate

    implicitWidth: vertical ? col.implicitWidth : row.implicitWidth
    implicitHeight: vertical ? col.implicitHeight : row.implicitHeight

    function ws(id: int): var {
        return Hyprland.workspaces.values.find(w => w.id === id) ?? null;
    }

    function isActive(id: int): bool {
        return Hyprland.focusedWorkspace?.id === id;
    }

    function isOccupied(id: int): bool {
        return (ws(id)?.toplevels?.values?.length ?? 0) > 0;
    }

    function isUrgent(id: int): bool {
        return ws(id)?.urgent ?? false;
    }

    // Always show 1-5; show 6-10 only when they exist
    function shown(id: int): bool {
        return id <= 5 || ws(id) !== null;
    }

    function goTo(id: int): void {
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ workspace = "${id}" })` : `workspace ${id}`);
    }

    Row {
        id: row

        height: parent.height
        visible: !root.vertical
        spacing: root.spacing

        Repeater {
            model: root.vertical ? 0 : root.count
            delegate: root.delegate
        }
    }

    Column {
        id: col

        width: parent.width
        visible: root.vertical
        spacing: root.spacing

        Repeater {
            model: root.vertical ? root.count : 0
            delegate: root.delegate
        }
    }
}
