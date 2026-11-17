// Live view of ~/.local/state/hypr-rice/settings.json (written by the Rice
// Settings app through `desktop.py set`). Changes apply without a reload.
//   { "global": { "idleMinutes": 10, ... }, "rices": { "<rice>": { "notifSound": ... } } }
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property var data: ({})
    readonly property string rice: Quickshell.shellPath("").replace(/\/shell\/?$/, "").split("/").pop()

    // This rice's value for key, else def
    function riceVal(key: string, def: var): var {
        const v = data.rices?.[rice]?.[key];
        return v === undefined ? def : v;
    }

    function globalVal(key: string, def: var): var {
        const v = data.global?.[key];
        return v === undefined ? def : v;
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/hypr-rice/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.data = JSON.parse(text());
            } catch (e) {
                root.data = {};
            }
        }
        onLoadFailed: root.data = {}
    }
}
