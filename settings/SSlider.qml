import QtQuick

// Horizontal slider, 0..1. Emits moved(value) while dragging and
// released(value) at the end (use that for slow backends).
Item {
    id: slider

    property real value: 0
    property real live: drag.pressed ? dragValue : value
    property real dragValue: 0
    signal moved(real v)
    signal released(real v)

    implicitWidth: 260
    implicitHeight: 24

    Rectangle {
        id: track

        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: 6
        radius: App.r(3)
        color: Qt.alpha(App.fg, 0.15)

        Rectangle {
            width: parent.width * Math.max(0, Math.min(1, slider.live))
            height: parent.height
            radius: App.r(3)
            color: App.accent
        }
    }
    Rectangle {
        x: (slider.width - width) * Math.max(0, Math.min(1, slider.live))
        anchors.verticalCenter: parent.verticalCenter
        width: 18
        height: 18
        radius: App.r(9)
        color: App.fg
        scale: drag.pressed ? 1.15 : 1
    }
    MouseArea {
        id: drag

        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        function at(x: real): real {
            return Math.max(0, Math.min(1, x / width));
        }
        onPressed: e => {
            slider.dragValue = at(e.x);
            slider.moved(slider.dragValue);
        }
        onPositionChanged: e => {
            if (pressed) {
                slider.dragValue = at(e.x);
                slider.moved(slider.dragValue);
            }
        }
        onReleased: slider.released(slider.dragValue)
    }
    SFocus {
        radius: App.r(12)
        function nudge(d: real): void {
            const v = Math.max(0, Math.min(1, Math.round((slider.value + d) * 100) / 100));
            slider.moved(v);
            slider.released(v);
        }
        Keys.onLeftPressed: nudge(-0.05)
        Keys.onRightPressed: nudge(0.05)
        Keys.onDownPressed: nudge(-0.05)
        Keys.onUpPressed: nudge(0.05)
        Keys.onPressed: e => {
            if (e.key === Qt.Key_Home)
                nudge(-1);
            else if (e.key === Qt.Key_End)
                nudge(1);
            else if (e.key === Qt.Key_PageUp)
                nudge(0.2);
            else if (e.key === Qt.Key_PageDown)
                nudge(-0.2);
            else
                return;
            e.accepted = true;
        }
    }
}
