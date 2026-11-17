// Storage: disks, biggest folders in home, and cleanups (package caches,
// orphaned packages). Cleanups that need root run in a terminal.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var info: null
    property bool loading: true

    spacing: 12

    function size(b: real): string {
        const u = ["B", "KB", "MB", "GB", "TB"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024;
            i++;
        }
        return (i >= 3 ? b.toFixed(1) : Math.round(b)) + " " + u[i];
    }

    function reload(): void {
        loading = true;
        App.run(["python3", App.py, "storage"], (c, out) => {
            page.info = JSON.parse(out);
            page.loading = false;
        });
    }

    function term(title: string, cmd: string): void {
        App.detached(["kitty", "--title", title, "--hold", "sh", "-c", cmd]);
    }

    Component.onCompleted: reload()

    SHeading {
        text: "Storage"
    }
    SNote {
        visible: page.loading
        text: "Measuring folders… this takes a few seconds."
    }

    Repeater {
        model: page.info?.disks ?? []

        SCard {
            id: disk

            required property var modelData

            SRow {
                label: disk.modelData.mount === "/" ? "System disk" : disk.modelData.mount
                note: page.size(disk.modelData.used) + " of " + page.size(disk.modelData.total) + " used · " + page.size(disk.modelData.total - disk.modelData.used) + " free · " + disk.modelData.fs
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 10
                radius: App.r(5)
                color: Qt.alpha(App.fg, 0.12)

                Rectangle {
                    width: parent.width * disk.modelData.used / disk.modelData.total
                    height: parent.height
                    radius: App.r(5)
                    color: disk.modelData.used / disk.modelData.total > 0.9 ? App.danger : App.accent
                }
            }
        }
    }

    SSection {
        visible: page.info !== null
        title: "Biggest folders in your home"
    }
    SCard {
        visible: page.info !== null
        spacing: 6

        Repeater {
            model: page.info?.folders ?? []

            RowLayout {
                id: folder

                required property var modelData

                Layout.fillWidth: true
                spacing: 12

                SLabel {
                    Layout.preferredWidth: 220
                    text: folder.modelData.name
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: App.r(3)
                    color: "transparent"

                    Rectangle {
                        width: parent.width * folder.modelData.size / Math.max(1, page.info.folders[0].size)
                        height: parent.height
                        radius: App.r(3)
                        color: Qt.alpha(App.accent, 0.7)
                    }
                }
                SLabel {
                    Layout.preferredWidth: 80
                    horizontalAlignment: Text.AlignRight
                    text: page.size(folder.modelData.size)
                    color: App.dim
                    font.pixelSize: 13
                }
            }
        }
    }

    SSection {
        visible: page.info !== null
        title: "Clean up"
    }
    SCard {
        visible: page.info !== null

        SRow {
            label: "Old package downloads"
            note: page.size(page.info?.pacmanCache ?? 0) + " · keeps the newest copy of each package, in case you need to roll back"

            SChip {
                text: "Clean"
                onClicked: page.term("Clean package cache", "sudo paccache -rk1 && sudo paccache -ruk0")
            }
        }
        SRow {
            label: "AUR build files"
            note: page.size(page.info?.paruCache ?? 0) + " · source and build leftovers from paru"

            SChip {
                text: "Clean"
                onClicked: page.term("Clean AUR cache", "paru -Sccd --noconfirm")
            }
        }
        SRow {
            label: "Unused packages"
            note: (page.info?.orphans.length ?? 0) === 0 ? "None, nice." : page.info.orphans.length + " installed as dependencies but no longer needed: " + page.info.orphans.slice(0, 6).join(", ") + (page.info.orphans.length > 6 ? "…" : "")

            SChip {
                visible: (page.info?.orphans.length ?? 0) > 0
                text: "Review & remove"
                onClicked: page.term("Remove unused packages", "sudo pacman -Rns $(pacman -Qtdq)")
            }
        }
    }
    SChip {
        text: "Measure again"
        onClicked: page.reload()
    }
}
