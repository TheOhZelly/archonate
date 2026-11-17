// Calendar: the date, a month you can page through (today marked), and a
// way into notifications and date & time settings.
import QtQuick
import QtQuick.Layouts
import Quickshell

ColumnLayout {
    id: page

    property date shown: new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
    readonly property int year: shown.getFullYear()
    readonly property int month: shown.getMonth()
    // Monday-first grid: leading days from last month, 6 weeks
    readonly property var cells: {
        const first = new Date(year, month, 1);
        const lead = (first.getDay() + 6) % 7;
        const out = [];
        for (let i = 0; i < 42; i++)
            out.push(new Date(year, month, 1 - lead + i));
        return out;
    }

    width: 320
    spacing: 10

    SystemClock {
        id: clock

        precision: SystemClock.Minutes
    }

    ColumnLayout {
        spacing: 0

        QText {
            text: Arch.caps(Qt.formatDateTime(clock.date, "dddd"))
            dim: true
        }
        QText {
            text: Arch.caps(Qt.formatDateTime(clock.date, "d MMMM yyyy"))
            size: (Arch.theme?.fontSize ?? 13) + 9
            font.family: Arch.theme?.displayFont ?? Arch.theme?.font ?? "sans-serif"
            font.weight: Font.DemiBold
        }
    }

    RowLayout {
        Layout.fillWidth: true

        QText {
            Layout.fillWidth: true
            text: Arch.caps(Qt.formatDate(page.shown, "MMMM yyyy"))
            font.weight: Font.DemiBold
        }
        QIconButton {
            icon: "chevron_left"
            size: 28
            onClicked: page.shown = new Date(page.year, page.month - 1, 1)
        }
        QIconButton {
            icon: "today"
            size: 28
            onClicked: page.shown = new Date(clock.date.getFullYear(), clock.date.getMonth(), 1)
        }
        QIconButton {
            icon: "chevron_right"
            size: 28
            onClicked: page.shown = new Date(page.year, page.month + 1, 1)
        }
    }

    GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: ["M", "T", "W", "T", "F", "S", "S"]

            QText {
                required property string modelData

                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: Arch.caps(modelData)
                dim: true
                size: (Arch.theme?.fontSize ?? 13) - 2
            }
        }
        Repeater {
            model: page.cells

            Rectangle {
                id: day

                required property date modelData
                readonly property bool today: modelData.toDateString() === clock.date.toDateString()
                readonly property bool inMonth: modelData.getMonth() === page.month

                Layout.fillWidth: true
                implicitHeight: 34
                radius: (Arch.theme?.radius ?? 8) > 0 ? 17 : 0
                color: today ? (Arch.theme?.accent ?? "#888") : "transparent"

                QText {
                    anchors.centerIn: parent
                    text: day.modelData.getDate()
                    color: day.today ? (Arch.theme?.bg ?? "#000") : day.inMonth ? (Arch.theme?.text ?? "#fff") : Qt.alpha(Arch.theme?.textDim ?? "#999", 0.5)
                    font.weight: day.today ? Font.Bold : Font.Normal
                }
            }
        }
    }

    QItem {
        Layout.fillWidth: true
        icon: Arch.toggles?.dnd ? "notifications_off" : "notifications"
        title: (Arch.notifs?.count ?? 0) > 0 ? Arch.notifs.count + " notifications" : "No notifications"
        sub: Arch.toggles?.dnd ? "Do not disturb is on" : ""
        onClicked: {
            Arch.panels.close();
            Arch.notifs.centerOpen = true;
        }

        QToggle {
            checked: Arch.toggles?.dnd ?? false
            onToggled: Arch.toggles.flip("dnd")
        }
    }

    QLink {
        Layout.fillWidth: true
        text: "Date & time settings"
        page: "time"
    }
}
