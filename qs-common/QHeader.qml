// Panel title row: icon, title, and whatever you put on the right.
import QtQuick
import QtQuick.Layouts

RowLayout {
    id: h

    property string icon: ""
    property string title: ""
    default property alias extra: right.data

    spacing: 10

    Icon {
        visible: h.icon !== ""
        name: h.icon
        size: 20
        color: Arch.theme?.accent ?? "#fff"
    }
    QText {
        Layout.fillWidth: true
        text: Arch.caps(h.title)
        size: (Arch.theme?.fontSize ?? 13) + 3
        font.weight: Font.DemiBold
    }
    Row {
        id: right

        spacing: 8
    }
}
