// Quick settings: the hub. Volume, every switch, network and Bluetooth (with
// a way deeper into each), the rice and its wallpaper, and the way out.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

ColumnLayout {
    id: page

    readonly property var svc: Arch.services
    readonly property var tog: Arch.toggles
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var btOn: (bt?.devices?.values ?? []).filter(d => d.connected)
    readonly property string rice: Arch.toggles?.cfg?.rice ?? ""

    width: 344
    spacing: 12

    QHeader {
        Layout.fillWidth: true
        icon: "tune"
        title: page.rice + "  ·  " + (page.tog?.mode ?? "")

        QIconButton {
            icon: "settings"
            size: 32
            onClicked: Arch.settings("")
        }
        QIconButton {
            icon: "lock"
            size: 32
            onClicked: {
                Arch.panels.close();
                Arch.cmd(["lock"]);
            }
        }
        QIconButton {
            icon: "power_settings_new"
            size: 32
            onClicked: Arch.panels.swap("power")
        }
    }

    QSlider {
        Layout.fillWidth: true
        icon: page.svc?.volumeIcon ?? "volume_up"
        value: page.svc?.muted ? 0 : (page.svc?.volume ?? 0)
        onMoved: v => page.svc.setVolume(v)
        onIconClicked: page.svc.toggleMute()
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 8
        columnSpacing: 8

        QTile {
            Layout.fillWidth: true
            icon: page.svc?.netIcon ?? "wifi"
            label: page.svc?.netWifi ? "Wi-Fi" : "Network"
            sub: page.svc?.netName ?? ""
            on: page.svc?.netDevice !== null
            more: true
            onClicked: Arch.panels.swap("network")
            onMoreClicked: Arch.panels.swap("network")
        }
        QTile {
            Layout.fillWidth: true
            icon: page.bt?.enabled ? "bluetooth" : "bluetooth_disabled"
            label: "Bluetooth"
            sub: !page.bt ? "no adapter" : !page.bt.enabled ? "off" : page.btOn.length ? page.btOn[0].name : "on"
            on: page.bt?.enabled ?? false
            more: true
            onClicked: if (page.bt)
                page.bt.enabled = !page.bt.enabled
            onMoreClicked: Arch.panels.swap("bluetooth")
        }

        Repeater {
            model: page.tog?.all ?? []

            QTile {
                required property var modelData

                Layout.fillWidth: true
                icon: page.tog.icon(modelData[0], on)
                label: modelData[1]
                on: page.tog.state(modelData[0])
                sub: modelData[0] === "nightlight" && on ? "warm until morning" : modelData[0] === "caffeine" && on ? "won't lock or sleep" : ""
                onClicked: page.tog.flip(modelData[0])
            }
        }
    }

    // Now playing, if anything is
    QItem {
        Layout.fillWidth: true
        visible: (page.svc?.nowPlaying ?? "") !== ""
        icon: page.svc?.player?.isPlaying ? "graphic_eq" : "music_note"
        title: page.svc?.player?.trackTitle ?? ""
        sub: page.svc?.player?.trackArtist ?? ""
        onClicked: Arch.panels.swap("media")

        QIconButton {
            icon: page.svc?.player?.isPlaying ? "pause" : "play_arrow"
            size: 30
            onClicked: page.svc.media("toggle")
        }
    }

    // Updates waiting
    QItem {
        Layout.fillWidth: true
        visible: (page.svc?.updateCount ?? 0) > 0 || (page.svc?.rebootNeeded ?? false)
        icon: page.svc?.rebootNeeded ? "restart_alt" : "system_update"
        title: page.svc?.rebootNeeded ? "Restart to finish updating" : page.svc.updateCount + " updates ready"
        active: true
        onClicked: Arch.panels.swap("updates")
    }

    // The rice (two columns, so three entries never squeeze)
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 2
        columnSpacing: 8

        QItem {
            Layout.fillWidth: true
            icon: "palette"
            title: "Change rice"
            onClicked: {
                Arch.panels.close();
                Arch.cmd(["theme", "pick"]);
            }
        }
        QItem {
            Layout.fillWidth: true
            visible: Arch.theme?.wearsStyles ?? false
            icon: "style"
            title: "Change style"
            onClicked: {
                Arch.panels.close();
                Arch.cmd(["style", "pick"]);
            }
        }
        QItem {
            Layout.fillWidth: true
            icon: "wallpaper"
            title: "Next wallpaper"
            onClicked: Arch.cmd(["wallpaper", "next"])
        }
    }
}
