// Updates: pending pacman + AUR packages, reboot hint after a kernel update,
// and a button that runs `archonate update` (cachy-update, snapshot first) in a terminal.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var info: null
    property bool checking: false
    property string error: ""

    readonly property var all: info ? [...info.repo, ...info.aur] : []

    spacing: 12

    function check(): void {
        checking = true;
        error = "";
        App.run(["python3", App.py, "updates"], (code, out, err) => {
            page.checking = false;
            if (code === 0)
                page.info = JSON.parse(out);
            else
                page.error = "Couldn't check for updates (offline?).";
        });
    }

    Component.onCompleted: check()

    SHeading {
        text: "Updates"
    }

    SCard {
        SRow {
            label: page.checking ? "Checking…" : page.all.length === 0 ? "You're up to date" : page.all.length + " updates available"
            note: page.info ? page.info.repo.length + " from the CachyOS/Arch repos, " + page.info.aur.length + " from the AUR" : ""

            SChip {
                text: "Check again"
                onClicked: page.check()
            }
            SChip {
                visible: page.all.length > 0
                text: "Update everything"
                selected: true
                onClicked: App.detached([App.bin + "archonate", "update"])
            }
        }
        SNote {
            visible: page.all.length > 0
            text: "Takes a snapshot, then runs cachy-update in a terminal: the news, the update, then cleanup (orphans, cache, .pacnew files, services)."
        }
    }

    SCard {
        visible: page.info?.reboot ?? false

        SRow {
            label: "Restart to finish updating"
            note: "The kernel you're running (" + (page.info?.kernel ?? "") + ") has been replaced by an update."

            SChip {
                text: "Restart now"
                danger: true
                onClicked: App.detached(["systemctl", "reboot"])
            }
        }
    }

    SLabel {
        visible: page.error !== ""
        text: page.error
        color: App.danger
    }

    SSection {
        visible: page.all.length > 0
        title: "Packages"
    }
    SCard {
        visible: page.all.length > 0
        spacing: 2

        Repeater {
            model: page.all

            RowLayout {
                id: pkg

                required property var modelData

                Layout.fillWidth: true
                spacing: 12

                SLabel {
                    Layout.fillWidth: true
                    text: pkg.modelData.name
                    elide: Text.ElideRight
                }
                SLabel {
                    text: pkg.modelData.from + "  →  " + pkg.modelData.to
                    color: App.dim
                    font.pixelSize: 12
                }
                Rectangle {
                    implicitWidth: src.implicitWidth + 12
                    implicitHeight: 20
                    radius: App.r(10)
                    color: pkg.modelData.source === "aur" ? Qt.alpha(App.accent, 0.25) : Qt.alpha(App.fg, 0.08)

                    SLabel {
                        id: src

                        anchors.centerIn: parent
                        text: pkg.modelData.source === "aur" ? "AUR" : "repo"
                        font.pixelSize: 11
                    }
                }
            }
        }
    }
}
