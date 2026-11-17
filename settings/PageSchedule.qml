// Day & night: one rice by day, another by night (archonate with any style).
// Saved under global.schedule; the shell checks once a minute and switches only
// when the period changes, so picking a rice by hand holds until the next change.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    readonly property var sc: App.global("schedule", {})
    readonly property bool on: sc.enabled ?? false
    readonly property var rices: (App.info.rices ?? []).filter(r => r.standalone).map(r => r.name)
    property var styles: []
    property var styled: ["archonate"] // rices that wear styles
    property string period: ""

    spacing: 12

    function set(key: string, value: var): void {
        const d = JSON.parse(JSON.stringify(sc));
        d[key] = value;
        App.run(["python3", App.py, "set", "global", "schedule", JSON.stringify(d)], () => {
            App.refresh();
            // Show the change now, not at the next sunrise
            if (d.enabled)
                App.detached([App.bin + "archonate", "schedule", "apply"]);
            page.status();
        });
    }

    function pick(which: string, key: string, value: string): void {
        const p = JSON.parse(JSON.stringify(sc[which] ?? {}));
        p[key] = value;
        set(which, p);
    }

    function status(): void {
        App.run(["python3", App.py, "schedule"], (c, out) => {
            try {
                page.period = JSON.parse(out).period;
            } catch (e) {}
        });
    }

    Component.onCompleted: {
        App.run(["python3", App.py, "styles"], (c, out) => {
            try {
                const d = JSON.parse(out);
                page.styles = d.styles;
                page.styled = d.styled ?? page.styled;
            } catch (e) {}
        });
        status();
    }

    SHeading {
        text: "Day & night"
    }

    SCard {
        SRow {
            label: "Change rice by time of day"
            note: page.on ? "It's " + (page.period || "…") + " now. Picking a rice yourself holds until the next change; never switches during gaming mode." : "One rice by day, another by night."

            SToggle {
                checked: page.on
                onToggled: page.set("enabled", !page.on)
            }
        }
    }

    Repeater {
        model: [["day", "By day", "light_mode"], ["night", "By night", "dark_mode"]]

        ColumnLayout {
            id: part

            required property var modelData
            readonly property string which: modelData[0]
            readonly property var choice: page.sc[which] ?? {}

            Layout.fillWidth: true
            spacing: 8
            opacity: page.on ? 1 : 0.55

            SSection {
                title: part.modelData[1]
            }
            SCard {
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: page.rices

                        SChip {
                            required property string modelData

                            text: modelData
                            selected: part.choice.rice === modelData
                            onClicked: page.pick(part.which, "rice", modelData)
                        }
                    }
                }
                SNote {
                    visible: page.styled.includes(part.choice.rice)
                    text: "Style"
                }
                Flow {
                    Layout.fillWidth: true
                    visible: page.styled.includes(part.choice.rice)
                    spacing: 6

                    Repeater {
                        model: page.styled.includes(part.choice.rice) ? page.styles : []

                        SChip {
                            required property var modelData

                            text: modelData.title
                            selected: part.choice.style === modelData.name
                            onClicked: page.pick(part.which, "style", modelData.name)
                        }
                    }
                }
            }
        }
    }

    SSection {
        title: "When"
    }
    SCard {
        opacity: page.on ? 1 : 0.55

        SRow {
            label: "Follow night light's times"
            note: "Night from " + (App.global("nightlight", {}).from ?? "20:00") + ", day from " + (App.global("nightlight", {}).to ?? "07:00") + " (Settings > Night light)."

            SToggle {
                checked: page.sc.followNightlight ?? true
                onToggled: page.set("followNightlight", !(page.sc.followNightlight ?? true))
            }
        }
        SRow {
            visible: !(page.sc.followNightlight ?? true)
            label: "Day starts"

            Repeater {
                model: ["05:00", "06:00", "07:00", "08:00", "09:00"]

                SChip {
                    required property string modelData

                    text: modelData
                    selected: (page.sc.dayFrom ?? "07:00") === modelData
                    onClicked: page.set("dayFrom", modelData)
                }
            }
        }
        SRow {
            visible: !(page.sc.followNightlight ?? true)
            label: "Night starts"

            Repeater {
                model: ["17:00", "18:00", "19:00", "20:00", "21:00", "22:00"]

                SChip {
                    required property string modelData

                    text: modelData
                    selected: (page.sc.nightFrom ?? "20:00") === modelData
                    onClicked: page.set("nightFrom", modelData)
                }
            }
        }
    }
}
