pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    spacing: 12

    SHeading {
        text: "Lock & power"
    }
    SNote {
        text: "Applies to every rice."
    }

    SCard {
        SRow {
            label: "Keep awake"
            note: "Never lock or turn the screen off by itself until you switch this off. Also in the bar's quick settings."

            SToggle {
                checked: App.global("caffeine", false)
                onToggled: App.toggle("caffeine", !checked)
            }
        }
    }

    SSection {
        title: "Screensaver after"
    }
    SNote {
        text: "The ARCHONATE logo, animated in your rice's colours. Any key or mouse movement ends it. Also: archonate screensaver."
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8

        SChip {
            text: "Off"
            selected: !App.global("screensaver", true)
            onClicked: App.toggle("screensaver", false)
        }
        Repeater {
            model: [[1, "1 min"], [2, "2 min"], [3, "3 min"], [5, "5 min"], [8, "8 min"]]

            SChip {
                required property var modelData

                text: modelData[1]
                selected: App.global("screensaver", true) && App.global("screensaverMinutes", 5) === modelData[0]
                onClicked: {
                    App.setGlobal("screensaverMinutes", modelData[0]);
                    if (!App.global("screensaver", true))
                        App.toggle("screensaver", true);
                }
            }
        }
        SChip {
            text: "Preview"
            onClicked: App.detached([App.bin + "archonate", "screensaver"])
        }
    }

    SSection {
        title: "Lock after"
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [[0, "Never"], [5, "5 min"], [10, "10 min"], [15, "15 min"], [30, "30 min"], [60, "1 hour"]]

            SChip {
                required property var modelData

                text: modelData[1]
                selected: App.global("idleMinutes", 10) === modelData[0]
                onClicked: App.setGlobal("idleMinutes", modelData[0])
            }
        }
    }

    SSection {
        title: "Screen off after"
    }
    Flow {
        Layout.fillWidth: true
        spacing: 8

        Repeater {
            model: [[0, "Never"], [10, "10 min"], [15, "15 min"], [30, "30 min"], [60, "1 hour"]]

            SChip {
                required property var modelData

                text: modelData[1]
                selected: App.global("screenOffMinutes", 15) === modelData[0]
                onClicked: App.setGlobal("screenOffMinutes", modelData[0])
            }
        }
    }

    SSection {
        title: "Lock screen"
    }
    RowLayout {
        spacing: 8

        SChip {
            text: "Lock now"
            onClicked: App.detached(["qs", "-p", App.home + "/.config/hypr/rices/" + App.info.rice + "/shell", "ipc", "call", "rice", "lock"])
        }
        SChip {
            text: "Preview design"
            onClicked: App.detached(["qs", "-p", App.home + "/.config/hypr/rices/" + App.info.rice + "/shell", "ipc", "call", "rice", "previewLock"])
        }
    }

    SSection {
        title: "Power"
    }
    RowLayout {
        spacing: 8

        SChip {
            text: "Suspend"
            onClicked: App.detached(["systemctl", "suspend-then-hibernate"])
        }
        SChip {
            text: "Restart"
            danger: true
            onClicked: confirm.ask("restart", ["systemctl", "reboot"])
        }
        SChip {
            text: "Shut down"
            danger: true
            onClicked: confirm.ask("shut down", ["systemctl", "poweroff"])
        }
    }
    // Restart/shut down need a second click, so a stray click can't do it
    RowLayout {
        id: confirm

        property string what
        property var cmd: []

        function ask(w: string, c: var): void {
            what = w;
            cmd = c;
            visible = true;
        }

        visible: false
        spacing: 8

        SLabel {
            text: "Really " + confirm.what + "?"
            color: App.danger
        }
        SChip {
            text: "Yes, " + confirm.what
            danger: true
            onClicked: App.detached(confirm.cmd)
        }
        SChip {
            text: "Cancel"
            onClicked: confirm.visible = false
        }
    }
}
