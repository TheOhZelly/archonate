// Icon + draggable track (0..1). The icon is clickable (e.g. mute).
import QtQuick

Item {
    id: s

    property string icon: ""
    property real value: 0
    property string label: ""
    signal moved(real v)
    signal iconClicked

    readonly property QtObject t: Arch.theme

    implicitWidth: 300
    implicitHeight: 36

    Icon {
        id: ic

        anchors.verticalCenter: parent.verticalCenter
        name: s.icon
        size: 20
        color: s.t?.text ?? "#fff"

        MouseArea {
            anchors.fill: parent
            anchors.margins: -6
            cursorShape: Qt.PointingHandCursor
            onClicked: s.iconClicked()
        }
    }

    Rectangle {
        id: track

        anchors.left: ic.right
        anchors.leftMargin: 12
        anchors.right: pct.left
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        height: 8
        radius: (s.t?.radius ?? 8) > 0 ? 4 : 0
        color: Qt.alpha(s.t?.text ?? "#fff", 0.12)

        Rectangle {
            width: Math.max(track.radius * 2, track.width * Math.max(0, Math.min(1, s.value)))
            height: parent.height
            radius: parent.radius
            color: s.t?.accent ?? "#888"
        }
        Rectangle {
            x: track.width * Math.max(0, Math.min(1, s.value)) - width / 2
            anchors.verticalCenter: parent.verticalCenter
            width: 16
            height: 16
            radius: (s.t?.radius ?? 8) > 0 ? 8 : 0
            color: s.t?.text ?? "#fff"
            visible: drag.containsMouse || drag.pressed
        }
        MouseArea {
            id: drag

            anchors.fill: parent
            anchors.margins: -10
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            function set(x: real): void {
                s.moved(Math.max(0, Math.min(1, (x - 10) / track.width)));
            }
            onPressed: m => set(m.x)
            onPositionChanged: m => {
                if (pressed)
                    set(m.x);
            }
            onWheel: w => s.moved(Math.max(0, Math.min(1, s.value + (w.angleDelta.y > 0 ? 0.05 : -0.05))))
        }
    }

    // Keyboard: arrows nudge 5%, Home/End go to the ends, Space/Enter = the icon (mute)
    QFocus {
        anchors.fill: undefined
        anchors.left: track.left
        anchors.right: track.right
        anchors.verticalCenter: parent.verticalCenter
        height: 22
        radius: 11
        onActivated: s.iconClicked()
        function nudge(d: real): void {
            s.moved(Math.max(0, Math.min(1, Math.round((s.value + d) * 100) / 100)));
        }
        Keys.onLeftPressed: nudge(-0.05)
        Keys.onRightPressed: nudge(0.05)
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Home)
                nudge(-1);
            else if (e.key === Qt.Key_End)
                nudge(1);
            else
                return;
            e.accepted = true;
        }
    }

    QText {
        id: pct

        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: 34
        horizontalAlignment: Text.AlignRight
        text: s.label !== "" ? s.label : Math.round(s.value * 100)
        dim: true
        size: (s.t?.fontSize ?? 13) - 1
    }
}
