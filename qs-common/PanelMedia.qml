// Now playing: cover, track, a seek bar and the controls.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets

ColumnLayout {
    id: page

    readonly property var svc: Arch.services
    readonly property var p: svc?.player ?? null

    width: 320
    spacing: 12

    // Position only updates when asked
    Timer {
        running: page.p?.isPlaying ?? false
        repeat: true
        interval: 1000
        onTriggered: page.p?.positionChanged()
    }

    function fmt(s: real): string {
        s = Math.max(0, Math.floor(s));
        return Math.floor(s / 60) + ":" + String(s % 60).padStart(2, "0");
    }

    QText {
        visible: !page.p
        text: "Nothing playing"
        dim: true
    }

    ClippingRectangle {
        Layout.fillWidth: true
        visible: page.p !== null
        implicitHeight: width
        radius: Math.round((Arch.theme?.radius ?? 10) * 0.8)
        color: Qt.alpha(Arch.theme?.text ?? "#fff", 0.06)

        Image {
            anchors.fill: parent
            source: page.p?.trackArtUrl ?? ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
        }
        Icon {
            anchors.centerIn: parent
            visible: !(page.p?.trackArtUrl)
            name: "album"
            size: 64
            color: Arch.theme?.textDim ?? "#999"
        }
    }

    ColumnLayout {
        Layout.fillWidth: true
        visible: page.p !== null
        spacing: 0

        QText {
            Layout.fillWidth: true
            text: page.p?.trackTitle ?? ""
            size: (Arch.theme?.fontSize ?? 13) + 3
            font.weight: Font.DemiBold
        }
        QText {
            Layout.fillWidth: true
            text: [page.p?.trackArtist, page.p?.trackAlbum].filter(s => s).join("  ·  ")
            dim: true
        }
    }

    QSlider {
        Layout.fillWidth: true
        visible: page.p !== null && (page.p?.lengthSupported ?? false)
        icon: "schedule"
        value: (page.p?.length ?? 0) > 0 ? page.p.position / page.p.length : 0
        label: page.fmt(page.p?.position ?? 0)
        onMoved: v => {
            if (page.p?.canSeek)
                page.p.position = v * page.p.length;
        }
    }

    Row {
        Layout.alignment: Qt.AlignHCenter
        visible: page.p !== null
        spacing: 18

        QIconButton {
            icon: "skip_previous"
            onClicked: page.svc.media("prev")
        }
        QIconButton {
            icon: page.p?.isPlaying ? "pause" : "play_arrow"
            accent: true
            size: 52
            onClicked: page.svc.media("toggle")
        }
        QIconButton {
            icon: "skip_next"
            onClicked: page.svc.media("next")
        }
    }

    QLink {
        Layout.fillWidth: true
        visible: page.p !== null
        text: "Open " + (page.p?.identity ?? "player")
        icon: "open_in_new"
        onClicked: {
            Arch.panels.close();
            if (page.p?.canRaise)
                page.p.raise();
        }
    }
}
