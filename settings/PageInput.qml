// Keyboard & mouse: layouts, layout switch key, key repeat, pointer speed,
// acceleration and scroll direction. Saved under global.input in
// settings.json and applied by common.lua on reload.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    readonly property var input: App.global("input", {})
    readonly property var layouts: (input.layouts ?? "us,gr").split(",").filter(s => s)
    readonly property var known: [["us", "English (US)"], ["gb", "English (UK)"], ["gr", "Greek"], ["de", "German"], ["fr", "French"], ["es", "Spanish"], ["it", "Italian"], ["pt", "Portuguese"], ["ru", "Russian"], ["ua", "Ukrainian"], ["pl", "Polish"], ["tr", "Turkish"], ["jp", "Japanese"]]

    spacing: 12

    function nameOf(code: string): string {
        return known.find(k => k[0] === code)?.[1] ?? code;
    }

    function set(key: string, value: var): void {
        const d = JSON.parse(JSON.stringify(input));
        d[key] = value;
        App.run(["python3", App.py, "set", "global", "input", JSON.stringify(d)], () => App.run(["hyprctl", "reload"], () => App.refresh()));
    }

    SHeading {
        text: "Keyboard & mouse"
    }

    SSection {
        title: "Keyboard layouts"
    }
    SCard {
        Repeater {
            model: page.layouts

            SListItem {
                id: lay

                required property string modelData
                required property int index

                icon: "keyboard"
                title: page.nameOf(modelData)
                subtitle: index === 0 ? "Default" : ""
                clickable: false

                SChip {
                    visible: lay.index > 0
                    text: "Make default"
                    onClicked: page.set("layouts", [lay.modelData, ...page.layouts.filter(l => l !== lay.modelData)].join(","))
                }
                SChip {
                    visible: page.layouts.length > 1
                    text: "Remove"
                    danger: true
                    onClicked: page.set("layouts", page.layouts.filter(l => l !== lay.modelData).join(","))
                }
            }
        }
        SNote {
            text: "Add a layout:"
        }
        Flow {
            Layout.fillWidth: true
            spacing: 8

            Repeater {
                model: page.known.filter(k => !page.layouts.includes(k[0]))

                SChip {
                    required property var modelData

                    text: "+ " + modelData[1]
                    onClicked: page.set("layouts", [...page.layouts, modelData[0]].join(","))
                }
            }
        }
        SRow {
            label: "Switch layouts with"

            Repeater {
                model: [["grp:win_space_toggle", "Super+Space"], ["grp:alt_shift_toggle", "Alt+Shift"], ["grp:ctrl_shift_toggle", "Ctrl+Shift"]]

                SChip {
                    required property var modelData

                    text: modelData[1]
                    selected: (page.input.switchKey ?? "grp:win_space_toggle") === modelData[0]
                    onClicked: page.set("switchKey", modelData[0])
                }
            }
        }
    }

    SSection {
        title: "Key repeat"
    }
    SCard {
        SRow {
            label: "Delay before repeating"
            note: (page.input.repeatDelay ?? 250) + " ms"
        }
        SSlider {
            Layout.fillWidth: true
            // 150..600 ms
            value: ((page.input.repeatDelay ?? 250) - 150) / 450
            onReleased: v => page.set("repeatDelay", Math.round(150 + v * 450))
        }
        SRow {
            label: "Repeat speed"
            note: (page.input.repeatRate ?? 35) + " per second"
        }
        SSlider {
            Layout.fillWidth: true
            // 15..60 per second
            value: ((page.input.repeatRate ?? 35) - 15) / 45
            onReleased: v => page.set("repeatRate", Math.round(15 + v * 45))
        }
    }

    SSection {
        title: "Mouse"
    }
    SCard {
        SRow {
            label: "Pointer speed"
            note: ((page.input.sensitivity ?? 0) >= 0 ? "+" : "") + (page.input.sensitivity ?? 0).toFixed(2)
        }
        SSlider {
            Layout.fillWidth: true
            // -1..1
            value: ((page.input.sensitivity ?? 0) + 1) / 2
            onReleased: v => page.set("sensitivity", Math.round((v * 2 - 1) * 100) / 100)
        }
        SRow {
            label: "Acceleration"
            note: "Flat moves the pointer exactly as far as the mouse. Adaptive speeds it up on fast flicks."

            SChip {
                text: "Flat"
                selected: (page.input.accel ?? "flat") === "flat"
                onClicked: page.set("accel", "flat")
            }
            SChip {
                text: "Adaptive"
                selected: (page.input.accel ?? "flat") === "adaptive"
                onClicked: page.set("accel", "adaptive")
            }
        }
        SRow {
            label: "Natural scrolling"
            note: "Content follows your fingers, like on a phone."

            SToggle {
                checked: page.input.naturalScroll ?? false
                onToggled: page.set("naturalScroll", !checked)
            }
        }
    }
}
