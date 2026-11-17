// Night light through hyprsunset: warmth + an evening-to-morning schedule.
// Saved under global.nightlight; desktop.py writes ~/.config/hypr/hyprsunset.conf
// and (re)starts hyprsunset. common.lua starts it at login.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property bool installed: true
    readonly property var n: App.global("nightlight", {})

    spacing: 12

    function set(key: string, value: var): void {
        const d = JSON.parse(JSON.stringify(n));
        d[key] = value;
        App.run(["python3", App.py, "set", "global", "nightlight", JSON.stringify(d)], () => App.run(["python3", App.py, "nightlight"], () => App.refresh()));
    }

    Component.onCompleted: App.run(["sh", "-c", "command -v hyprsunset"], code => page.installed = code === 0)

    SHeading {
        text: "Night light"
    }

    SCard {
        visible: !page.installed

        SRow {
            label: "Night light needs hyprsunset"
            note: "Hyprland's own screen-warming tool. One package, from the official repos."

            SChip {
                text: "Install"
                selected: true
                onClicked: App.detached(["kitty", "--title", "Install hyprsunset", "--hold", "sudo", "pacman", "-S", "hyprsunset"])
            }
            SChip {
                text: "I've installed it"
                onClicked: App.run(["sh", "-c", "command -v hyprsunset"], code => page.installed = code === 0)
            }
        }
    }

    SCard {
        visible: page.installed

        SRow {
            label: "Night light"
            note: "Warms the screen in the evening so it's easier on your eyes."

            SToggle {
                checked: page.n.enabled ?? false
                onToggled: App.toggle("nightlight", !(page.n.enabled ?? false))
            }
        }
        SRow {
            label: "Warmth"
            note: (page.n.temp ?? 4000) + " K · lower is warmer"
        }
        SSlider {
            Layout.fillWidth: true
            // 2500 K (candle) .. 6000 K (barely warm)
            value: 1 - ((page.n.temp ?? 4000) - 2500) / 3500
            onReleased: v => page.set("temp", Math.round((6000 - v * 3500) / 100) * 100)
        }
        SRow {
            label: "Turns on at"

            Repeater {
                model: ["18:00", "19:00", "20:00", "21:00", "22:00"]

                SChip {
                    required property string modelData

                    text: modelData
                    selected: (page.n.from ?? "20:00") === modelData
                    onClicked: page.set("from", modelData)
                }
            }
        }
        SRow {
            label: "Turns off at"

            Repeater {
                model: ["05:00", "06:00", "07:00", "08:00", "09:00"]

                SChip {
                    required property string modelData

                    text: modelData
                    selected: (page.n.to ?? "07:00") === modelData
                    onClicked: page.set("to", modelData)
                }
            }
        }
    }
}
