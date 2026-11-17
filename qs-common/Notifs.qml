// Notification daemon: popups in the top-right corner, plus a sidebar
// ("center") with the date, media controls and notification history.
//
// Like omarchy's: notifications from one app stack into a deck (hover to fan
// it out; nothing expires under your pointer). Click runs the notification's
// own action, right-click or ✕ dismisses. Verification codes get "Copy code"
// (kept out of clipboard history, cleared after a minute). Keyboard control
// (SUPER+CTRL+comma, IPC notifKeys): the newest is selected and its buttons
// numbered; 1-9 press one, Enter clicks, ↑/↓ move, Delete dismisses, C copies
// the code, Esc lets go. With nothing on screen it brings back the last five.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications

Scope {
    id: root

    required property QtObject theme
    required property Services services
    property bool centerOpen: false
    property string sound: "" // played on each new notification
    property bool dnd: false  // do not disturb: no popups, no sound

    // On screen now: [{ n, t }] newest first (t = when it was shown)
    property var popups: []
    // Arrival times by notification id, for "2m" labels
    property var arrived: ({})

    readonly property int count: server.trackedNotifications.values.length

    // ---- decks: group by app, newest app first, newest card first --------
    function decksOf(list: var): var {
        const order = [], by = {};
        for (const n of list) {
            const k = n.appName || n.desktopEntry || "notification";
            if (!by[k]) {
                by[k] = [];
                order.push(k);
            }
            by[k].push(n);
        }
        return order.map(k => ({ app: k, items: by[k] }));
    }
    readonly property var popupDecks: decksOf(popups.map(p => p.n)).slice(0, 4)
    readonly property var centerDecks: decksOf(server.trackedNotifications.values.slice().reverse())

    function clearAll(): void {
        for (const n of server.trackedNotifications.values.slice())
            n.dismiss();
        popups = [];
    }

    function dropPopup(n: var): void {
        popups = popups.filter(p => p.n !== n);
    }

    function dismiss(n: var): void {
        if (root.theme.notifDismissSound)
            Quickshell.execDetached(["pw-play", root.theme.notifDismissSound]);
        dropPopup(n);
        n.dismiss();
    }

    // The notification's own "default" action (open the chat, the page...)
    function defaultAction(n: var): var {
        return n.actions.find(a => a.identifier === "default") ?? null;
    }
    function buttons(n: var): var {
        return n.actions.filter(a => a.identifier !== "default");
    }
    function click(n: var): void {
        const a = defaultAction(n);
        if (a)
            a.invoke();
        dismiss(n);
    }

    // A verification code in the text, digits only ("" if none)
    function codeOf(n: var): string {
        const t = (n.summary + " " + n.body).replace(/<[^>]+>/g, " ");
        if (!/(code|verif|otp|passcode|\bpin\b|2fa|one[- ]?time|log ?in|sign ?in|security|κωδικ)/i.test(t))
            return "";
        const m = t.match(/(?:^|[^\d])((?:[A-Z]-)?\d{3}[- ]\d{3}|(?:[A-Z]-)?\d{4,8})(?!\d)/);
        if (!m)
            return "";
        const d = m[1].replace(/\D/g, "");
        return d.length >= 4 && d.length <= 8 ? d : "";
    }
    function copyCode(code: string): void {
        // --sensitive keeps it out of clipboard history; gone after a minute
        Quickshell.execDetached(["sh", "-c", "printf %s \"$1\" | wl-copy --sensitive 2>/dev/null || printf %s \"$1\" | wl-copy; sleep 60; [ \"$(wl-paste -n 2>/dev/null)\" = \"$1\" ] && wl-copy --clear", "sh", code]);
    }

    function ago(n: var): string {
        const t = arrived[n.id];
        if (!t)
            return "";
        const m = Math.floor((clock.date.getTime() - t) / 60000);
        return m < 1 ? "now" : m < 60 ? m + "m" : Math.floor(m / 60) + "h";
    }

    NotificationServer {
        id: server

        keepOnReload: false
        actionsSupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true

        onNotification: n => {
            n.tracked = true;
            const a = root.arrived;
            a[n.id] = Date.now();
            root.arrived = a;
            if (root.sound && !n.transient && !root.dnd)
                Quickshell.execDetached(["pw-play", root.sound]);
            n.closed.connect(() => root.dropPopup(n));
            if (!root.centerOpen && !root.dnd)
                root.popups = [{ n: n, t: Date.now() }, ...root.popups.filter(p => p.n !== n)].slice(0, 12);
        }
    }

    // Expire popups, but never while you're reading (hovering) or steering
    Timer {
        running: root.popups.length > 0
        repeat: true
        interval: 400
        onTriggered: {
            if (popupHover.hovered || root.kbd)
                return;
            const now = Date.now();
            const keep = root.popups.filter(p => p.n.urgency === NotificationUrgency.Critical || now - p.t < (p.n.expireTimeout > 0 ? p.n.expireTimeout : 6000));
            if (keep.length !== root.popups.length)
                root.popups = keep;
        }
    }

    // ---- keyboard control ------------------------------------------------
    property bool kbd: false
    property int kbdIndex: 0
    readonly property var kbdList: popupDecks.reduce((a, d) => a.concat(d.items), [])
    readonly property var kbdSel: kbd ? (kbdList[Math.min(kbdIndex, kbdList.length - 1)] ?? null) : null

    function keys(): void {
        if (kbd) {
            kbd = false;
            return;
        }
        if (popups.length === 0) {
            // Nothing on screen: bring back the last few, held back or not
            const recent = server.trackedNotifications.values.slice(-5).reverse();
            popups = recent.map(n => ({ n: n, t: Date.now() }));
        }
        if (popups.length === 0)
            return;
        kbdIndex = 0;
        kbd = true;
        kbdIdle.restart();
    }

    Timer {
        id: kbdIdle

        interval: 8000
        onTriggered: root.kbd = false
    }
    onKbdListChanged: if (kbd && kbdList.length === 0)
        kbd = false

    // ---- popups -----------------------------------------------------------
    PanelWindow {
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-notifs"
        WlrLayershell.keyboardFocus: root.kbd ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        anchors {
            top: true
            right: true
        }
        margins {
            top: root.theme.gap
            right: root.theme.gap
        }
        visible: root.popups.length > 0 && !root.centerOpen
        implicitWidth: root.theme.notifWidth + 8
        implicitHeight: Math.max(1, popupCol.implicitHeight + 8)
        color: "transparent"

        Item {
            anchors.fill: parent
            focus: root.kbd
            Keys.onPressed: e => {
                kbdIdle.restart();
                const n = root.kbdSel;
                const list = root.kbdList;
                if (e.key === Qt.Key_Escape)
                    root.kbd = false;
                else if (e.key === Qt.Key_Down || e.key === Qt.Key_J || e.key === Qt.Key_Tab)
                    root.kbdIndex = Math.min(list.length - 1, root.kbdIndex + 1);
                else if (e.key === Qt.Key_Up || e.key === Qt.Key_K || e.key === Qt.Key_Backtab)
                    root.kbdIndex = Math.max(0, root.kbdIndex - 1);
                else if (!n)
                    return;
                else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter)
                    root.click(n);
                else if (e.key === Qt.Key_Delete || e.key === Qt.Key_Backspace || e.key === Qt.Key_D)
                    root.dismiss(n);
                else if (e.key === Qt.Key_C && root.codeOf(n) !== "")
                    root.copyCode(root.codeOf(n));
                else if (e.key >= Qt.Key_1 && e.key <= Qt.Key_9) {
                    const b = root.buttons(n)[e.key - Qt.Key_1];
                    if (b) {
                        b.invoke();
                        if (!n.resident)
                            root.dismiss(n);
                    }
                }
                e.accepted = true;
            }
        }

        Column {
            id: popupCol

            spacing: root.theme.gap / 2

            HoverHandler {
                id: popupHover
            }

            Repeater {
                model: root.popupDecks

                NotifDeck {
                    required property var modelData

                    host: root

                    items: modelData.items
                }
            }

            // Keyboard mode hint
            Rectangle {
                visible: root.kbd
                width: root.theme.notifWidth
                height: hint.implicitHeight + 12
                radius: root.theme.radius / 2
                color: Qt.alpha(root.theme.bg, 0.85)

                Text {
                    id: hint

                    anchors.centerIn: parent
                    text: "↑↓ move   enter open   1-9 buttons   c code   del dismiss   esc"
                    color: root.theme.textDim
                    font.family: root.theme.font
                    font.pixelSize: 11
                }
            }
        }
    }

    // ---- center / sidebar ---------------------------------------------------
    PanelWindow {
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "rice-center"
        WlrLayershell.keyboardFocus: root.centerOpen ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Normal
        anchors {
            top: true
            right: true
            bottom: true
        }
        margins {
            top: root.theme.gap
            right: root.theme.gap
            bottom: root.theme.gap
        }
        visible: root.centerOpen
        implicitWidth: root.theme.notifWidth + 2 * root.theme.pad
        color: "transparent"

        Rectangle {
            anchors.fill: parent
            readonly property bool liquid: root.theme.glass ?? false
            radius: liquid ? 26 : root.theme.radius
            color: liquid ? "transparent" : Qt.alpha(root.theme.bg, root.theme.panelAlpha)
            border.width: liquid ? 0 : root.theme.borderWidth
            border.color: root.theme.border
            focus: true

            // Big surface over windows: heaviest tint of the three for legibility
            LiquidGlass {
                anchors.fill: parent
                visible: parent.liquid
                radius: parent.radius
                tint: root.theme.bg
                tintOpacity: 0.55
                rimStrength: 0.7
            }
            Keys.onEscapePressed: root.centerOpen = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: root.theme.pad
                spacing: root.theme.pad

                Text {
                    text: root.theme.caps(Qt.formatDateTime(clock.date, "dddd"))
                    color: root.theme.accent
                    font.family: root.theme.font
                    font.pixelSize: root.theme.fontSize
                    font.letterSpacing: root.theme.tracking
                }
                Text {
                    text: Qt.formatDateTime(clock.date, root.theme.longDate)
                    color: root.theme.text
                    font.family: root.theme.displayFont
                    font.pixelSize: root.theme.fontSize * 2
                }

                // Media card
                Rectangle {
                    Layout.fillWidth: true
                    visible: root.services.player !== null
                    implicitHeight: media.implicitHeight + 2 * root.theme.pad
                    radius: root.theme.radius
                    color: root.theme.surface
                    border.width: root.theme.borderWidth
                    border.color: root.theme.border

                    ColumnLayout {
                        id: media

                        anchors.fill: parent
                        anchors.margins: root.theme.pad
                        spacing: 6

                        Text {
                            Layout.fillWidth: true
                            text: root.services.player?.trackTitle || root.services.player?.identity || ""
                            color: root.theme.text
                            font.family: root.theme.font
                            font.pixelSize: root.theme.fontSize + 1
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: root.services.player?.trackArtist ?? ""
                            color: root.theme.textDim
                            font.family: root.theme.font
                            font.pixelSize: root.theme.fontSize - 1
                            elide: Text.ElideRight
                        }
                        Row {
                            spacing: 14

                            Repeater {
                                model: [["skip_previous", "prev"], [root.services.player?.isPlaying ? "pause" : "play_arrow", "toggle"], ["skip_next", "next"]]

                                Icon {
                                    required property var modelData

                                    name: modelData[0]
                                    size: 22
                                    color: root.theme.accent

                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.services.media(parent.modelData[1])
                                    }
                                }
                            }
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    Text {
                        Layout.fillWidth: true
                        text: root.theme.caps(root.count + " notifications")
                        color: root.theme.textDim
                        font.family: root.theme.font
                        font.pixelSize: root.theme.fontSize - 1
                        font.letterSpacing: root.theme.tracking
                    }
                    Text {
                        visible: root.count > 0
                        text: root.theme.caps("clear")
                        color: root.theme.accent
                        font.family: root.theme.font
                        font.pixelSize: root.theme.fontSize - 1
                        font.letterSpacing: root.theme.tracking

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.clearAll()
                        }
                    }
                }

                // History, one deck per app (click a deck's header to open it)
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    contentHeight: centerCol.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds

                    Column {
                        id: centerCol

                        width: parent.width
                        spacing: root.theme.gap

                        Repeater {
                            model: root.centerDecks

                            Column {
                                id: group

                                required property var modelData

                                spacing: 6

                                // Header: app · count · open/close · clear this app
                                RowLayout {
                                    width: root.theme.notifWidth
                                    visible: group.modelData.items.length > 1

                                    Text {
                                        Layout.fillWidth: true
                                        text: root.theme.caps(group.modelData.app) + "  ·  " + group.modelData.items.length
                                        color: root.theme.textDim
                                        font.family: root.theme.font
                                        font.pixelSize: root.theme.fontSize - 2
                                        font.letterSpacing: root.theme.tracking
                                        elide: Text.ElideRight

                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: deckC.expanded = !deckC.expanded
                                        }
                                    }
                                    Icon {
                                        name: deckC.expanded ? "unfold_less" : "unfold_more"
                                        size: 16
                                        color: root.theme.textDim

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: deckC.expanded = !deckC.expanded
                                        }
                                    }
                                    Icon {
                                        name: "clear_all"
                                        size: 16
                                        color: root.theme.textDim

                                        MouseArea {
                                            anchors.fill: parent
                                            anchors.margins: -5
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                for (const n of group.modelData.items.slice())
                                                    root.dismiss(n);
                                            }
                                        }
                                    }
                                }
                                NotifDeck {
                                    id: deckC

                                    host: root

                                    items: group.modelData.items
                                    inCenter: true
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }
}
