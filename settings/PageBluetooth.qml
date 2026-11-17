// Bluetooth through BlueZ (Quickshell.Bluetooth). Shows a note when the
// machine has no adapter.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

ColumnLayout {
    id: page

    readonly property var adapter: Bluetooth.defaultAdapter

    spacing: 12

    SHeading {
        text: "Bluetooth"
    }

    SCard {
        visible: page.adapter === null

        SRow {
            label: "No Bluetooth adapter"
            note: "This PC doesn't have one (or the bluetooth service is off). Plug in a USB adapter and it shows up here."
        }
    }

    SCard {
        visible: page.adapter !== null

        SRow {
            label: "Bluetooth"
            note: page.adapter?.enabled ? (page.adapter?.discovering ? "Looking for devices…" : "On") : "Off"

            SToggle {
                checked: page.adapter?.enabled ?? false
                onToggled: page.adapter.enabled = !page.adapter.enabled
            }
        }
    }

    RowLayout {
        visible: page.adapter?.enabled ?? false
        Layout.fillWidth: true

        SSection {
            title: "Devices"
            Layout.fillWidth: true
        }
        SChip {
            text: page.adapter?.discovering ? "Stop scanning" : "Scan"
            onClicked: page.adapter.discovering = !page.adapter.discovering
        }
    }

    Repeater {
        model: (page.adapter?.enabled ?? false) ? page.adapter.devices : []

        SListItem {
            id: dev

            required property BluetoothDevice modelData

            icon: modelData.icon?.includes("audio") || modelData.icon?.includes("headset") ? "headphones" : modelData.icon?.includes("input") ? "mouse" : "bluetooth"
            title: modelData.name || modelData.address
            subtitle: modelData.connected ? "Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "") : modelData.paired ? "Paired" : ""
            active: modelData.connected
            onClicked: {
                if (modelData.connected)
                    modelData.disconnect();
                else if (modelData.paired)
                    modelData.connect();
                else
                    modelData.pair();
            }

            SChip {
                visible: dev.modelData.paired
                text: "Forget"
                danger: true
                onClicked: dev.modelData.forget()
            }
        }
    }
}
