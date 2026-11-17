// Quick panels: small popups that open from the bar (PanelHook) or from
// `archonate panel <name>`. One is open at a time; clicking outside, Escape,
// or clicking its bar item again closes it. Each panel is Panel<Name>.qml,
// styled from the rice's Theme, and links on to its Settings page.
//   control  network  bluetooth  sound  calendar  media  power  updates
import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland

Scope {
    id: root

    readonly property var names: ["control", "network", "bluetooth", "sound", "calendar", "media", "power", "updates"]

    property string current: ""
    property var win: null // the bar window it hangs from
    property rect at: Qt.rect(0, 0, 0, 0) // the bar item, in screen coordinates
    property string edge: "top" // which screen edge that bar sits on
    readonly property bool isOpen: current !== ""

    // name -> [PanelHook] from every bar on every screen; a hook knows its
    // item (target) and, once shown, its window (win)
    property var hooks: ({})

    function register(name: string, hook: var): void {
        const h = hooks;
        (h[name] = h[name] ?? []).push(hook);
        hooks = h;
    }

    function unregister(hook: var): void {
        const h = hooks;
        for (const n in h)
            h[n] = h[n].filter(e => e !== hook);
        hooks = h;
    }

    function toggle(name: string, item: Item, w: var): void {
        if (current === name && win === w)
            close();
        else
            open(name, item, w);
    }

    // From IPC: hang it off the matching bar item on the focused screen, else
    // off any registered item there (the control button usually exists)
    function openNamed(name: string): void {
        if (!names.includes(name))
            return;
        const mon = Hyprland.focusedMonitor?.name;
        const pick = list => (list ?? []).filter(e => e.win && e.target?.visible).sort((a, b) => (b.win.screen?.name === mon) - (a.win.screen?.name === mon))[0];
        let e = pick(hooks[name]);
        if (!e)
            for (const n in hooks)
                if ((e = pick(hooks[n])))
                    break;
        if (e)
            open(name, e.target, e.win);
    }

    function open(name: string, item: Item, w: var): void {
        if (!item || !w)
            return;
        // The item's place on screen: its place in the bar window, plus where
        // the bar's anchors and margins put that window
        const p = item.mapToItem(w.contentItem, 0, 0);
        const sw = w.screen?.width ?? 1920, sh = w.screen?.height ?? 1080;
        const a = w.anchors, m = w.margins;
        const wx = a?.left ? (m?.left ?? 0) : a?.right ? sw - w.width - (m?.right ?? 0) : (sw - w.width) / 2;
        const wy = a?.top ? (m?.top ?? 0) : a?.bottom ? sh - w.height - (m?.bottom ?? 0) : (sh - w.height) / 2;
        const horizontal = w.width >= w.height;
        edge = horizontal ? (a?.bottom && !a?.top ? "bottom" : "top") : (a?.right && !a?.left ? "right" : "left");
        at = Qt.rect(wx + p.x, wy + p.y, item.width, item.height);
        win = w;
        current = "";
        current = name;
    }

    // Go deeper from inside a panel (control -> network), same spot
    function swap(name: string): void {
        if (names.includes(name))
            current = name;
    }

    function close(): void {
        current = "";
    }

    // Its own overlay surface (not a popup of the bar: Hyprland 0.57.2 stopped
    // giving bar popups input), placed beside the bar item and kept on screen
    PanelWindow {
        id: pane

        readonly property int gap: 10
        readonly property real sw: screen?.width ?? 1920
        readonly property real sh: screen?.height ?? 1080

        function clamp(v: real, lo: real, hi: real): real {
            return Math.max(lo, Math.min(hi, v));
        }

        screen: root.win?.screen ?? null
        visible: root.isOpen && root.win !== null
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-panel"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            left: true
        }
        margins {
            left: Math.round(pane.clamp(root.edge === "left" ? root.at.x + root.at.width + pane.gap : root.edge === "right" ? root.at.x - pane.gap - frame.width : root.at.x + root.at.width / 2 - frame.width / 2, pane.gap, pane.sw - frame.width - pane.gap))
            top: Math.round(pane.clamp(root.edge === "top" ? root.at.y + root.at.height + pane.gap : root.edge === "bottom" ? root.at.y - pane.gap - frame.height : root.at.y + root.at.height / 2 - frame.height / 2, pane.gap, pane.sh - frame.height - pane.gap))
        }
        implicitWidth: frame.width
        implicitHeight: frame.height
        color: "transparent"

        PanelFrame {
            id: frame

            focus: true
            Keys.onEscapePressed: root.close()

            Loader {
                id: body

                active: root.isOpen
                source: root.current ? "Panel" + root.current[0].toUpperCase() + root.current.slice(1) + ".qml" : ""
            }

            // Grow out of the bar
            opacity: pane.visible ? 1 : 0
            scale: pane.visible ? 1 : 0.94
            transformOrigin: root.edge === "top" ? Item.Top : root.edge === "bottom" ? Item.Bottom : root.edge === "left" ? Item.Left : Item.Right
            Behavior on opacity {
                NumberAnimation {
                    duration: 160
                }
            }
            Behavior on scale {
                NumberAnimation {
                    duration: 220
                    easing.type: Easing.OutCubic
                }
            }
        }
    }

    HyprlandFocusGrab {
        active: pane.visible
        windows: [pane, root.win].filter(w => w)
        onCleared: root.close()
    }
}
