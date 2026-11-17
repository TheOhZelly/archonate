// Liquid Glass surface: a barely-there tint over the compositor blur, a soft
// sheen across the top, and a rim that catches light at the top-left and fades
// around the sides (brightening again faintly bottom-right, like a lens edge).
// Fill a parent with it and put content on top.
import QtQuick

Item {
    id: root

    property real radius: 26
    property color tint: "#ffffff"
    property real tintOpacity: 0.06
    property real rimStrength: 0.55

    // Tint
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        color: Qt.alpha(root.tint, root.tintOpacity)
    }

    // Sheen: light pooling in the upper part of the glass
    Rectangle {
        anchors.fill: parent
        radius: root.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: Qt.rgba(1, 1, 1, 0.13)
            }
            GradientStop {
                position: 0.42
                color: Qt.rgba(1, 1, 1, 0.025)
            }
            GradientStop {
                position: 1
                color: Qt.rgba(1, 1, 1, 0)
            }
        }
    }

    // Rim: gradient stroke, bright top-left, faint bottom-right
    Canvas {
        anchors.fill: parent
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()

        onPaint: {
            const ctx = getContext("2d");
            const w = width, h = height, r = Math.min(root.radius, w / 2, h / 2), s = root.rimStrength;
            ctx.reset();
            const g = ctx.createLinearGradient(0, 0, w, h);
            g.addColorStop(0, Qt.rgba(1, 1, 1, 0.9 * s));
            g.addColorStop(0.28, Qt.rgba(1, 1, 1, 0.22 * s));
            g.addColorStop(0.55, Qt.rgba(1, 1, 1, 0.06 * s));
            g.addColorStop(1, Qt.rgba(1, 1, 1, 0.35 * s));
            ctx.strokeStyle = g;
            ctx.lineWidth = 1.2;
            const x = 0.6, y = 0.6, ww = w - 1.2, hh = h - 1.2;
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + ww, y, x + ww, y + hh, r);
            ctx.arcTo(x + ww, y + hh, x, y + hh, r);
            ctx.arcTo(x, y + hh, x, y, r);
            ctx.arcTo(x, y, x + ww, y, r);
            ctx.closePath();
            ctx.stroke();
        }
    }
}
