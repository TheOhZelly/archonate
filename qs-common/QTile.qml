// Quick-settings tile: icon + label (+ sublabel). Lit when on. Click flips it;
// the chevron (when `more` is set) opens a deeper panel or page instead.
import QtQuick

Rectangle {
    id: tile

    property string icon: ""
    property string label: ""
    property string sub: ""
    property bool on: false
    property bool more: false
    signal clicked
    signal moreClicked

    readonly property QtObject t: Arch.theme

    implicitWidth: 150
    implicitHeight: 56
    radius: Math.round((t?.radius ?? 10) * 0.8)
    color: on ? Qt.alpha(t?.accent ?? "#888", 0.9) : hover.containsMouse ? Qt.alpha(t?.text ?? "#fff", 0.1) : Qt.alpha(t?.text ?? "#fff", 0.06)
    border.width: (t?.borderWidth ?? 1) > 2 ? 2 : 0
    border.color: Qt.alpha(t?.accent ?? "#888", 0.6)
    scale: hover.pressed ? 0.97 : 1
    Behavior on color { ColorAnimation { duration: 140 } }
    Behavior on scale { NumberAnimation { duration: 90 } }

    MouseArea {
        id: hover

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: tile.clicked()
    }

    Row {
        anchors.verticalCenter: parent.verticalCenter
        x: 12
        spacing: 10

        Icon {
            anchors.verticalCenter: parent.verticalCenter
            name: tile.icon
            size: 20
            fill: tile.on
            color: tile.on ? (tile.t?.bg ?? "#000") : (tile.t?.text ?? "#fff")
        }
        Column {
            anchors.verticalCenter: parent.verticalCenter
            width: tile.width - 54 - (tile.more ? 22 : 0)

            QText {
                width: parent.width
                text: Arch.caps(tile.label)
                color: tile.on ? (tile.t?.bg ?? "#000") : (tile.t?.text ?? "#fff")
                font.weight: Font.DemiBold
                size: (tile.t?.fontSize ?? 13) - 1
            }
            QText {
                width: parent.width
                visible: tile.sub !== ""
                text: tile.sub
                color: tile.on ? Qt.alpha(tile.t?.bg ?? "#000", 0.75) : (tile.t?.textDim ?? "#999")
                size: (tile.t?.fontSize ?? 13) - 2
            }
        }
    }

    // Enter flips it; Right opens the deeper panel
    QFocus {
        onActivated: tile.clicked()
        Keys.onRightPressed: e => {
            if (tile.more)
                tile.moreClicked();
            else
                e.accepted = false;
        }
    }

    Icon {
        visible: tile.more
        anchors.right: parent.right
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        name: "chevron_right"
        size: 18
        color: tile.on ? (tile.t?.bg ?? "#000") : (tile.t?.textDim ?? "#999")

        MouseArea {
            anchors.fill: parent
            anchors.margins: -8
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.moreClicked()
        }
    }
}
