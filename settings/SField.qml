import QtQuick

// Single-line text input
Rectangle {
    id: field

    property alias text: box.text
    property alias echoMode: box.echoMode
    property string placeholder
    property alias input: box
    signal accepted
    signal navUp // Up/Down in the box (the sidebar search uses them)
    signal navDown

    function focusInput(): void {
        box.forceActiveFocus();
    }

    implicitWidth: 260
    implicitHeight: 38
    radius: App.r(10)
    color: Qt.alpha(App.fg, 0.06)
    border.width: App.bw
    border.color: box.activeFocus ? App.accent : App.line

    TextInput {
        id: box

        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        verticalAlignment: TextInput.AlignVCenter
        color: App.fg
        font.family: App.font
        font.pixelSize: 14
        clip: true
        selectByMouse: true
        activeFocusOnTab: true
        Keys.onUpPressed: field.navUp()
        Keys.onDownPressed: field.navDown()
        onAccepted: field.accepted()

        SLabel {
            anchors.verticalCenter: parent.verticalCenter
            visible: box.text === ""
            text: field.placeholder
            color: App.dim
        }
    }
}
