pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    spacing: 12

    SHeading {
        text: "Notifications"
    }
    SCard {
        SRow {
            label: "Do not disturb"
            note: "No popups and no sound in any rice. Notifications still land in the sidebar."

            SToggle {
                checked: App.global("dnd", false)
                onToggled: App.toggle("dnd", !checked)
            }
        }
    }

    SSection {
        title: "Sound"
    }
    SCard {
        SRow {
            label: "Desktop sounds"
            note: "Each rice's own sounds for unlocking, locking, a wrong password, screenshots and when its desktop starts."

            SToggle {
                checked: App.global("uiSounds", true)
                onToggled: App.setGlobal("uiSounds", !checked)
            }
        }
    }
    SRicePicker {}
    Repeater {
        model: App.info.sounds

        SListItem {
            id: snd

            required property var modelData

            icon: modelData.path === "" ? "notifications_off" : "music_note"
            title: modelData.name
            active: (App.edited?.notifSound ?? "") === modelData.path
            onClicked: {
                App.setRice("notifSound", modelData.path);
                // hear it
                const p = modelData.path.startsWith("rice:") ? App.home + "/.config/hypr/rices/" + (App.edited?.name ?? "") + "/assets/sounds/" + modelData.path.slice(5) + ".oga" : modelData.path;
                if (p !== "")
                    App.detached(["pw-play", p]);
            }

            SChip {
                visible: snd.modelData.path !== ""
                text: "▶ Play"
                onClicked: Quickshell.execDetached(["pw-play", snd.modelData.path])
            }
        }
    }
}
