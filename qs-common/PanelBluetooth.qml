// Bluetooth: on/off and your devices, connect or disconnect in a click.
import QtQuick
import QtQuick.Layouts
import Quickshell.Bluetooth

ColumnLayout {
    id: page

    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var devices: (bt?.devices?.values ?? []).filter(d => d.paired || d.connected).sort((a, b) => b.connected - a.connected)

    width: 344
    spacing: 8

    QHeader {
        Layout.fillWidth: true
        icon: page.bt?.enabled ? "bluetooth" : "bluetooth_disabled"
        title: "Bluetooth"

        QToggle {
            visible: page.bt !== null
            checked: page.bt?.enabled ?? false
            onToggled: page.bt.enabled = !page.bt.enabled
        }
    }

    QText {
        visible: !page.bt
        text: "No Bluetooth adapter found"
        dim: true
    }

    Repeater {
        model: page.bt?.enabled ? page.devices : []

        QItem {
            required property var modelData

            Layout.fillWidth: true
            icon: modelData.icon?.includes("audio") || modelData.icon?.includes("head") ? "headphones" : modelData.icon?.includes("input") ? "mouse" : modelData.icon?.includes("phone") ? "smartphone" : "bluetooth"
            title: modelData.name || modelData.address
            sub: modelData.connected ? (modelData.batteryAvailable ? "Connected · " + Math.round(modelData.battery * 100) + "%" : "Connected") : modelData.state === BluetoothDeviceState.Connecting ? "Connecting…" : "Not connected"
            active: modelData.connected
            busy: modelData.state === BluetoothDeviceState.Connecting || modelData.state === BluetoothDeviceState.Disconnecting
            onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
        }
    }

    QText {
        visible: (page.bt?.enabled ?? false) && page.devices.length === 0
        text: "No paired devices yet"
        dim: true
    }

    QLink {
        Layout.fillWidth: true
        text: "Pair a device"
        page: "bluetooth"
    }
}
