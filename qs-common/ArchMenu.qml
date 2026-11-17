// The Archonate menu, part of the shell (SUPER+Escape, `archonate menu`).
// Dressed in the rice; everything the desktop can do, nested and searchable:
// type at the top level to search every submenu at once. ↑/↓ move, Enter or
// → opens, ← or Backspace (empty search) goes back, Esc closes. Switches flip
// in place and the menu stays open.
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
    property bool open: false
    property var data: ({ rices: [], modes: [], styles: [], keybinds: [], catalog: {}, rice: "", mode: "", style: "" })
    property var stack: [] // [{ title, items }]
    property string query: ""
    property int sel: 0
    property string pending: ""
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/archonate"

    readonly property var level: stack.length ? stack[stack.length - 1] : ({ title: "archonate", items: [] })
    readonly property var shown: {
        const q = query.trim().toLowerCase();
        if (q === "")
            return level.items;
        // Punctuation doesn't count ("wifi" finds Wi-Fi), and the same action
        // reachable two ways shows once
        const norm = x => String(x).toLowerCase().replace(/[^a-z0-9]+/g, "");
        const nq = norm(q);
        const pool = stack.length === 1 ? everything() : level.items;
        const hit = it => norm(it.label + (it.hint ?? "") + (it.path ?? "")).includes(nq) || (it.label + " " + (it.hint ?? "")).toLowerCase().includes(q);
        const starts = it => norm(it.label).startsWith(nq) ? 0 : 1;
        const seen = {};
        return pool.filter(hit).filter(it => {
            const k = it.label + "|" + JSON.stringify(it.run ?? it.sub ?? it.toggle ?? it.term ?? "");
            return seen[k] ? false : (seen[k] = true);
        }).sort((a, b) => (a.info ? 1 : 0) - (b.info ? 1 : 0) || starts(a) - starts(b)).slice(0, 60);
    }

    function caps(s: string): string {
        return theme?.caps ? theme.caps(s) : s;
    }

    // ---- open / close ---------------------------------------------------------
    function show(section: string): void {
        if (open && section === "") {
            close();
            return;
        }
        pending = section;
        query = "";
        sel = 0;
        stack = [{ title: "archonate", items: build("root") }];
        open = true;
        loader.running = true;
    }

    function close(): void {
        open = false;
        stack = [];
        query = "";
    }

    Process {
        id: loader

        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/lib/desktop.py", "menu-data"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.data = JSON.parse(text);
                } catch (e) {}
                // Rebuild with fresh data, keeping where we are
                const titles = root.stack.map(l => l.title);
                root.stack = [{ title: "archonate", items: root.build("root") }];
                const jump = { rice: "rices", theme: "rices", style: "styles", styles: "styles", ai: "ai", agent: "ai", mode: "modes", wallpaper: "wallpaper", toggles: "toggles", switches: "toggles", panels: "panels", capture: "capture", settings: "settings", keys: "keys", keybindings: "keys", install: "install", remove: "remove", update: "update", power: "power" }[root.pending];
                if (jump) {
                    const it = root.stack[0].items.find(i => i.sub === jump);
                    if (it)
                        root.push(it);
                }
                root.pending = "";
            }
        }
    }

    // ---- the tree ----------------------------------------------------------------
    // An item: { label, icon, hint, sub (builder name) | run [archonate args]
    //            | toggle id | term "command" ; current, delay, color, info }
    function build(name: string): var {
        const d = data;
        switch (name) {
        case "root":
            return [
                { label: "Rice", icon: "palette", hint: d.rice, sub: "rices" },
                ...((d.styled ?? []).includes(d.rice) && d.styles.length ? [{ label: "Style", icon: "style", hint: (d.styles.find(s => s.name === d.style)?.title ?? ""), sub: "styles" }] : []),
                { label: "Mode", icon: "tune", hint: d.mode, sub: "modes" },
                { label: "Wallpaper", icon: "wallpaper", sub: "wallpaper" },
                { label: "Switches", icon: "toggle_on", sub: "toggles" },
                { label: "Quick panels", icon: "dashboard", sub: "panels" },
                { label: "Capture", icon: "screenshot_region", sub: "capture" },
                { label: "AI", icon: "smart_toy", sub: "ai" },
                { label: "Settings", icon: "settings", sub: "settings" },
                { label: "Keyboard shortcuts", icon: "keyboard", sub: "keys" },
                { label: "Install", icon: "download", sub: "install" },
                { label: "Remove", icon: "delete", sub: "remove" },
                { label: "Update", icon: "system_update", sub: "update" },
                { label: "Clipboard", icon: "content_paste", sub: "clipboard" },
                { label: "Emoji", icon: "mood", run: ["emoji"], delay: 0.15 },
                { label: "Power", icon: "power_settings_new", sub: "power" }
            ];
        case "ai":
            // Your coding agent and what it can do here (archonate agent ...)
            return [
                { label: "Open coding agent", icon: "terminal", hint: "SUPER+A", run: ["agent"] },
                { label: "Choose the agent", icon: "swap_horiz", run: ["agent", "default", "--pick"], delay: 0.15 },
                { label: "Teach agents Archonate", icon: "school", hint: "skills", run: ["agent", "skills", "on"] },
                { label: "Install AI tools", icon: "download", run: ["install", "ai"], delay: 0.15 }
            ];
        case "rices":
            return [
                { label: "Visual picker", icon: "view_carousel", run: ["theme", "pick"] },
                ...d.rices.map(r => ({ label: r, icon: "palette", current: r === d.rice, run: ["theme", "set", r] })),
                ...(d.styles.length ? [{ label: "Styles for " + (d.styleRice ?? "archonate"), icon: "style", sub: "styles" }] : [])
            ];
        case "styles":
            return [
                { label: "New style from a wallpaper", icon: "add_photo_alternate", hint: "any image", run: ["style", "from"] },
                ...d.styles.map(s => ({ label: s.title, color: "#" + s.accent, current: d.rice === d.styleRice && s.name === d.style, run: ["style", "set", s.name, d.styleRice ?? "archonate"] })),
                ...(d.styles.some(s => s.mine) ? [{ label: "Remove a style you made", icon: "delete", sub: "styles-remove" }] : [])
            ];
        case "styles-remove":
            // only styles made from a wallpaper, and not the one being worn; they go to the trash
            return d.styles.filter(s => s.mine).map(s => (d.rice === d.styleRice && s.name === d.style
                ? { label: s.title, color: "#" + s.accent, hint: "wearing it", current: true }
                : { label: s.title, color: "#" + s.accent, icon: "delete", hint: "to the trash", run: ["style", "remove", s.name] }));
        case "modes":
            return d.modes.map(m => ({ label: m, icon: m === "gaming" ? "sports_esports" : m === "minimal" ? "crop_free" : "tune", current: m === d.mode, run: ["mode", "set", m] }));
        case "wallpaper":
            return [
                { label: "Switcher", icon: "view_carousel", run: ["wallpaper", "pick"] },
                { label: "Next", icon: "skip_next", run: ["wallpaper", "next"], stay: true },
                { label: "Previous", icon: "skip_previous", run: ["wallpaper", "prev"], stay: true },
                { label: "Wallpaper settings", icon: "settings", run: ["settings", "wallpaper"] }
            ];
        case "toggles":
            return (Arch.toggles?.all ?? []).map(t => ({ label: t[1], icon: t[2], toggle: t[0] }));
        case "panels":
            return [["control", "Quick settings", "tune"], ["network", "Network", "wifi"], ["bluetooth", "Bluetooth", "bluetooth"], ["sound", "Sound", "volume_up"], ["calendar", "Calendar", "calendar_month"], ["media", "Now playing", "music_note"], ["power", "Power", "power_settings_new"], ["updates", "Updates", "system_update"]].map(p => ({ label: p[1], icon: p[2], run: ["panel", p[0]], delay: 0.1 }));
        case "capture":
            return [
                { label: "Screenshot a region", icon: "screenshot_region", run: ["capture", "region"], delay: 0.25 },
                { label: "Screenshot the screen", icon: "screenshot_monitor", run: ["capture", "shot"], delay: 0.35 },
                { label: "Copy text from the screen", icon: "document_scanner", run: ["capture", "text"], delay: 0.25 },
                { label: "Record the screen", icon: "videocam", run: ["capture", "record"], delay: 0.25 },
                { label: "Record with sound", icon: "mic", run: ["capture", "record-sound"], delay: 0.25 },
                { label: "Record a region", icon: "screenshot_region", run: ["capture", "record-region"], delay: 0.25 },
                { label: "Stop recording", icon: "stop_circle", run: ["capture", "record"] }
            ];
        case "settings":
            return [["wifi", "Wi-Fi", "wifi"], ["bluetooth", "Bluetooth", "bluetooth"], ["sound", "Sound", "volume_up"], ["display", "Display", "desktop_windows"], ["input", "Keyboard & mouse", "keyboard"], ["shortcuts", "Keyboard shortcuts", "keyboard_command_key"], ["nightlight", "Night light", "nightlight"], ["rices", "Rices & modes", "palette"], ["wallpaper", "Wallpaper", "wallpaper"], ["schedule", "Day & night", "routine"], ["bar", "Bar & desktop", "toolbar"], ["notifications", "Notifications", "notifications"], ["updates", "Updates", "system_update"], ["startup", "Startup apps", "rocket_launch"], ["storage", "Storage", "hard_drive"], ["time", "Date & time", "schedule"], ["power", "Lock & power", "power_settings_new"], ["apps", "Default apps", "apps"], ["about", "About", "info"]].map(p => ({ label: p[1], icon: p[2], run: ["settings", p[0]] }));
        case "keys":
            return d.keybinds.map(b => ({ label: b.label, icon: "keyboard", hint: b.keys.join("  or  "), info: true, path: b.group }));
        case "install":
            return [
                { label: "Search packages (repos)", icon: "search", run: ["install", "search"] },
                { label: "Search the AUR", icon: "package_2", run: ["install", "aur"] },
                ...Object.keys(d.catalog).map(s => ({ label: s, icon: sectionIcon(s), sub: "install:" + s, hint: d.catalog[s].filter(i => i.installed).length + "/" + d.catalog[s].length }))
            ];
        case "remove":
            return [
                { label: "Search installed packages", icon: "search", run: ["remove", "search"] },
                ...Object.keys(d.catalog).filter(s => d.catalog[s].some(i => i.installed)).map(s => ({ label: s, icon: sectionIcon(s), sub: "remove:" + s }))
            ];
        case "update":
            return [
                { label: "Update now", icon: "download", hint: "cachy-update, snapshot first", run: ["update"] },
                { label: "News", icon: "newspaper", hint: "read before big updates", term: "archonate update news" },
                { label: "Services to restart", icon: "restart_alt", term: "archonate update services" },
                { label: "What's waiting", icon: "system_update", run: ["panel", "updates"], delay: 0.1 },
                { label: "Health check", icon: "health_and_safety", hint: "archonate doctor", term: "archonate doctor" },
                { label: "Snapshots", icon: "history", term: "archonate snapshot list" }
            ];
        case "clipboard":
            return [
                { label: "History", icon: "content_paste", hint: "SUPER+V", run: ["clipboard"], delay: 0.15 },
                { label: "Forget one", icon: "backspace", hint: "SUPER+ALT+V", run: ["clipboard", "delete"], delay: 0.15 },
                { label: "Forget everything", icon: "delete_sweep", hint: "SUPER+CTRL+SHIFT+V", run: ["clipboard", "wipe"] }
            ];
        case "power":
            return [
                { label: "Screensaver", icon: "animation", run: ["screensaver"], delay: 0.3 },
                { label: "Lock", icon: "lock", run: ["lock"] },
                { label: "Log out", icon: "logout", run: ["power", "logout"] },
                { label: "Sleep", icon: "bedtime", run: ["power", "suspend"] },
                { label: "Restart", icon: "restart_alt", run: ["power", "reboot"] },
                { label: "Shut down", icon: "power_settings_new", run: ["power", "shutdown"] }
            ];
        }
        if (name.startsWith("install:"))
            return (d.catalog[name.slice(8)] ?? []).map(i => ({ label: i.label, icon: i.installed ? "check_circle" : "download", hint: i.installed ? "installed" : i.pkgs.join(" "), current: i.installed, run: i.installed ? null : ["install", ...i.pkgs], info: i.installed }));
        if (name.startsWith("remove:"))
            return (d.catalog[name.slice(7)] ?? []).filter(i => i.installed).map(i => ({ label: i.label, icon: "delete", hint: i.pkgs.join(" "), run: ["remove", ...i.pkgs] }));
        return [];
    }

    function sectionIcon(s: string): string {
        return { Browser: "language", Editor: "code", Terminal: "terminal", Development: "data_object", Gaming: "sports_esports", AI: "smart_toy", Apps: "apps", Font: "match_case" }[s] ?? "category";
    }

    // Every item one level down, for searching from the top
    function everything(): var {
        const out = [];
        for (const it of stack[0]?.items ?? []) {
            out.push(it);
            if (it.sub)
                for (const c of build(it.sub)) {
                    if (c.sub)
                        for (const g of build(c.sub))
                            out.push(Object.assign({}, g, { path: it.label + " › " + c.label }));
                    out.push(Object.assign({}, c, { path: it.label }));
                }
        }
        return out;
    }

    function push(it: var): void {
        stack = [...stack, { title: it.label, items: build(it.sub) }];
        query = "";
        sel = 0;
    }

    function back(): void {
        if (stack.length > 1) {
            stack = stack.slice(0, -1);
            query = "";
            sel = 0;
        } else
            close();
    }

    function q(s: string): string {
        return "'" + String(s).replace(/'/g, "'\\''") + "'";
    }

    function activate(it: var): void {
        if (!it || it.info && !it.run)
            return;
        if (it.sub) {
            push(it);
            return;
        }
        if (it.toggle) {
            Arch.toggles.flip(it.toggle);
            return;
        }
        if (it.term) {
            close();
            Quickshell.execDetached(["kitty", "--class", "archonate-term", "--title", it.label, "-o", "confirm_os_window_close=0", "--hold", "sh", "-c", it.term.replace(/^archonate /, root.bin + " ")]);
            return;
        }
        if (it.run) {
            if (!it.stay)
                close();
            Quickshell.execDetached(["sh", "-c", (it.delay ? "sleep " + it.delay + "; " : "") + q(root.bin) + " " + it.run.map(a => q(a)).join(" ")]);
        }
    }

    // ---- the window ---------------------------------------------------------------
    PanelWindow {
        id: win

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "archonate-menu"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Qt.alpha("black", 0.28)

        MouseArea {
            anchors.fill: parent
            onClicked: root.close()
        }

        Rectangle {
            id: card

            readonly property QtObject t: root.theme
            readonly property bool liquid: t?.glass ?? false
            readonly property int rowH: 40

            x: (parent.width - width) / 2
            y: parent.height * 0.16
            width: 600
            height: col.implicitHeight + 28
            radius: liquid ? 24 : Math.round((t?.radius ?? 12) * 1.15)
            color: liquid ? "transparent" : Qt.alpha(t?.bg ?? "#111", Math.max(0.97, t?.panelAlpha ?? 0.97))
            border.width: liquid ? 0 : Math.max(1, t?.borderWidth ?? 1)
            border.color: t?.border ?? "#40ffffff"

            // swallow clicks on the card itself
            MouseArea {
                anchors.fill: parent
            }
            LiquidGlass {
                anchors.fill: parent
                visible: card.liquid
                radius: card.radius
                tint: card.t?.bg ?? "#000"
                tintOpacity: 0.6
                rimStrength: 0.8
            }

            ColumnLayout {
                id: col

                x: 14
                y: 14
                width: parent.width - 28
                spacing: 8

                // Where we are + search
                RowLayout {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    spacing: 10

                    Icon {
                        name: root.stack.length > 1 ? "arrow_back" : "search"
                        size: 20
                        color: card.t?.accent ?? "#fff"

                        MouseArea {
                            anchors.fill: parent
                            anchors.margins: -6
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.back()
                        }
                    }
                    Text {
                        text: root.caps(root.stack.map(l => l.title).join("  ›  "))
                        color: card.t?.accent ?? "#fff"
                        font.family: card.t?.font ?? "sans-serif"
                        font.pixelSize: (card.t?.fontSize ?? 13) + 1
                        font.weight: Font.DemiBold
                    }
                    TextInput {
                        id: search

                        Layout.fillWidth: true
                        text: root.query
                        onTextChanged: {
                            root.query = text;
                            root.sel = 0;
                        }
                        color: card.t?.text ?? "#fff"
                        font.family: card.t?.font ?? "sans-serif"
                        font.pixelSize: (card.t?.fontSize ?? 13) + 2
                        selectionColor: card.t?.accent ?? "#888"
                        focus: root.open
                        clip: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: search.text === ""
                            text: root.stack.length > 1 ? "filter" : "type to search everything"
                            color: card.t?.textDim ?? "#999"
                            font: search.font
                        }

                        Keys.onPressed: e => {
                            const n = root.shown.length;
                            if (e.key === Qt.Key_Escape)
                                root.back();
                            else if (e.key === Qt.Key_Down || e.key === Qt.Key_Tab || (e.key === Qt.Key_J && e.modifiers & Qt.ControlModifier))
                                root.sel = Math.min(n - 1, root.sel + 1);
                            else if (e.key === Qt.Key_Up || e.key === Qt.Key_Backtab || (e.key === Qt.Key_K && e.modifiers & Qt.ControlModifier))
                                root.sel = Math.max(0, root.sel - 1);
                            else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                                root.activate(root.shown[root.sel]);
                            else if (e.key === Qt.Key_Right && search.cursorPosition === search.text.length && root.shown[root.sel]?.sub)
                                root.activate(root.shown[root.sel]);
                            else if ((e.key === Qt.Key_Left || e.key === Qt.Key_Backspace) && search.text === "")
                                root.back();
                            else if (e.key === Qt.Key_PageDown)
                                root.sel = Math.min(n - 1, root.sel + 8);
                            else if (e.key === Qt.Key_PageUp)
                                root.sel = Math.max(0, root.sel - 8);
                            else
                                return;
                            e.accepted = true;
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: Qt.alpha(card.t?.text ?? "#fff", 0.1)
                }

                ListView {
                    id: list

                    Layout.fillWidth: true
                    implicitHeight: Math.max(card.rowH, Math.min(10, root.shown.length) * card.rowH)
                    clip: true
                    model: root.shown
                    currentIndex: root.sel
                    highlightMoveDuration: 90
                    boundsBehavior: Flickable.StopAtBounds
                    onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)

                    delegate: Rectangle {
                        id: row

                        required property var modelData
                        required property int index
                        readonly property bool active: index === root.sel
                        readonly property bool on: modelData.toggle ? Arch.toggles.state(modelData.toggle) : false

                        width: list.width
                        height: card.rowH
                        radius: Math.round((card.t?.radius ?? 10) * 0.6)
                        color: active ? Qt.alpha(card.t?.accent ?? "#888", 0.2) : "transparent"

                        Rectangle {
                            visible: row.active
                            width: 3
                            height: parent.height - 14
                            anchors.verticalCenter: parent.verticalCenter
                            radius: 2
                            color: card.t?.accent ?? "#888"
                        }

                        RowLayout {
                            anchors.fill: parent
                            anchors.leftMargin: 14
                            anchors.rightMargin: 12
                            spacing: 12

                            Item {
                                implicitWidth: 22
                                implicitHeight: 22

                                Icon {
                                    anchors.centerIn: parent
                                    visible: !row.modelData.color
                                    name: row.modelData.icon ?? "chevron_right"
                                    size: 19
                                    fill: row.active || row.on
                                    color: row.on || row.modelData.current ? (card.t?.accent ?? "#fff") : (card.t?.textDim ?? "#aaa")
                                }
                                Rectangle {
                                    anchors.centerIn: parent
                                    visible: !!row.modelData.color
                                    width: 12
                                    height: 12
                                    radius: 6
                                    color: row.modelData.color ?? "transparent"
                                }
                            }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 0

                                Text {
                                    Layout.fillWidth: true
                                    text: root.caps(row.modelData.label)
                                    color: card.t?.text ?? "#fff"
                                    font.family: card.t?.font ?? "sans-serif"
                                    font.pixelSize: card.t?.fontSize ?? 13
                                    font.weight: row.active ? Font.DemiBold : Font.Normal
                                    elide: Text.ElideRight
                                }
                                Text {
                                    Layout.fillWidth: true
                                    visible: !!row.modelData.path && root.query !== ""
                                    text: row.modelData.path ?? ""
                                    color: card.t?.textDim ?? "#999"
                                    font.family: card.t?.font ?? "sans-serif"
                                    font.pixelSize: (card.t?.fontSize ?? 13) - 3
                                    elide: Text.ElideRight
                                }
                            }
                            Text {
                                visible: !!row.modelData.hint
                                Layout.maximumWidth: 240
                                text: row.modelData.hint ?? ""
                                color: card.t?.textDim ?? "#999"
                                font.family: card.t?.font ?? "sans-serif"
                                font.pixelSize: (card.t?.fontSize ?? 13) - 2
                                elide: Text.ElideRight
                            }
                            Text {
                                visible: !!row.modelData.current
                                text: "●"
                                color: card.t?.accent ?? "#fff"
                                font.pixelSize: 10
                            }
                            // Switch rows show their state
                            Rectangle {
                                visible: !!row.modelData.toggle
                                implicitWidth: 34
                                implicitHeight: 20
                                radius: (card.t?.radius ?? 8) > 0 ? 10 : 0
                                color: row.on ? (card.t?.accent ?? "#888") : Qt.alpha(card.t?.text ?? "#fff", 0.15)

                                Rectangle {
                                    x: row.on ? parent.width - width - 3 : 3
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 14
                                    height: 14
                                    radius: (card.t?.radius ?? 8) > 0 ? 7 : 0
                                    color: row.on ? (card.t?.bg ?? "#000") : (card.t?.text ?? "#fff")
                                    Behavior on x {
                                        NumberAnimation {
                                            duration: 140
                                        }
                                    }
                                }
                            }
                            Icon {
                                visible: !!row.modelData.sub
                                name: "chevron_right"
                                size: 18
                                color: card.t?.textDim ?? "#999"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: row.modelData.info && !row.modelData.run ? Qt.ArrowCursor : Qt.PointingHandCursor
                            onEntered: root.sel = row.index
                            onClicked: root.activate(row.modelData)
                        }
                    }
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    visible: root.shown.length === 0
                    text: root.query ? "nothing matches \"" + root.query + "\"" : "loading…"
                    color: card.t?.textDim ?? "#999"
                    font.family: card.t?.font ?? "sans-serif"
                    font.pixelSize: card.t?.fontSize ?? 13
                    bottomPadding: 6
                }

                Text {
                    Layout.fillWidth: true
                    Layout.leftMargin: 6
                    horizontalAlignment: Text.AlignRight
                    text: "↑↓ move   enter open   ← back   esc close"
                    color: Qt.alpha(card.t?.textDim ?? "#999", 0.8)
                    font.family: card.t?.font ?? "sans-serif"
                    font.pixelSize: 11
                }
            }
        }
    }
}
