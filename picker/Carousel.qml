// The style carousel: the selected style as a large slanted card, its
// neighbours as thin slanted slices fanned out either side, dimmed. Each shows
// the style's preview (a screenshot of the desktop in it, else its wallpaper).
// The picker drives it: `items` is the (filtered) list, `index` the selection.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Shapes

Item {
    id: car

    property var items: []
    property int index: 0
    property string current: ""
    property color dim: "#101010"

    // the selected card and the slices; the skew slants every edge the same way
    readonly property real cardW: Math.round(Math.min(820, parent.width * 0.46))
    readonly property real cardH: Math.round(cardW * 0.62)
    readonly property real sliceW: Math.round(cardW * 0.135)
    readonly property real sliceH: Math.round(cardH * 0.9)
    readonly property real overlap: Math.round(sliceW * 0.28)
    readonly property real skew: Math.round(cardH * 0.06)
    readonly property real step: sliceW - overlap
    // how many slices fit each side (plus one sliding in)
    readonly property int reach: Math.max(1, Math.ceil((width - cardW) / 2 / step) + 1)

    signal picked(int i)
    signal chosen(int i)

    implicitHeight: cardH

    Repeater {
        model: car.items

        Item {
            id: card

            required property var modelData
            required property int index
            readonly property int rel: index - car.index
            readonly property bool sel: rel === 0
            // the card shows the whole desktop in the style; the slices just its wallpaper
            readonly property string src: (sel ? modelData.thumbShot || modelData.shot || modelData.thumbWall || modelData.wallpaper : modelData.thumbWall || modelData.wallpaper || modelData.thumbShot || modelData.shot) || ""

            visible: Math.abs(rel) <= car.reach
            width: sel ? car.cardW : car.sliceW
            height: sel ? car.cardH : car.sliceH
            y: (car.cardH - height) / 2
            x: {
                const c = (car.width - car.cardW) / 2;
                if (sel)
                    return c;
                // each slice tucks `overlap` under the one nearer the card
                return rel < 0 ? c + car.overlap - car.sliceW + (rel + 1) * car.step : c + car.cardW - car.overlap + (rel - 1) * car.step;
            }
            z: sel ? 100 : 50 - Math.abs(rel)
            Behavior on x { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }
            Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.OutCubic } }

            // the slanted outline, shared by the mask and the border
            readonly property real k: car.skew

            Item {
                id: mask

                anchors.fill: parent
                visible: false
                layer.enabled: true

                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        fillColor: "white"
                        strokeColor: "transparent"
                        startX: card.k; startY: 0
                        PathLine { x: card.width; y: 0 }
                        PathLine { x: card.width - card.k; y: card.height }
                        PathLine { x: 0; y: card.height }
                        PathLine { x: card.k; y: 0 }
                    }
                }
            }

            Item {
                anchors.fill: parent
                layer.enabled: true
                layer.smooth: true
                layer.effect: MultiEffect {
                    maskEnabled: true
                    maskSource: mask
                    maskThresholdMin: 0.3
                    maskSpreadAtMin: 0.3
                }

                Rectangle {
                    anchors.fill: parent
                    color: "#" + (card.modelData.bg || "101010")
                }
                Image {
                    anchors.fill: parent
                    source: card.src ? "file://" + card.src : ""
                    sourceSize.width: car.cardW
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    smooth: true
                    // small cached copies (desktop.py thumbs): they decode at once,
                    // so no fade-in, the picker opens complete
                    opacity: status === Image.Ready ? 1 : 0
                }
                Rectangle {
                    anchors.fill: parent
                    color: car.dim
                    opacity: card.sel ? 0 : 0.45
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }
            }

            Shape {
                anchors.fill: parent
                preferredRendererType: Shape.CurveRenderer
                ShapePath {
                    fillColor: "transparent"
                    strokeColor: card.sel ? "#" + card.modelData.accent : Qt.rgba(1, 1, 1, 0.18)
                    strokeWidth: card.sel ? 3 : 1
                    startX: card.k; startY: 0
                    PathLine { x: card.width; y: 0 }
                    PathLine { x: card.width - card.k; y: card.height }
                    PathLine { x: 0; y: card.height }
                    PathLine { x: card.k; y: 0 }
                }
            }

            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: card.sel ? car.chosen(card.index) : car.picked(card.index)
            }
        }
    }
}
