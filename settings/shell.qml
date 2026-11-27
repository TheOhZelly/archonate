// Settings (SUPER+I or the launcher): Wi-Fi, Bluetooth, sound, display,
// keyboard & mouse, the rice system, notifications, lock & power, default
// apps and about. Each page is Page<Name>.qml; shared state lives in App.qml.
//
// Keyboard first: it opens in the search box. Type to find a page (it opens as
// you type), Up/Down walk the pages, Enter or Tab go into the page, Tab and
// Shift+Tab move between controls, Space/Enter press them, arrows move sliders.
// Esc steps back to the search box, then closes. Ctrl+Tab / Alt+Up/Down switch
// page from anywhere, Ctrl+F or / search, PageUp/PageDown scroll.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

ShellRoot {
    id: root

    property string page: Quickshell.env("RICE_SETTINGS_PAGE") || "Wifi"

    // [page, icon, label, search keywords]
    readonly property var groups: [
        ["Connections", [["Wifi", "wifi", "Wi-Fi", "network internet wireless password router ip"], ["Bluetooth", "bluetooth", "Bluetooth", "headphones pair devices"]]],
        ["Device", [["Sound", "volume_up", "Sound", "audio volume speakers microphone mic output input mixer"], ["Display", "desktop_windows", "Display", "monitor screen resolution refresh hz 165 scale brightness"], ["Input", "keyboard", "Keyboard & mouse", "layout greek typing repeat mouse pointer speed scroll acceleration"], ["Shortcuts", "keyboard_command_key", "Keyboard shortcuts", "keybinds hotkeys keys bindings super"], ["Nightlight", "nightlight", "Night light", "blue light warm evening eyes hyprsunset"]]],
        ["Personalise", [["Rices", "palette", "Rices & modes", "theme rice mode gaming minimal"], ["Wallpaper", "wallpaper", "Wallpaper", "background image rotate"], ["Schedule", "routine", "Day & night", "schedule time of day night day evening morning automatic switch rice"], ["Bar", "toolbar", "Bar", "panel top clock 24 hour 12 seconds date tray workspaces numbers volume music archonate stats"], ["Notifications", "notifications", "Notifications", "do not disturb dnd sound"]]],
        ["System", [["Updates", "system_update", "Updates", "upgrade packages pacman paru aur kernel"], ["Startup", "rocket_launch", "Startup apps", "autostart login boot launch"], ["Storage", "hard_drive", "Storage", "disk space clean cache folders"], ["Time", "schedule", "Date & time", "clock timezone ntp sync"], ["Power", "power_settings_new", "Lock & power", "lock idle screen off suspend restart shut down"], ["Apps", "apps", "Default apps", "browser files open with"], ["About", "info", "About", "system cpu gpu memory computer info"]]]
    ]
    property string search: ""
    // The pages in sidebar order (or the search results), for Up/Down
    readonly property var visiblePages: search === "" ? groups.reduce((a, g) => a.concat(g[1]), []) : matches
    // Flat list of pages matching the search box
    readonly property var matches: {
        const q = search.toLowerCase();
        const out = [];
        for (let g = 0; g < groups.length; g++)
            for (let i = 0; i < groups[g][1].length; i++) {
                const p = groups[g][1][i];
                if ((p[2] + " " + p[3]).toLowerCase().includes(q))
                    out.push(p);
            }
        return out;
    }

    function step(d: int): void {
        const list = root.visiblePages;
        if (list.length === 0)
            return;
        const i = list.findIndex(p => p[0] === root.page);
        root.page = list[((i < 0 ? (d > 0 ? -1 : 0) : i) + d + list.length) % list.length][0];
    }
    // Page switches from inside a page land you on the new page's first control
    property bool focusAfterLoad: false
    function inSearch(): bool {
        return searchBox.input.activeFocus;
    }
    function focusSearch(): void {
        searchBox.input.forceActiveFocus();
        searchBox.input.selectAll();
    }
    function focusPage(): void {
        const n = searchBox.input.nextItemInFocusChain(true);
        if (n && n !== searchBox.input)
            n.forceActiveFocus(Qt.TabFocusReason);
    }
    function switchPage(d: int): void {
        focusAfterLoad = !inSearch();
        step(d);
    }

    FloatingWindow {
        id: win

        title: "Archonate Settings"
        implicitWidth: 1100
        implicitHeight: 760
        color: App.bg
        onVisibleChanged: {
            if (!visible)
                Qt.quit();
        }

        // Esc: out of a page to the search box; clear the search; then close
        Shortcut {
            sequence: "Escape"
            onActivated: {
                if (!root.inSearch())
                    root.focusSearch();
                else if (searchBox.text !== "")
                    searchBox.text = "";
                else
                    Qt.quit();
            }
        }
        Shortcut {
            sequences: ["Ctrl+F", "/"]
            onActivated: root.focusSearch()
        }
        Shortcut {
            sequences: ["Ctrl+Tab", "Ctrl+PgDown", "Alt+Down"]
            onActivated: root.switchPage(1)
        }
        Shortcut {
            sequences: ["Ctrl+Shift+Tab", "Ctrl+Backtab", "Ctrl+PgUp", "Alt+Up"]
            onActivated: root.switchPage(-1)
        }
        Shortcut {
            sequence: "PgDown"
            onActivated: pane.scrollBy(pane.height * 0.8)
        }
        Shortcut {
            sequence: "PgUp"
            onActivated: pane.scrollBy(-pane.height * 0.8)
        }

        RowLayout {
            anchors.fill: parent
            spacing: 0

            // ---- sidebar ----
            Rectangle {
                Layout.fillHeight: true
                Layout.preferredWidth: 250
                color: App.panel

                Flickable {
                    anchors.fill: parent
                    anchors.margins: 16
                    contentHeight: side.implicitHeight
                    clip: true

                    ColumnLayout {
                        id: side

                        width: parent.width
                        spacing: 2

                        SLabel {
                            text: "Settings"
                            font.pixelSize: 21
                            font.weight: Font.Bold
                            bottomPadding: 10
                        }

                        SField {
                            id: searchBox

                            Layout.fillWidth: true
                            placeholder: "Search  ( / )"
                            // the best match opens as you type
                            onTextChanged: {
                                root.search = text;
                                if (text !== "" && root.matches.length > 0)
                                    root.page = root.matches[0][0];
                            }
                            onNavUp: root.step(-1)
                            onNavDown: root.step(1)
                            onAccepted: root.focusPage()
                            Component.onCompleted: input.forceActiveFocus()
                        }

                        Repeater {
                            model: root.search === "" ? root.groups : [["Results", root.matches]]

                            ColumnLayout {
                                id: group

                                required property var modelData

                                Layout.fillWidth: true
                                spacing: 2

                                SLabel {
                                    text: App.lowerRice ? group.modelData[0].toLowerCase() : group.modelData[0].toUpperCase()
                                    color: App.dim
                                    font.pixelSize: 11
                                    font.weight: Font.DemiBold
                                    font.letterSpacing: 1.2
                                    topPadding: 14
                                    bottomPadding: 4
                                    leftPadding: 10
                                }

                                Repeater {
                                    model: group.modelData[1]

                                    Rectangle {
                                        id: nav

                                        required property var modelData
                                        readonly property bool active: root.page === modelData[0]

                                        Layout.fillWidth: true
                                        implicitHeight: 38
                                        radius: App.r(10)
                                        color: active ? Qt.alpha(App.accent, 0.22) : navHover.containsMouse ? Qt.alpha(App.fg, 0.06) : "transparent"
                                        scale: navHover.pressed ? 0.98 : 1

                                        Row {
                                            anchors.verticalCenter: parent.verticalCenter
                                            x: 12
                                            spacing: 12

                                            Text {
                                                text: nav.modelData[1]
                                                font.family: "Material Symbols Rounded"
                                                font.pixelSize: 20
                                                color: nav.active ? App.accent : App.dim
                                            }
                                            SLabel {
                                                anchors.verticalCenter: parent.verticalCenter
                                                text: nav.modelData[2]
                                                font.weight: nav.active ? Font.DemiBold : Font.Normal
                                                font.capitalization: App.capitalization
                                            }
                                        }
                                        MouseArea {
                                            id: navHover

                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: root.page = nav.modelData[0]
                                        }
                                    }
                                }
                            }
                        }

                        SNote {
                            topPadding: 18
                            leftPadding: 10
                            text: "Rice: " + App.info.rice + " · " + App.info.mode
                        }
                        SNote {
                            topPadding: 6
                            leftPadding: 10
                            font.pixelSize: 11
                            lineHeight: 1.25
                            text: "↑↓ pages · ⏎ / tab go in · esc back\nctrl+tab next page · / search"
                        }
                    }
                }
            }

            // ---- page ----
            Flickable {
                id: pane

                Layout.fillWidth: true
                Layout.fillHeight: true
                contentHeight: pageLoader.implicitHeight + 72
                clip: true
                boundsBehavior: Flickable.StopAtBounds

                function scrollBy(dy: real): void {
                    contentY = Math.max(0, Math.min(Math.max(0, contentHeight - height), contentY + dy));
                }
                // Keep the focused control in view as Tab walks down the page
                readonly property Item focused: Window.activeFocusItem
                onFocusedChanged: {
                    let p = focused;
                    while (p && p !== pageLoader)
                        p = p.parent;
                    if (!p)
                        return;
                    const y = focused.mapToItem(pane.contentItem, 0, 0).y, pad = 48;
                    if (y - pad < contentY)
                        scrollBy(y - pad - contentY);
                    else if (y + focused.height + pad > contentY + height)
                        scrollBy(y + focused.height + pad - contentY - height);
                }

                Loader {
                    id: pageLoader

                    x: 40
                    y: 34
                    width: pane.width - 80
                    source: "Page" + root.page + ".qml"
                    onSourceChanged: pane.contentY = 0
                    onLoaded: if (root.focusAfterLoad) {
                        root.focusAfterLoad = false;
                        Qt.callLater(root.focusPage);
                    }
                }
            }
        }
    }
}
