// One notification card (popups and the sidebar). See Notifs.qml.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Notifications

Rectangle {
    id: card

    required property var host // Notifs.qml

    required property var notif
    property bool popup: false
    readonly property bool selected: host.kbdSel === notif
    readonly property bool critical: notif.urgency === NotificationUrgency.Critical
    readonly property string code: host.codeOf(notif)
    readonly property var btns: host.buttons(notif)
    // Glass rices: popups are translucent material; cards inside the glass
    // sidebar stay solid so translucency never stacks on translucency
    readonly property bool glass: (host.theme.glass ?? false) && popup

    width: host.theme.notifWidth
    implicitHeight: col.implicitHeight + 2 * host.theme.pad
    radius: glass ? 22 : host.theme.radius
    color: glass ? "transparent" : host.theme.surface
    border.width: selected ? Math.max(2, host.theme.borderWidth) : glass && !critical ? 0 : host.theme.borderWidth
    border.color: selected ? host.theme.accent : critical ? host.theme.urgent : host.theme.border

    LiquidGlass {
        anchors.fill: parent
        visible: card.glass
        radius: card.radius
        tint: host.theme.bg
        tintOpacity: 0.42
        rimStrength: 0.75
    }

    HoverHandler {
        id: cardHover
    }

    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
        cursorShape: host.defaultAction(card.notif) ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: event => {
            if (event.button === Qt.LeftButton)
                host.click(card.notif);
            else
                host.dismiss(card.notif);
        }
    }

    ColumnLayout {
        id: col

        anchors.fill: parent
        anchors.margins: host.theme.pad
        spacing: 4

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                Layout.fillWidth: true
                text: host.theme.caps(card.notif.appName || "notification")
                color: host.theme.accent
                font.family: host.theme.font
                font.pixelSize: host.theme.fontSize - 2
                font.letterSpacing: host.theme.tracking
                elide: Text.ElideRight
            }
            Text {
                text: host.ago(card.notif)
                color: host.theme.textDim
                font.family: host.theme.font
                font.pixelSize: host.theme.fontSize - 3
                visible: !closeX.visible
            }
            Icon {
                id: closeX

                visible: cardHover.hovered || card.selected
                name: "close"
                size: 15
                color: host.theme.textDim

                MouseArea {
                    anchors.fill: parent
                    anchors.margins: -5
                    cursorShape: Qt.PointingHandCursor
                    onClicked: host.dismiss(card.notif)
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: card.notif.summary
            color: host.theme.text
            font.family: host.theme.font
            font.pixelSize: host.theme.fontSize + 1
            font.weight: Font.DemiBold
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
        }
        Text {
            Layout.fillWidth: true
            visible: text !== ""
            text: card.notif.body
            textFormat: Text.StyledText
            color: card.glass ? Qt.alpha(host.theme.text, 0.82) : host.theme.textDim
            font.family: host.theme.font
            font.pixelSize: host.theme.fontSize
            wrapMode: Text.Wrap
            maximumLineCount: card.popup ? 4 : 8
            elide: Text.ElideRight
            linkColor: host.theme.accent
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
        Flow {
            Layout.fillWidth: true
            Layout.topMargin: 2
            visible: card.code !== "" || card.btns.length > 0
            spacing: 6

            // Copy code (C in keyboard mode)
            Rectangle {
                id: codeChip

                property bool done: false

                visible: card.code !== ""
                implicitWidth: codeLabel.implicitWidth + 18
                implicitHeight: codeLabel.implicitHeight + 10
                radius: host.theme.radius / 2
                color: Qt.alpha(host.theme.accent, done ? 0.4 : 0.22)
                border.width: 1
                border.color: Qt.alpha(host.theme.accent, 0.6)

                Text {
                    id: codeLabel

                    anchors.centerIn: parent
                    text: (card.selected ? "C  " : "") + (codeChip.done ? "Copied" : "Copy code  " + card.code)
                    color: host.theme.text
                    font.family: host.theme.font
                    font.pixelSize: host.theme.fontSize - 1
                    font.weight: Font.DemiBold
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        host.copyCode(card.code);
                        codeChip.done = true;
                    }
                }
            }

            Repeater {
                model: card.btns

                Rectangle {
                    id: action

                    required property var modelData
                    required property int index

                    implicitWidth: label.implicitWidth + 16
                    implicitHeight: label.implicitHeight + 10
                    radius: host.theme.radius / 2
                    color: host.theme.surfaceHi

                    Text {
                        id: label

                        anchors.centerIn: parent
                        text: (card.selected && action.index < 9 ? (action.index + 1) + "  " : "") + action.modelData.text
                        color: host.theme.text
                        font.family: host.theme.font
                        font.pixelSize: host.theme.fontSize - 1
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            action.modelData.invoke();
                            if (!card.notif.resident)
                                host.dismiss(card.notif);
                        }
                    }
                }
            }
        }
    }
}
