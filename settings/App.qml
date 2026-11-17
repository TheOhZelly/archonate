// Shared state for the Settings app: data from `desktop.py settings`, the
// active rice's colours, and helpers every page uses.
pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string py: home + "/.config/hypr/lib/desktop.py"
    readonly property string bin: home + "/.local/bin/"

    property var info: ({ rice: "", mode: "", modes: [], rices: [], sounds: [], global: {} })
    property string editRice: "" // standalone rice the per-rice pages edit

    readonly property var current: info.rices.find(r => r.name === info.rice) ?? { bg: "16161a", accent: "a79bf0", text: "f0f0f0" }
    readonly property var standalone: info.rices.filter(r => r.standalone)
    readonly property var edited: standalone.find(r => r.name === editRice) ?? standalone[0] ?? null

    // The active rice's whole look (desktop.py rice_look): palette, font,
    // corners, border weight, text casing. Settings dresses itself in it.
    readonly property var look: info.look ?? ({})
    readonly property var pal: look.palette ?? ({})
    function hex(k: string, d: string): color {
        return "#" + (pal[k] ?? d);
    }

    readonly property color bg: hex("bg", current.bg)
    readonly property color fg: hex("text", current.text)
    readonly property color accent: hex("accent", current.accent)
    readonly property color panel: hex("surface", "202020")
    readonly property color card: Qt.tint(hex("surface", "202020"), Qt.alpha(hex("surface_hi", "303030"), 0.45))
    readonly property color line: bw > 1 ? Qt.alpha(accent, 0.35) : Qt.alpha(fg, 0.12)
    readonly property color dim: hex("text_dim", "999999")
    readonly property color danger: hex("error", "ff5f57")
    readonly property string font: look.font ?? "Adwaita Sans"

    // Corners scale with the rice (ashen 0 = sharp, kyoto 16 = soft)
    readonly property real radiusScale: (look.radius ?? 14) / 14
    function r(base: real): real {
        return Math.round(base * radiusScale);
    }
    readonly property int bw: Math.max(1, Math.min(3, look.borderWidth ?? 1))

    // Headings and navigation follow the rice's casing
    readonly property int capitalization: look.caps === "lower" ? Font.AllLowercase : look.caps === "upper" ? Font.AllUppercase : Font.MixedCase
    readonly property bool lowerRice: look.caps === "lower"

    function refresh(): void {
        loader.running = true;
    }

    // Run a command, then reload settings
    function exec(cmd: var): void {
        const p = runnerComp.createObject(root, { command: cmd });
        p.running = true;
    }

    // Fire and forget
    function detached(cmd: var): void {
        Quickshell.execDetached(cmd);
    }

    // Every switch goes through archonate, so the bar, keys and this app agree
    function toggle(id: string, on: bool): void {
        exec([bin + "archonate", "toggle", id, on ? "on" : "off"]);
    }

    function setRice(key: string, value: var): void {
        exec(["python3", py, "set", edited.name, key, JSON.stringify(value)]);
    }

    function setGlobal(key: string, value: var): void {
        exec(["python3", py, "set", "global", key, JSON.stringify(value)]);
    }

    function global(key: string, def: var): var {
        const v = info.global?.[key];
        return v === undefined ? def : v;
    }

    // Run a command and get (exitCode, stdout, stderr) back
    function run(cmd: var, done: var): void {
        const p = captureComp.createObject(root, { command: cmd, done: done });
        p.running = true;
    }

    Component {
        id: captureComp

        Process {
            id: cap

            property var done: null

            stdout: StdioCollector {
                id: out
            }
            stderr: StdioCollector {
                id: err
            }
            onExited: code => {
                if (cap.done)
                    cap.done(code, out.text, err.text);
                destroy();
            }
        }
    }

    Component {
        id: runnerComp

        Process {
            onExited: {
                root.refresh();
                destroy();
            }
        }
    }

    Process {
        id: loader

        running: true
        command: ["python3", root.py, "settings"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.info = JSON.parse(text);
                if (!root.standalone.find(r => r.name === root.editRice))
                    root.editRice = (root.standalone.find(r => r.name === root.info.rice) ?? root.standalone[0])?.name ?? "";
            }
        }
    }

    // Follow changes made elsewhere (bar, keybinds, the CLI) while open
    Timer {
        id: debounce

        interval: 250
        onTriggered: root.refresh()
    }
    FileView {
        path: root.home + "/.local/state/hypr-rice/settings.json"
        watchChanges: true
        printErrors: false
        onFileChanged: debounce.restart()
    }
    FileView {
        path: root.home + "/.local/state/hypr-rice/effects.json"
        watchChanges: true
        printErrors: false
        onFileChanged: debounce.restart()
    }
    FileView {
        path: root.home + "/.config/hypr/active-rice.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: debounce.restart()
    }
    FileView {
        path: root.home + "/.local/state/hypr-rice/archonate/desktop.json"
        watchChanges: true
        printErrors: false
        onFileChanged: debounce.restart()
    }
    FileView {
        path: root.home + "/.config/hypr/active-mode.lua"
        watchChanges: true
        printErrors: false
        onFileChanged: debounce.restart()
    }
}
