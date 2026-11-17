// Updates: what's waiting, and one button that snapshots then updates.
import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    readonly property var svc: Arch.services
    readonly property var all: [...(svc?.updates?.repo ?? []), ...(svc?.updates?.aur ?? [])]

    width: 344
    spacing: 8

    QHeader {
        Layout.fillWidth: true
        icon: "system_update"
        title: "Updates"

        QIconButton {
            icon: page.svc?.checkingUpdates ? "progress_activity" : "refresh"
            size: 30
            onClicked: page.svc.checkUpdates()
        }
    }

    QItem {
        Layout.fillWidth: true
        visible: page.svc?.rebootNeeded ?? false
        icon: "restart_alt"
        title: "Restart to finish updating"
        sub: "Kernel " + (page.svc?.updates?.kernel ?? "") + " was replaced"
        active: true
        onClicked: {
            Arch.panels.close();
            Arch.cmd(["power", "reboot"]);
        }
    }

    QText {
        text: page.svc?.checkingUpdates ? "Checking…" : page.all.length === 0 ? "You're up to date" : page.all.length + " packages (" + (page.svc.updates.aur?.length ?? 0) + " from the AUR)"
        dim: true
    }

    Repeater {
        model: page.all.slice(0, 8)

        QItem {
            required property var modelData

            Layout.fillWidth: true
            implicitHeight: 30
            title: modelData.name
            trailing: modelData.to
        }
    }
    QText {
        visible: page.all.length > 8
        text: "and " + (page.all.length - 8) + " more"
        dim: true
        leftPadding: 10
    }

    QItem {
        Layout.fillWidth: true
        visible: page.all.length > 0
        icon: "download"
        title: "Update now"
        sub: "Takes a snapshot first, so you can roll back from the boot menu"
        active: true
        onClicked: {
            Arch.panels.close();
            Arch.cmd(["update"]);
        }
    }

    QLink {
        Layout.fillWidth: true
        text: "Update settings"
        page: "updates"
    }
}
