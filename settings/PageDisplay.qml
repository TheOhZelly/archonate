// Display: resolution/refresh rate and scale per monitor (saved in
// settings.json, applied by common.lua), plus brightness over DDC/CI.
// Changing a mode asks "keep these settings?" and reverts after 15 s.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var monitors: []
    property var previous: null // display settings to restore if not confirmed
    property int countdown: 0
    property real brightness: -1
    property bool ddcBusy: false

    spacing: 12

    function reload(): void {
        App.run(["hyprctl", "monitors", "-j"], (c, out) => page.monitors = JSON.parse(out));
    }

    function saved(): var {
        return JSON.parse(JSON.stringify(App.global("display", {})));
    }

    // Apply a change, keep the old settings to fall back to
    function apply(name: string, key: string, value: var): void {
        const d = saved();
        if (previous === null)
            previous = saved();
        d[name] = Object.assign({}, d[name] ?? {}, { [key]: value });
        App.run(["python3", App.py, "set", "global", "display", JSON.stringify(d)], () => {
            App.run(["hyprctl", "reload"], () => {
                App.refresh();
                page.reload();
                page.countdown = 15;
            });
        });
    }

    function revert(): void {
        countdown = 0;
        const d = previous ?? {};
        previous = null;
        App.run(["python3", App.py, "set", "global", "display", JSON.stringify(d)], () => App.run(["hyprctl", "reload"], () => {
                App.refresh();
                page.reload();
            }));
    }

    function keep(): void {
        countdown = 0;
        previous = null;
    }

    // "1920x1080@165.00Hz" -> "1920x1080@165"
    function modeKey(m: string): string {
        return m.replace(/\.\d+Hz$|Hz$/, "").replace(/(@\d+)\.\d+$/, "$1");
    }

    Component.onCompleted: {
        reload();
        App.run(["ddcutil", "getvcp", "10", "--brief"], (c, out) => {
            const m = out.match(/C (\d+) (\d+)/);
            page.brightness = m ? parseInt(m[1]) / parseInt(m[2]) : -1;
        });
    }

    Timer {
        running: page.countdown > 0
        repeat: true
        interval: 1000
        onTriggered: {
            page.countdown--;
            if (page.countdown === 0)
                page.revert();
        }
    }

    SHeading {
        text: "Display"
    }

    // Keep / revert banner
    Rectangle {
        visible: page.countdown > 0
        Layout.fillWidth: true
        implicitHeight: 60
        radius: App.r(12)
        color: Qt.alpha(App.accent, 0.18)
        border.width: App.bw
        border.color: App.accent

        RowLayout {
            anchors.fill: parent
            anchors.margins: 14
            spacing: 10

            SLabel {
                Layout.fillWidth: true
                text: "Keep these display settings? Reverting in " + page.countdown + " s."
                font.weight: Font.DemiBold
            }
            SChip {
                text: "Keep"
                selected: true
                onClicked: page.keep()
            }
            SChip {
                text: "Revert"
                onClicked: page.revert()
            }
        }
    }

    SCard {
        visible: page.brightness >= 0

        SRow {
            label: "Brightness"
            note: "Set on the monitor itself, over the display cable."
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            Text {
                text: "brightness_6"
                font.family: "Material Symbols Rounded"
                font.pixelSize: 22
                color: App.accent
            }
            SSlider {
                id: bright

                Layout.fillWidth: true
                value: page.brightness
                // DDC is slow, so only send the final value
                onReleased: v => {
                    page.brightness = v;
                    App.run(["ddcutil", "setvcp", "10", String(Math.round(v * 100))], () => {});
                }
            }
            SLabel {
                Layout.preferredWidth: 42
                horizontalAlignment: Text.AlignRight
                text: Math.round(bright.live * 100) + "%"
                font.pixelSize: 13
            }
        }
    }

    Repeater {
        model: page.monitors

        ColumnLayout {
            id: mon

            required property var modelData
            readonly property string current: modelData.width + "x" + modelData.height + "@" + Math.round(modelData.refreshRate)
            readonly property var modes: {
                const seen = {};
                for (const m of modelData.availableModes) {
                    const k = page.modeKey(m);
                    seen[k] = true;
                }
                return Object.keys(seen);
            }
            readonly property var resolutions: [...new Set(modes.map(m => m.split("@")[0]))]
            readonly property string res: modelData.width + "x" + modelData.height

            Layout.fillWidth: true
            spacing: 12

            SSection {
                title: mon.modelData.name + " · " + (mon.modelData.make + " " + mon.modelData.model).trim()
            }
            SCard {
                SRow {
                    label: "Resolution"
                    note: mon.current + " Hz now"
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: mon.resolutions.slice(0, 8)

                        SChip {
                            required property string modelData

                            text: modelData
                            selected: modelData === mon.res
                            onClicked: {
                                // Highest refresh rate available at that resolution
                                const best = mon.modes.filter(m => m.startsWith(modelData + "@")).sort((a, b) => parseInt(b.split("@")[1]) - parseInt(a.split("@")[1]))[0];
                                page.apply(mon.modelData.name, "mode", best);
                            }
                        }
                    }
                }

                SRow {
                    label: "Refresh rate"
                    note: "Higher is smoother. Your monitor's maximum is the last one."
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [...new Set(mon.modes.filter(m => m.startsWith(mon.res + "@")).map(m => parseInt(m.split("@")[1])))].sort((a, b) => a - b)

                        SChip {
                            required property int modelData

                            text: modelData + " Hz"
                            selected: modelData === Math.round(mon.modelData.refreshRate)
                            onClicked: page.apply(mon.modelData.name, "mode", mon.res + "@" + modelData)
                        }
                    }
                }

                SRow {
                    label: "Scale"
                    note: "Makes everything bigger. 100% suits a 27\" 1080p screen."
                }
                Flow {
                    Layout.fillWidth: true
                    spacing: 8

                    Repeater {
                        model: [1, 1.25, 1.5, 2]

                        SChip {
                            required property real modelData

                            text: Math.round(modelData * 100) + "%"
                            selected: Math.abs(mon.modelData.scale - modelData) < 0.01
                            onClicked: page.apply(mon.modelData.name, "scale", modelData)
                        }
                    }
                }
            }
        }
    }
}
