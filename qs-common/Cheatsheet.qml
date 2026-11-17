// The keyboard cheat sheet (SUPER + /, `archonate keys`): every shortcut,
// grouped, dressed in the rice. Type to filter, Esc or SUPER + / again closes.
// The list comes from desktop.py keybinds, the same one Settings shows, so a
// bind added to the config shows up here by itself.
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
    property var binds: []
    property string query: ""
    // the first login ever: the sheet opens by itself with a welcome on top
    property bool welcome: false

    readonly property var groups: {
        const q = query.trim().toLowerCase();
        const order = [];
        const by = {};
        for (const b of binds) {
            const keys = b.keys.map(k => pretty(k));
            if (q && !(b.label + " " + b.group + " " + keys.join(" ") + " " + b.keys.join(" ")).toLowerCase().includes(q))
                continue;
            if (!by[b.group]) {
                by[b.group] = [];
                order.push(b.group);
            }
            by[b.group].push({ label: b.label, keys: keys });
        }
        return order.map(g => ({ name: g, rows: by[g] }));
    }

    // Groups into n columns, masonry style: each group goes to the shortest
    // column so far (in reading order), so no column is mostly empty
    function pack(n: int): var {
        const cols = [];
        const h = [];
        for (let i = 0; i < n; i++) {
            cols.push([]);
            h.push(0);
        }
        for (const g of groups) {
            // a row with many key caps wraps onto a second line
            const w = 2 + g.rows.reduce((s, r) => s + (r.keys.reduce((c, k) => c + k.length, 0) > 6 ? 2 : 1), 0);
            const i = h.indexOf(Math.min(...h));
            cols[i].push(g);
            h[i] += w;
        }
        return cols.filter(c => c.length);
    }

    function toggle(): void {
        if (open) {
            open = false;
            return;
        }
        welcome = false;
        query = "";
        open = true;
        loader.running = true;
    }

    function greet(): void {
        welcome = true;
        query = "";
        open = true;
        loader.running = true;
    }

    // First login: desktop.py welcome answers "first" once, then never again
    Process {
        id: firstRun

        running: true
        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/lib/desktop.py", "welcome"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (text.trim() === "first")
                    greetLater.start();
            }
        }
    }
    Timer {
        id: greetLater

        interval: 2500 // let the bar and wallpaper land first
        onTriggered: root.greet()
    }

    function caps(s: string): string {
        return theme?.caps ? theme.caps(s) : s;
    }

    // "SUPER + SHIFT + Return" -> ["Super", "Shift", "Enter"]
    function pretty(k: string): var {
        const names = {
            super: "Super", shift: "Shift", ctrl: "Ctrl", control: "Ctrl", alt: "Alt", return: "Enter", escape: "Esc",
            slash: "/", comma: ",", period: ".", minus: "-", equal: "=", grave: "`", backslash: "\\", semicolon: ";",
            apostrophe: "'", bracketleft: "[", bracketright: "]", space: "Space", tab: "Tab", print: "PrtSc",
            left: "←", right: "→", up: "↑", down: "↓", page_down: "PgDn", page_up: "PgUp", next: "PgDn", prior: "PgUp",
            backspace: "Bksp", delete: "Del", insert: "Ins", home: "Home", end: "End", pause: "Pause", menu: "Menu",
            "mouse:272": "Left drag", "mouse:273": "Right drag", mouse_down: "Scroll ↓", mouse_up: "Scroll ↑",
            xf86audioraisevolume: "Vol +", xf86audiolowervolume: "Vol −", xf86audiomute: "Mute", xf86audiomicmute: "Mic mute",
            xf86audioplay: "Play", xf86audiopause: "Pause", xf86audionext: "Next", xf86audioprev: "Prev",
            xf86monbrightnessup: "Bright +", xf86monbrightnessdown: "Bright −"
        };
        return String(k).split("+").map(s => s.trim()).filter(s => s).map(s => names[s.toLowerCase()] ?? (s.length === 1 ? s.toUpperCase() : s.charAt(0).toUpperCase() + s.slice(1)));
    }

    Process {
        id: loader

        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/lib/desktop.py", "keybinds"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.binds = JSON.parse(text);
                } catch (e) {}
            }
        }
    }

    PanelWindow {
        id: win

        readonly property QtObject t: root.theme
        readonly property int fs: t?.fontSize ?? 13
        readonly property int r: t?.radius ?? 12

        screen: Quickshell.screens.find(s => s.name === Hyprland.focusedMonitor?.name) ?? Quickshell.screens[0]
        visible: root.open
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "archonate-keys"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
        exclusionMode: ExclusionMode.Ignore
        anchors {
            top: true
            bottom: true
            left: true
            right: true
        }
        color: Qt.alpha("black", 0.5)

        MouseArea {
            anchors.fill: parent
            onClicked: root.open = false
        }

        Rectangle {
            id: card

            readonly property bool liquid: win.t?.glass ?? false

            width: Math.min(parent.width - 80, 1400)
            height: Math.min(parent.height - 80, head.implicitHeight + board.implicitHeight + 76 + (hello.visible ? hello.implicitHeight + 20 : 0))
            anchors.centerIn: parent
            radius: liquid ? 24 : Math.round(win.r * 1.15)
            // opaque: this is for reading (glass rices keep their glass, tinted heavier)
            color: liquid ? "transparent" : (win.t?.bg ?? "#111")
            border.width: liquid ? 0 : Math.max(1, win.t?.borderWidth ?? 1)
            border.color: win.t?.border ?? "#40ffffff"

            MouseArea {
                anchors.fill: parent
            }
            LiquidGlass {
                anchors.fill: parent
                visible: card.liquid
                radius: card.radius
                tint: win.t?.bg ?? "#000"
                tintOpacity: 0.85
                rimStrength: 0.8
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 28
                spacing: 20

                // first login only
                Rectangle {
                    id: hello

                    visible: root.welcome
                    Layout.fillWidth: true
                    implicitHeight: helloCol.implicitHeight + 28
                    radius: Math.round(win.r * 0.8)
                    color: Qt.alpha(win.t?.accent ?? "#888", 0.12)
                    border.width: Math.max(1, win.t?.borderWidth ?? 1)
                    border.color: Qt.alpha(win.t?.accent ?? "#888", 0.5)

                    ColumnLayout {
                        id: helloCol

                        x: 18
                        y: 14
                        width: parent.width - 36
                        spacing: 5

                        Text {
                            text: root.caps("Welcome to Archonate")
                            color: win.t?.accent ?? "#fff"
                            font.family: win.t?.displayFont ?? win.t?.font ?? "sans-serif"
                            font.pixelSize: win.fs + 5
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            wrapMode: Text.WordWrap
                            text: "Everything here is driven from the keyboard, and this sheet lists all of it. Two keys are worth remembering: Super + / brings this sheet back, and Super + Escape opens the menu with rices, wallpapers, settings and the rest. Press Esc to start."
                            color: win.t?.text ?? "#fff"
                            font.family: win.t?.font ?? "sans-serif"
                            font.pixelSize: win.fs + 1
                            lineHeight: 1.25
                        }
                    }
                }

                RowLayout {
                    id: head

                    Layout.fillWidth: true
                    spacing: 16

                    Text {
                        text: root.caps("Keyboard shortcuts")
                        color: win.t?.text ?? "#fff"
                        font.family: win.t?.displayFont ?? win.t?.font ?? "sans-serif"
                        font.pixelSize: win.fs + 9
                        font.weight: Font.DemiBold
                        font.letterSpacing: win.t?.tracking ?? 0
                    }
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.maximumWidth: 360
                        implicitHeight: win.fs + 18
                        radius: Math.round(win.r * 0.6)
                        color: Qt.alpha(win.t?.text ?? "#fff", 0.06)
                        border.width: search.activeFocus ? Math.max(1, win.t?.borderWidth ?? 1) : 0
                        border.color: win.t?.accent ?? "#888"

                        TextInput {
                            id: search

                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            verticalAlignment: TextInput.AlignVCenter
                            text: root.query
                            onTextChanged: root.query = text
                            color: win.t?.text ?? "#fff"
                            font.family: win.t?.font ?? "sans-serif"
                            font.pixelSize: win.fs + 1
                            selectionColor: win.t?.accent ?? "#888"
                            focus: root.open
                            clip: true
                            Keys.onEscapePressed: {
                                if (search.text !== "")
                                    search.text = "";
                                else
                                    root.open = false;
                            }
                            Keys.onPressed: e => {
                                if (e.key === Qt.Key_Down || e.key === Qt.Key_PageDown) {
                                    scroller.contentY = Math.min(Math.max(0, scroller.contentHeight - scroller.height), scroller.contentY + (e.key === Qt.Key_Down ? 60 : scroller.height * 0.9));
                                    e.accepted = true;
                                } else if (e.key === Qt.Key_Up || e.key === Qt.Key_PageUp) {
                                    scroller.contentY = Math.max(0, scroller.contentY - (e.key === Qt.Key_Up ? 60 : scroller.height * 0.9));
                                    e.accepted = true;
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: search.text === ""
                                text: "type to filter"
                                color: win.t?.textDim ?? "#999"
                                font: search.font
                            }
                        }
                    }
                    Item {
                        Layout.fillWidth: true
                    }
                    Text {
                        text: "Esc to close"
                        color: win.t?.textDim ?? "#999"
                        font.family: win.t?.font ?? "sans-serif"
                        font.pixelSize: win.fs
                    }
                }

                Flickable {
                    id: scroller

                    // as many ~400px columns as fit
                    readonly property int gap: 30
                    readonly property int cols: Math.max(1, Math.floor((width + gap) / (400 + gap)))
                    readonly property real colW: (width - (cols - 1) * gap) / cols

                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentHeight: board.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    RowLayout {
                        id: board

                        width: scroller.width
                        spacing: scroller.gap

                        Repeater {
                            model: root.pack(scroller.cols)

                            ColumnLayout {
                                id: column

                                required property var modelData

                                Layout.preferredWidth: scroller.colW
                                Layout.maximumWidth: scroller.colW
                                Layout.alignment: Qt.AlignTop
                                spacing: 26

                                Repeater {
                                    model: column.modelData

                                    ColumnLayout {
                                        id: group

                                        required property var modelData

                                        Layout.fillWidth: true
                                        Layout.maximumWidth: scroller.colW
                                        spacing: 7

                                        Text {
                                            Layout.bottomMargin: 2
                                            text: root.caps(group.modelData.name)
                                            color: win.t?.accent ?? "#fff"
                                            font.family: win.t?.font ?? "sans-serif"
                                            font.pixelSize: win.fs
                                            font.weight: Font.DemiBold
                                            font.letterSpacing: Math.max(0.5, win.t?.tracking ?? 0)
                                        }

                                        Repeater {
                                            model: group.modelData.rows

                                            GridLayout {
                                                id: line

                                                required property var modelData
                                                // keys under the label when they'd crowd it
                                                readonly property bool stacked: keysRow.natural > scroller.colW * 0.58

                                                Layout.fillWidth: true
                                                Layout.maximumWidth: scroller.colW
                                                Layout.bottomMargin: stacked ? 4 : 0
                                                columns: stacked ? 1 : 2
                                                columnSpacing: 12
                                                rowSpacing: 4

                                                Text {
                                                    Layout.fillWidth: true
                                                    text: line.modelData.label
                                                    color: win.t?.text ?? "#fff"
                                                    font.family: win.t?.font ?? "sans-serif"
                                                    font.pixelSize: win.fs
                                                    elide: Text.ElideRight
                                                }

                                                // each way to press it: key caps, joined by "or"; wraps
                                                // inside the column when there are many
                                                Flow {
                                                    id: keysRow

                                                    // its width on one line
                                                    readonly property real natural: {
                                                        let w = 0, n = 0;
                                                        for (let i = 0; i < children.length; i++)
                                                            if (children[i].implicitWidth > 0) {
                                                                w += children[i].implicitWidth;
                                                                n++;
                                                            }
                                                        return w + Math.max(0, n - 1) * spacing;
                                                    }

                                                    Layout.alignment: line.stacked ? Qt.AlignLeft : Qt.AlignRight
                                                    Layout.preferredWidth: Math.min(natural, scroller.colW)
                                                    Layout.maximumWidth: scroller.colW
                                                    spacing: 6

                                                    Repeater {
                                                        model: line.modelData.keys

                                                        Row {
                                                            id: combo

                                                            required property var modelData
                                                            required property int index

                                                            spacing: 3

                                                            Text {
                                                                visible: combo.index > 0
                                                                anchors.verticalCenter: parent.verticalCenter
                                                                rightPadding: 3
                                                                text: "or"
                                                                color: win.t?.textDim ?? "#999"
                                                                font.family: win.t?.font ?? "sans-serif"
                                                                font.pixelSize: win.fs - 2
                                                            }
                                                            Repeater {
                                                                model: combo.modelData

                                                                Rectangle {
                                                                    id: cap

                                                                    required property string modelData

                                                                    width: Math.max(implicitHeight, label.implicitWidth + 12)
                                                                    implicitHeight: win.fs + 10
                                                                    radius: Math.round(win.r * 0.4)
                                                                    color: Qt.alpha(win.t?.text ?? "#fff", 0.07)
                                                                    border.width: Math.max(1, Math.round((win.t?.borderWidth ?? 1) / 2))
                                                                    border.color: Qt.alpha(win.t?.text ?? "#fff", 0.16)

                                                                    Text {
                                                                        id: label

                                                                        anchors.centerIn: parent
                                                                        text: cap.modelData
                                                                        color: win.t?.text ?? "#fff"
                                                                        font.family: win.t?.font ?? "sans-serif"
                                                                        font.pixelSize: win.fs - 1
                                                                        font.weight: Font.Medium
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: root.groups.length === 0
                    text: root.binds.length ? "Nothing matches “" + root.query + "”" : "Loading…"
                    color: win.t?.textDim ?? "#999"
                    font.family: win.t?.font ?? "sans-serif"
                    font.pixelSize: win.fs + 1
                }
            }
        }
    }
}
