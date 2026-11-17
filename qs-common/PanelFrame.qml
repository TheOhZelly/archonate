// The card a quick panel sits in, styled from the rice: glass for cupertino,
// sharp frames for mono, chunky borders for ashen...
import QtQuick

Rectangle {
    id: frame

    readonly property QtObject t: Arch.theme
    readonly property bool liquid: t?.glass ?? false
    readonly property int pad: Math.max(14, t?.pad ?? 16)
    default property alias content: inner.data

    width: inner.childrenRect.width + pad * 2
    height: inner.childrenRect.height + pad * 2
    radius: liquid ? 24 : Math.round((t?.radius ?? 12) * 1.15)
    color: liquid ? "transparent" : Qt.alpha(t?.bg ?? "#000000", Math.max(0.97, t?.panelAlpha ?? 0.97))
    border.width: liquid ? 0 : Math.max(1, t?.borderWidth ?? 1)
    border.color: t?.border ?? "#40ffffff"
    clip: false

    LiquidGlass {
        anchors.fill: parent
        visible: frame.liquid
        radius: frame.radius
        tint: frame.t?.bg ?? "#000000"
        tintOpacity: 0.55
        rimStrength: 0.8
    }

    Item {
        id: inner

        x: frame.pad
        y: frame.pad
    }
}
