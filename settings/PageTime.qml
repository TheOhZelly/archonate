// Date & time: timezone and automatic time sync (timedatectl; the system
// asks for your password through the polkit prompt).
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page

    property var info: ({ timezone: "", ntp: true, synced: false, zones: [] })
    property bool picking: false
    property string query: ""

    spacing: 12

    function reload(): void {
        App.run(["python3", App.py, "time"], (c, out) => page.info = JSON.parse(out));
    }

    Component.onCompleted: reload()

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    SHeading {
        text: "Date & time"
    }

    SCard {
        SLabel {
            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
            font.pixelSize: 40
            font.weight: Font.Light
            font.letterSpacing: -1
        }
        SLabel {
            text: Qt.formatDateTime(clock.date, "dddd d MMMM yyyy")
            color: App.dim
        }
    }

    SCard {
        SRow {
            label: "Set time automatically"
            note: page.info.ntp ? (page.info.synced ? "Synced with internet time" : "Waiting to sync…") : "Off: the clock keeps whatever it's set to"

            SToggle {
                checked: page.info.ntp
                onToggled: App.run(["timedatectl", "set-ntp", page.info.ntp ? "false" : "true"], () => page.reload())
            }
        }
        SRow {
            label: "Time zone"
            note: page.info.timezone.replace(/_/g, " ")

            SChip {
                text: page.picking ? "Cancel" : "Change"
                onClicked: page.picking = !page.picking
            }
        }
        ColumnLayout {
            visible: page.picking
            Layout.fillWidth: true
            spacing: 6

            SField {
                id: zoneSearch

                Layout.fillWidth: true
                placeholder: "Search a city or region, e.g. Athens, London, Tokyo"
                onTextChanged: page.query = text.toLowerCase().replace(/ /g, "_")
                onVisibleChanged: if (visible)
                    focusInput()
            }
            Repeater {
                model: page.query.length < 2 ? [] : page.info.zones.filter(z => z.toLowerCase().includes(page.query)).slice(0, 8)

                SListItem {
                    required property string modelData

                    icon: "public"
                    title: modelData.replace(/_/g, " ")
                    active: modelData === page.info.timezone
                    onClicked: App.run(["timedatectl", "set-timezone", modelData], () => {
                        page.picking = false;
                        page.reload();
                    })
                }
            }
        }
    }
}
