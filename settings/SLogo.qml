// Block-character art (the Archonate logo) drawn as exact squares, so rows
// never gap or overlap the way text rendering does. █ fills a cell, ▀/▄ its
// top/bottom half. Scales to fit `width`.
import QtQuick

Canvas {
    id: c

    property string art: ""
    property color color: "white"
    readonly property var rows: art.replace(/\n+$/, "").split("\n")
    readonly property int cols: Math.max(1, ...rows.map(r => r.length))
    // Whole pixels, or anti-aliasing draws seams between the blocks
    readonly property int cell: Math.max(1, Math.floor(width / cols))

    implicitHeight: cell * 2 * rows.length
    onArtChanged: requestPaint()
    onColorChanged: requestPaint()
    onWidthChanged: requestPaint()

    onPaint: {
        const g = getContext("2d");
        g.reset();
        g.fillStyle = color;
        const s = cell, ox = Math.floor((width - s * cols) / 2);
        for (let y = 0; y < rows.length; y++)
            for (let x = 0; x < rows[y].length; x++) {
                const ch = rows[y][x];
                if (ch === "█")
                    g.fillRect(ox + x * s, y * 2 * s, s, 2 * s);
                else if (ch === "▀")
                    g.fillRect(ox + x * s, y * 2 * s, s, s);
                else if (ch === "▄")
                    g.fillRect(ox + x * s, y * 2 * s + s, s, s);
            }
    }
}
