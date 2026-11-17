// This rice's colours, live from rices/<rice>/desktop.json ("palette"), the
// one place they are written. Theme.qml binds to it: color: pal.c("accent").
// Editing desktop.json recolours the running shell without a restart.
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string rice: Quickshell.shellPath("").replace(/\/shell\/?$/, "").split("/").pop()
    // First read is synchronous (blockLoading), so nothing renders before the
    // colours exist; onLoaded keeps it current after edits
    property var p: parse()

    function parse(): var {
        try {
            return JSON.parse(file.text()).palette ?? {};
        } catch (e) {
            return {};
        }
    }

    // "#rrggbb" for a palette key; magenta when missing, so a typo shows
    function c(key: string): color {
        const v = p[key];
        return v ? "#" + v : "#ff00ff";
    }

    property FileView file: FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/rices/" + root.rice + "/desktop.json"
        blockLoading: true
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root.p = root.parse()
    }
}
