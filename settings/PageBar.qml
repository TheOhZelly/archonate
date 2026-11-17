pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// The archonate bar's options. Saved per rice (settings.json > rices > archonate) and
// picked up live by its Bar.qml; other rices keep their fixed bars.
ColumnLayout {
    id: page

    spacing: 12

    readonly property var arch: App.info.rices.find(r => r.name === "archonate") ?? null
    function val(key: string, def: bool): bool {
        return page.arch?.[key] ?? def;
    }
    function set(key: string, on: bool): void {
        App.exec(["python3", App.py, "set", "archonate", key, JSON.stringify(on)]);
    }

    component Opt: SRow {
        id: opt

        property string key
        property bool def: true

        SToggle {
            checked: page.val(opt.key, opt.def)
            onToggled: page.set(opt.key, !checked)
        }
    }

    SHeading {
        text: "Bar & desktop"
    }
    SNote {
        Layout.fillWidth: true
        visible: App.info.rice !== "archonate"
        text: "These are the archonate rice's bar options. They take effect when archonate is the active rice."
    }

    SSection {
        title: "Clock"
    }
    SCard {
        Opt {
            label: "24-hour time"
            note: "Off shows 9:41 PM."
            key: "barClock24"
        }
        Opt {
            label: "Seconds"
            key: "barSeconds"
            def: false
        }
        Opt {
            label: "Date"
            note: "The weekday and day beside the time."
            key: "barDate"
        }
    }

    SSection {
        title: "What the bar shows"
    }
    SCard {
        Opt {
            label: "Workspace numbers"
            note: "Numbers on every workspace instead of dots."
            key: "barWsNumbers"
            def: false
        }
        Opt {
            label: "CPU and memory"
            key: "barStats"
        }
        Opt {
            label: "Now playing"
            note: "Controls, the track title and a little live meter."
            key: "barMedia"
        }
        Opt {
            label: "Tray"
            note: "Icons of apps running in the background."
            key: "barTray"
        }
        Opt {
            label: "Volume percentage"
            key: "barVolume"
        }
        Opt {
            label: "Music line"
            note: "The hairline across the top that ripples with whatever's playing."
            key: "barWave"
        }
    }

    SSection {
        title: "Desktop"
    }
    SCard {
        SRow {
            label: "Desktop widgets"
            note: "The visualizer, media card, clock and stats on the wallpaper. Off in gaming mode. SUPER+F12."

            SToggle {
                checked: App.global("widgets", true)
                onToggled: App.toggle("widgets", !checked)
            }
        }
    }
}
