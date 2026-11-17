// Footer link that leads on: "Sound settings  →". Opens Settings at `page`.
import QtQuick

Item {
    id: l

    property string text: ""
    property string page: ""
    property string icon: "arrow_forward"
    signal clicked

    implicitWidth: 300
    implicitHeight: 34

    Rectangle {
        anchors.fill: parent
        radius: Math.round((Arch.theme?.radius ?? 10) * 0.6)
        color: ma.containsMouse ? Qt.alpha(Arch.theme?.text ?? "#fff", 0.07) : "transparent"
    }
    QText {
        x: 8
        anchors.verticalCenter: parent.verticalCenter
        text: Arch.caps(l.text)
        color: Arch.theme?.accent ?? "#888"
        font.weight: Font.DemiBold
    }
    Icon {
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        name: l.icon
        size: 18
        color: Arch.theme?.accent ?? "#888"
    }
    QFocus {
        radius: Math.round((Arch.theme?.radius ?? 10) * 0.6)
        onActivated: {
            l.clicked();
            if (l.page !== "")
                Arch.settings(l.page);
        }
    }
    MouseArea {
        id: ma

        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
            l.clicked();
            if (l.page !== "")
                Arch.settings(l.page);
        }
    }
}
