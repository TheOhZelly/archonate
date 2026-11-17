// Keyboard shortcuts: everything bound, grouped, searchable. Read from
// variables.lua (your keymap) plus the rice system's own keys.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    property var binds: []
    property string query: ""

    readonly property var shown: binds.filter(b => {
        const q = query.toLowerCase();
        return q === "" || b.label.toLowerCase().includes(q) || b.keys.join(" ").toLowerCase().includes(q) || b.group.toLowerCase().includes(q);
    })
    readonly property var groups: [...new Set(shown.map(b => b.group))]

    spacing: 12

    Component.onCompleted: App.run(["python3", App.py, "keybinds"], (c, out) => page.binds = JSON.parse(out))

    SHeading {
        text: "Keyboard shortcuts"
    }
    SField {
        Layout.fillWidth: true
        placeholder: "Search shortcuts, e.g. \"screenshot\" or \"SUPER + S\""
        onTextChanged: page.query = text
    }
    SNote {
        text: page.shown.length + " shortcuts. Change them in ~/.config/hypr/variables.lua."
    }

    Repeater {
        model: page.groups

        ColumnLayout {
            id: grp

            required property string modelData

            Layout.fillWidth: true
            spacing: 6

            SSection {
                title: grp.modelData
            }
            SCard {
                spacing: 4

                Repeater {
                    model: page.shown.filter(b => b.group === grp.modelData)

                    RowLayout {
                        id: bind

                        required property var modelData

                        Layout.fillWidth: true
                        spacing: 12

                        SLabel {
                            Layout.fillWidth: true
                            text: bind.modelData.label
                            elide: Text.ElideRight
                        }
                        // Each key combo as keycaps; alternatives separated by "or"
                        Repeater {
                            model: bind.modelData.keys

                            Row {
                                id: combo

                                required property string modelData
                                required property int index

                                spacing: 4

                                SLabel {
                                    visible: combo.index > 0
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "or"
                                    color: App.dim
                                    font.pixelSize: 12
                                    rightPadding: 4
                                }
                                Repeater {
                                    model: combo.modelData.split("+").map(k => k.trim())

                                    Rectangle {
                                        id: cap

                                        required property string modelData

                                        implicitWidth: capText.implicitWidth + 14
                                        implicitHeight: 26
                                        radius: App.r(6)
                                        color: Qt.alpha(App.fg, 0.08)
                                        border.width: App.bw
                                        border.color: App.line

                                        SLabel {
                                            id: capText

                                            anchors.centerIn: parent
                                            text: cap.modelData.replace("SUPER_L", "SUPER").replace("mouse:272", "Left click").replace("mouse:273", "Right click").replace("mouse_down", "Scroll down").replace("mouse_up", "Scroll up")
                                            font.pixelSize: 12
                                            font.weight: Font.DemiBold
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
