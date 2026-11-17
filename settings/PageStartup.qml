// Startup apps: XDG autostart entries uwsm launches at login. Switching one
// off writes a user override (~/.config/autostart, Hidden=true), so system
// files are never touched. Changes apply from the next login.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: page

    property var entries: []
    property var apps: []
    property bool adding: false
    property string query: ""

    spacing: 12

    function reload(): void {
        App.run(["python3", App.py, "autostart"], (c, out) => page.entries = JSON.parse(out));
    }

    function set(file: string, action: string): void {
        App.run(["python3", App.py, "autostart", file, action], () => page.reload());
    }

    Component.onCompleted: reload()

    SHeading {
        text: "Startup apps"
    }
    SNote {
        text: "What opens by itself when you log in. Changes take effect next login."
    }

    SCard {
        spacing: 2

        Repeater {
            model: page.entries

            SListItem {
                id: entry

                required property var modelData

                icon: "rocket_launch"
                title: modelData.name
                subtitle: modelData.comment
                onClicked: page.set(modelData.file, modelData.enabled ? "disable" : "enable")

                SChip {
                    visible: entry.modelData.user && entry.modelData.enabled
                    text: "Remove"
                    danger: true
                    onClicked: page.set(entry.modelData.file, "remove")
                }
                SToggle {
                    checked: entry.modelData.enabled
                    onToggled: page.set(entry.modelData.file, entry.modelData.enabled ? "disable" : "enable")
                }
            }
        }
    }

    RowLayout {
        spacing: 8

        SChip {
            text: page.adding ? "Done" : "+ Add an app"
            onClicked: {
                page.adding = !page.adding;
                if (page.adding && page.apps.length === 0)
                    App.run(["python3", "-c", "import json,sys; sys.argv=['x']; exec(open('" + App.py + "').read().replace('if __name__ == \"__main__\":','if False:')); print(json.dumps(sorted(({'id': k, 'name': v['name'], 'icon': v['icon']} for k, v in desktop_entries().items()), key=lambda a: a['name'].lower())))"], (c, out) => page.apps = JSON.parse(out));
            }
        }
    }

    ColumnLayout {
        visible: page.adding
        Layout.fillWidth: true
        spacing: 8

        SField {
            Layout.fillWidth: true
            placeholder: "Search your apps"
            onTextChanged: page.query = text.toLowerCase()
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.apps.filter(a => page.query === "" || a.name.toLowerCase().includes(page.query)).slice(0, 40)

                Rectangle {
                    id: app

                    required property var modelData

                    implicitWidth: appRow.implicitWidth + 24
                    implicitHeight: 38
                    radius: App.r(10)
                    color: appHover.containsMouse ? Qt.alpha(App.fg, 0.08) : Qt.alpha(App.fg, 0.04)
                    border.width: App.bw
                    border.color: App.line
                    scale: appHover.pressed ? 0.96 : 1

                    Row {
                        id: appRow

                        anchors.centerIn: parent
                        spacing: 8

                        IconImage {
                            anchors.verticalCenter: parent.verticalCenter
                            implicitSize: 20
                            source: Quickshell.iconPath(app.modelData.icon, "application-x-executable")
                        }
                        SLabel {
                            anchors.verticalCenter: parent.verticalCenter
                            text: app.modelData.name
                        }
                    }
                    MouseArea {
                        id: appHover

                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            page.set(app.modelData.id, "add");
                            page.adding = false;
                        }
                    }
                    SFocus {
                        onActivated: {
                            page.set(app.modelData.id, "add");
                            page.adding = false;
                        }
                    }
                }
            }
        }
    }

    SSection {
        title: "Always started by your desktop"
    }
    SNote {
        text: "Part of the rice setup, not switchable here: the password prompt agent, clipboard history, the rice's own shell, Bluetooth media keys and your keyring."
    }
}
