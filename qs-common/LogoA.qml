// The A of the ARCHONATE logo, the same one fastfetch and the login screen show:
// the first 13 columns of lib/archonate/logo.txt less one column of the hole
// (a terminal's cells are 1.1x taller than wide, so fastfetch's A is narrower
// than square blocks make it), drawn as exact blocks. It is pixel art, so it
// stays sharp only at whole-pixel blocks: `cell` is the block size in pixels
// (1 = 12x16, 2 = 24x32), never a fraction. Two-tone like
// fastfetch's: the top five rows `color`, the rest `color2`.
import QtQuick
import Quickshell
import Quickshell.Io

Canvas {
    id: c

    property color color: "white"
    property color color2: color
    property int cell: 1
    property var rows: []

    implicitWidth: 12 * cell
    implicitHeight: 16 * cell
    onColorChanged: requestPaint()
    onColor2Changed: requestPaint()
    onCellChanged: requestPaint()
    onRowsChanged: requestPaint()

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/lib/archonate/logo.txt"
        blockLoading: true
        onLoaded: c.rows = text().split("\n").slice(0, 8).map(r => r.slice(0, 6) + r.slice(7, 13))
    }

    onPaint: {
        const g = getContext("2d");
        g.reset();
        const s = cell;
        for (let y = 0; y < rows.length; y++) {
            g.fillStyle = y < 5 ? color : color2;
            for (let x = 0; x < rows[y].length; x++) {
                const ch = rows[y][x];
                if (ch === "█")
                    g.fillRect(x * s, y * 2 * s, s, 2 * s);
                else if (ch === "▀")
                    g.fillRect(x * s, y * 2 * s, s, s);
                else if (ch === "▄")
                    g.fillRect(x * s, y * 2 * s + s, s, s);
            }
        }
    }
}
