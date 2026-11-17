// The audio spectrum, live from cava (cava.conf: 48 bars, 0..1 in `bars`).
// Runs only while `active`, so a silent or gaming desktop costs nothing.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property bool active: false
    readonly property int count: 48
    property var bars: flat()
    // Overall loudness 0..1, handy for glows
    readonly property real level: bars.reduce((a, b) => a + b, 0) / count

    function flat(): var {
        return new Array(count).fill(0);
    }

    onActiveChanged: if (!active)
        bars = flat()

    Process {
        running: root.active
        command: ["cava", "-p", Quickshell.shellPath("cava.conf")]
        stdout: SplitParser {
            onRead: data => {
                const v = data.split(";");
                const out = new Array(root.count);
                for (let i = 0; i < root.count; i++)
                    out[i] = Math.min(1, (parseInt(v[i]) || 0) / 100);
                root.bars = out;
            }
        }
    }
}
