// Power: lock, log out, sleep, restart, shut down.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    width: 320
    spacing: 14

    QHeader {
        Layout.fillWidth: true
        icon: "power_settings_new"
        title: "Power"
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        spacing: 12

        Repeater {
            model: [["lock", "lock", "Lock"], ["logout", "logout", "Log out"], ["suspend", "bedtime", "Sleep"], ["reboot", "restart_alt", "Restart"], ["shutdown", "power_settings_new", "Shut down"]]

            QIconButton {
                required property var modelData

                icon: modelData[1]
                caption: modelData[2]
                size: 48
                accent: modelData[0] === "shutdown"
                onClicked: {
                    Arch.panels.close();
                    Arch.cmd(["power", modelData[0]]);
                }
            }
        }
    }

    QLink {
        Layout.fillWidth: true
        text: "Lock & power settings"
        page: "power"
    }
}
