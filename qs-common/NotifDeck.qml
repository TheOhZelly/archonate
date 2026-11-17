// One app's notifications stacked into a deck; fans out on hover (popups),
// keyboard selection, or when expanded (sidebar). See Notifs.qml.
pragma ComponentBehavior: Bound

import QtQuick

Item {
    id: deck

    required property var host // Notifs.qml

    required property var items // newest first
    property bool inCenter: false
    property bool expanded: false
    readonly property bool fanned: items.length < 2 || expanded || (!inCenter && hover.hovered) || (host.kbd && items.includes(host.kbdSel))
    readonly property int peeks: Math.min(2, items.length - 1)

    width: host.theme.notifWidth
    implicitHeight: fanned ? fan.implicitHeight : top.implicitHeight + peeks * 7

    HoverHandler {
        id: hover
    }

    // The stack: cards peeking out underneath the newest
    Repeater {
        model: deck.fanned ? 0 : deck.peeks

        Rectangle {
            required property int index

            z: -1 - index
            x: (index + 1) * 8
            y: top.height - host.theme.radius - 4 + (index + 1) * 7
            width: deck.width - 2 * (index + 1) * 8
            height: host.theme.radius + 8
            radius: host.theme.radius
            color: Qt.darker(host.theme.surface, 1.08 + index * 0.08)
            border.width: host.theme.borderWidth
            border.color: host.theme.border
            opacity: 0.95 - index * 0.2
        }
    }
    NotifCard {
        id: top

        host: deck.host
        visible: !deck.fanned
        notif: deck.items[0]
        popup: !deck.inCenter

        // "+3" badge
        Rectangle {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: -6
            visible: deck.items.length > 1
            width: Math.max(22, badge.implicitWidth + 10)
            height: 22
            radius: 11
            color: host.theme.accent

            Text {
                id: badge

                anchors.centerIn: parent
                text: "+" + (deck.items.length - 1)
                color: host.theme.bg
                font.family: host.theme.font
                font.pixelSize: 11
                font.weight: Font.Bold
            }
        }
    }
    Column {
        id: fan

        visible: deck.fanned
        spacing: host.theme.gap / 3

        Repeater {
            model: deck.fanned ? deck.items : []

            NotifCard {
                required property var modelData

                host: deck.host
                notif: modelData
                popup: !deck.inCenter
            }
        }
    }
}
