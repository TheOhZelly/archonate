// The desktop's switches, live. Each one reads the file its owner writes
// (settings.json, effects.json, the active mode), and every change goes
// through `archonate toggle`, so the bar, quick panels, keybinds, the menu and
// the Settings app always agree.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property Settings cfg
    required property string mode

    property var effects: ({})

    readonly property bool nightlight: cfg.globalVal("nightlight", {})?.enabled ?? false
    readonly property bool dnd: cfg.globalVal("dnd", false)
    readonly property bool caffeine: cfg.globalVal("caffeine", false)
    readonly property bool gaming: mode === "gaming"
    readonly property bool widgets: effects.widgets ?? true
    readonly property bool screensaver: effects.screensaver ?? true
    readonly property bool intros: effects.intros ?? true

    // id, label, icon (Material Symbols) — the order quick panels show them in
    readonly property var all: [
        ["dnd", "Do not disturb", "do_not_disturb_on", "notifications_active"],
        ["nightlight", "Night light", "nightlight", "light_mode"],
        ["caffeine", "Keep awake", "coffee", "bedtime"],
        ["gaming", "Gaming mode", "sports_esports", "sports_esports"],
        ["widgets", "Desktop widget", "widgets", "widgets"],
        ["screensaver", "Screensaver", "animation", "animation"],
        ["intros", "Wallpaper intros", "movie", "movie"]
    ]

    // Fired after a switch changes (not at startup), for the OSD
    signal changed(string id, string label, string icon, bool on)

    function state(id: string): bool {
        return root[id] ?? false;
    }

    function set(id: string, on: bool): void {
        Quickshell.execDetached([Quickshell.env("HOME") + "/.local/bin/archonate", "toggle", id, on ? "on" : "off"]);
    }

    function flip(id: string): void {
        set(id, !state(id));
    }

    function label(id: string): string {
        return all.find(t => t[0] === id)?.[1] ?? id;
    }

    function icon(id: string, on: bool): string {
        const t = all.find(t => t[0] === id);
        return t ? (on ? t[2] : t[3]) : "toggle_on";
    }

    // Announce changes once startup values have settled
    property bool armed: false
    property var last: ({})

    function check(): void {
        const now = {};
        for (const t of all)
            now[t[0]] = state(t[0]);
        if (armed)
            for (const id in now)
                if (last[id] !== undefined && last[id] !== now[id])
                    changed(id, label(id), icon(id, now[id]), now[id]);
        last = now;
    }

    onNightlightChanged: check()
    onDndChanged: check()
    onCaffeineChanged: check()
    onGamingChanged: check()
    onWidgetsChanged: check()
    onScreensaverChanged: check()
    onIntrosChanged: check()

    Timer {
        running: true
        interval: 1500
        onTriggered: {
            root.check();
            root.armed = true;
        }
    }

    FileView {
        path: Quickshell.env("HOME") + "/.local/state/hypr-rice/effects.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.effects = JSON.parse(text());
            } catch (e) {}
        }
    }
}
