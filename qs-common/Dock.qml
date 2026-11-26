// The dock of the floating layout (SUPER + Backspace to floating): every open
// app, grouped, with a dot per window (the focused app's in the accent), then
// the minimized windows, dimmed, after a divider. Dressed in the rice.
//
//   click             focus the app (again: its next window)
//   right-click       minimize it (SUPER + H does the focused window)
//   click a minimized bring it back to this workspace
//
// Shown only in the floating layout: it watches ~/.local/state/hypr-rice/layout.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root

    required property QtObject theme
    property string layout: "tiling"
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/archonate"

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/hypr-rice/layout"
        watchChanges: true
        blockLoading: true
        onFileChanged: reload()
        onLoaded: {
            root.layout = text().trim() || "tiling";
            Hyprland.refreshToplevels(); // fresh classes for the icons
        }
        onLoadFailed: root.layout = "tiling"
    }

    function addr(t: var): string {
        const a = String(t.address ?? "");
        return a.startsWith("0x") ? a : "0x" + a;
    }
    function appOf(t: var): string {
        return t.wayland?.appId || t.lastIpcObject?.class || "app";
    }
    function minimized(t: var): bool {
        return t.workspace?.name === "special:minimized";
    }

    // [{ app, windows: [toplevel], active }] in first-seen order, then the
    // minimized windows one by one
    // real windows only: helpers (Steam keeps a few) have no app name or title
    readonly property var windows: Hyprland.toplevels.values.filter(t => t.address && t.title && (t.wayland?.appId || t.lastIpcObject?.class))
    readonly property var apps: {
        const order = [], by = {};
        for (const t of windows) {
            if (minimized(t))
                continue;
            const k = appOf(t);
            if (!by[k]) {
                by[k] = { app: k, windows: [], active: false };
                order.push(k);
            }
            by[k].windows.push(t);
            if (t.activated)
                by[k].active = true;
        }
        return order.map(k => by[k]);
    }
    readonly property var hidden: windows.filter(t => minimized(t))

    function icon(app: string): string {
        const e = DesktopEntries.heuristicLookup(app);
        return Quickshell.iconPath(e?.icon ?? app, "application-x-executable");
    }

    function focus(t: var): void {
        Hyprland.dispatch(Hyprland.usingLua ? `hl.dsp.focus({ window = "address:${addr(t)}" })` : `focuswindow address:${addr(t)}`);
    }
    // Click an app: focus it, or if it's already focused, its next window
    function activate(entry: var): void {
        const ws = entry.windows;
        const i = ws.findIndex(t => t.activated);
        focus(ws[i < 0 ? 0 : (i + 1) % ws.length]);
    }
    function minimize(entry: var): void {
        const t = entry.windows.find(w => w.activated) ?? entry.windows[0];
        Quickshell.execDetached([bin, "window", "minimize", addr(t)]);
    }
    function restore(t: var): void {
        Quickshell.execDetached([bin, "window", "restore", addr(t)]);
    }

    PanelWindow {
        id: win

        readonly property QtObject t: root.theme
        readonly property int r: t?.radius ?? 12
        readonly property int cell: 48

        visible: root.layout === "floating" && (root.apps.length + root.hidden.length) > 0
        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "archonate-dock"
        exclusionMode: ExclusionMode.Ignore
        anchors.bottom: true
        margins.bottom: 10
        implicitWidth: bar.implicitWidth + 2
        implicitHeight: bar.implicitHeight + 40 // room above for the name tag
        color: "transparent"

        // the name of the hovered app, above it
        Rectangle {
            id: tag

            property string text: ""
            property real cx: 0

            visible: text !== ""
            x: Math.max(0, Math.min(win.width - width, cx - width / 2))
            y: 0
            width: tagText.implicitWidth + 18
            height: tagText.implicitHeight + 10
            radius: Math.round(win.r * 0.6)
            color: win.t?.bg ?? "#111"
            border.width: Math.max(1, win.t?.borderWidth ?? 1)
            border.color: win.t?.border ?? "#40ffffff"

            Text {
                id: tagText

                anchors.centerIn: parent
                text: tag.text
                color: win.t?.text ?? "#fff"
                font.family: win.t?.font ?? "sans-serif"
                font.pixelSize: (win.t?.fontSize ?? 13) - 1
                elide: Text.ElideRight
                width: Math.min(implicitWidth, 360)
            }
        }

        Rectangle {
            id: bar

            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            implicitWidth: row.implicitWidth + 20
            implicitHeight: win.cell + 18
            radius: Math.round(win.r * 1.2)
            color: Qt.alpha(win.t?.bg ?? "#111", Math.max(0.9, win.t?.panelAlpha ?? 0.95))
            border.width: Math.max(1, win.t?.borderWidth ?? 1)
            border.color: win.t?.border ?? "#40ffffff"

            Row {
                id: row

                anchors.centerIn: parent
                spacing: 6

                Repeater {
                    model: root.apps

                    DockItem {
                        required property var modelData

                        theme: win.t
                        size: win.cell
                        source: root.icon(modelData.app)
                        count: modelData.windows.length
                        active: modelData.active
                        onHovered: (on, cx) => {
                            tag.text = on ? (modelData.windows.find(w => w.activated) ?? modelData.windows[0]).title : "";
                            tag.cx = cx;
                        }
                        onClicked: root.activate(modelData)
                        onRightClicked: root.minimize(modelData)
                    }
                }

                // minimized windows
                Rectangle {
                    visible: root.hidden.length > 0 && root.apps.length > 0
                    width: Math.max(1, win.t?.borderWidth ?? 1)
                    height: win.cell - 12
                    anchors.verticalCenter: parent.verticalCenter
                    color: Qt.alpha(win.t?.text ?? "#fff", 0.2)
                }
                Repeater {
                    model: root.hidden

                    DockItem {
                        required property var modelData

                        theme: win.t
                        size: win.cell
                        source: root.icon(root.appOf(modelData))
                        dim: true
                        onHovered: (on, cx) => {
                            tag.text = on ? modelData.title + "  (minimized)" : "";
                            tag.cx = cx;
                        }
                        onClicked: root.restore(modelData)
                        onRightClicked: root.restore(modelData)
                    }
                }
            }
        }
    }
}
