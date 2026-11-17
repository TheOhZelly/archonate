// Text in the rice's font and colours. dim: secondary text.
import QtQuick

Text {
    property bool dim: false
    property real size: Arch.theme?.fontSize ?? 13

    color: dim ? (Arch.theme?.textDim ?? "#999") : (Arch.theme?.text ?? "#fff")
    font.family: Arch.theme?.font ?? "sans-serif"
    font.pixelSize: size
    font.letterSpacing: Math.min(1, (Arch.theme?.tracking ?? 0) * 0.3)
    elide: Text.ElideRight
    verticalAlignment: Text.AlignVCenter
}
