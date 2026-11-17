// Screensaver: the ARCHONATE logo, broken into its half-block pixels and run
// through effects in this rice's colours, like omarchy's tte screensaver:
// rain, decrypt, beams, swarm, slide, bloom. Each assembles the logo, lets a
// colour wave run through it, then dissolves into the next. One per screen.
// Starts after `minutes` idle (or `archonate screensaver`); any key, click,
// scroll or mouse movement ends it.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    required property QtObject theme
    property bool enabled: true
    property int minutes: 5
    property bool active: false

    // The logo as pixels: {x, y} in half-cell units
    property var pixels: []
    property int cols: 1
    property int prows: 1

    // Palette gradient: accent -> secondary -> tertiary, plus a bright "head"
    readonly property var stops: [theme.pal?.c("accent") ?? theme.accent, theme.pal?.c("secondary") ?? theme.text, theme.pal?.c("tertiary") ?? theme.accent]
    readonly property color hot: theme.text

    readonly property var effects: ["rain", "decrypt", "beams", "swarm", "slide", "bloom"]
    property string effect: "rain"
    property real started: 0 // ms, effect start

    function start(): void {
        if (active || pixels.length === 0)
            return;
        pick();
        active = true;
    }

    function stop(): void {
        active = false;
    }

    function pick(): void {
        let e;
        do
            e = effects[Math.floor(Math.random() * effects.length)];
        while (e === effect && effects.length > 1);
        effect = e;
        started = Date.now();
        seed = Math.random() * 1000;
    }
    property real seed: 0

    FileView {
        path: Quickshell.env("HOME") + "/.config/hypr/lib/archonate/logo.txt"
        onLoaded: {
            const rows = text().replace(/\n+$/, "").split("\n");
            const px = [];
            let cols = 0;
            for (let y = 0; y < rows.length; y++) {
                cols = Math.max(cols, rows[y].length);
                for (let x = 0; x < rows[y].length; x++) {
                    const ch = rows[y][x];
                    if (ch === "█" || ch === "▀")
                        px.push({ x: x, y: y * 2 });
                    if (ch === "█" || ch === "▄")
                        px.push({ x: x, y: y * 2 + 1 });
                }
            }
            root.cols = cols;
            root.prows = rows.length * 2;
            root.pixels = px;
        }
    }

    IdleMonitor {
        enabled: root.enabled && root.minutes > 0
        timeout: Math.max(1, root.minutes) * 60
        respectInhibitors: true
        onIsIdleChanged: isIdle ? root.start() : root.stop()
    }

    Variants {
        model: root.active ? Quickshell.screens : []

        PanelWindow {
            id: win

            required property var modelData

            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "archonate-screensaver"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: root.theme.bg

            // Any input ends it; ignore the pointer "arriving" as it appears
            property real born: Date.now()
            property point first: Qt.point(-1, -1)
            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.BlankCursor
                acceptedButtons: Qt.AllButtons
                onPressed: root.stop()
                onWheel: root.stop()
                onPositionChanged: m => {
                    if (Date.now() - win.born < 700) {
                        win.first = Qt.point(m.x, m.y);
                        return;
                    }
                    if (win.first.x < 0)
                        win.first = Qt.point(m.x, m.y);
                    else if (Math.abs(m.x - win.first.x) + Math.abs(m.y - win.first.y) > 12)
                        root.stop();
                }
            }
            Item {
                anchors.fill: parent
                focus: true
                Keys.onPressed: root.stop()
            }

            Canvas {
                id: cv

                anchors.fill: parent
                renderTarget: Canvas.FramebufferObject

                readonly property int s: Math.max(2, Math.floor(width * 0.62 / root.cols))
                readonly property real ox: Math.round((width - s * root.cols) / 2)
                readonly property real oy: Math.round((height - s * (root.prows - 2)) / 2)

                // timings (s): assemble, shimmer, dissolve
                readonly property real tIn: 3.6
                readonly property real tHold: 4.5
                readonly property real tOut: 1.1

                function clamp(v: real): real {
                    return v < 0 ? 0 : v > 1 ? 1 : v;
                }
                function ease(v: real): real {
                    v = clamp(v);
                    return 1 - Math.pow(1 - v, 3);
                }
                // stable per-pixel random in [0,1)
                function rnd(i: int, k: int): real {
                    const v = Math.sin((i + 1) * 12.9898 + k * 78.233 + root.seed) * 43758.5453;
                    return v - Math.floor(v);
                }
                function mix(a: color, b: color, t: real): string {
                    t = clamp(t);
                    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1).toString();
                }
                function grad(u: real): string {
                    u = u - Math.floor(u);
                    const st = root.stops, n = st.length;
                    // loop the gradient so the wave wraps smoothly
                    const f = u * n, i = Math.floor(f) % n;
                    return mix(st[i], st[(i + 1) % n], f - Math.floor(f));
                }

                onPaint: {
                    const g = getContext("2d");
                    g.clearRect(0, 0, width, height);
                    const t = (Date.now() - root.started) / 1000;
                    const P = root.pixels, s = cv.s, W = width, H = height;
                    const total = tIn + tHold + tOut;
                    if (t > total) {
                        root.pick();
                        return;
                    }
                    const hold = t > tIn ? t - tIn : 0;
                    const out = t > tIn + tHold ? (t - tIn - tHold) / tOut : 0;
                    const e = root.effect;
                    for (let i = 0; i < P.length; i++) {
                        const p = P[i];
                        const u = p.x / root.cols, tx = ox + p.x * s, ty = oy + p.y * s;
                        let x = tx, y = ty, a = 1, heat = 0; // heat 1 = bright head colour
                        if (e === "rain") {
                            const k = ease((t - rnd(i, 1) * 1.6 - u * 0.8) / 1.0);
                            y = ty - (1 - k) * (ty + s * 4 + rnd(i, 2) * H * 0.3);
                            a = k > 0 ? 1 : 0;
                            heat = 1 - k;
                        } else if (e === "decrypt") {
                            const on = t - rnd(i, 1) * 1.4, settle = 1.6 + rnd(i, 2) * 1.6;
                            a = on > 0 ? 1 : 0;
                            if (t < settle) {
                                heat = 0.5 + 0.5 * Math.sin(t * 40 + i);
                                a *= 0.35 + 0.65 * rnd(i, Math.floor(t * 14));
                            }
                        } else if (e === "beams") {
                            const row = p.y, fromLeft = row % 2 === 0;
                            const head = (t - row * 0.09) * W * 0.55;
                            const d = (fromLeft ? head - (tx - ox + 0) : head - (ox + s * root.cols - tx));
                            a = d > 0 ? 1 : 0;
                            heat = d > 0 ? Math.max(0, 1 - d / (W * 0.18)) : 0;
                        } else if (e === "swarm") {
                            const k = ease((t - rnd(i, 3) * 0.9) / 2.4);
                            const sx = rnd(i, 1) * W, sy = rnd(i, 2) * H;
                            const wob = (1 - k) * 40 * Math.sin(t * 3 + i);
                            x = sx + (tx - sx) * k + wob;
                            y = sy + (ty - sy) * k + wob * 0.6;
                            heat = (1 - k) * 0.7;
                        } else if (e === "slide") {
                            const k = ease((t - p.y * 0.07 - rnd(i, 1) * 0.15) / 1.4);
                            x = tx + (p.y % 2 === 0 ? -1 : 1) * (1 - k) * W;
                            heat = (1 - k) * 0.8;
                        } else if (e === "bloom") {
                            const cx = ox + s * root.cols / 2, cy = oy + s * root.prows / 2;
                            const dist = Math.hypot(tx - cx, ty - cy) / (s * root.cols / 2);
                            const k = ease((t - dist * 1.6) / 1.1);
                            x = cx + (tx - cx) * k;
                            y = cy + (ty - cy) * k;
                            a = k > 0.02 ? 1 : 0;
                            heat = 1 - k;
                        }
                        // The colour wave once it's assembled
                        let c = grad(u * 0.9 + hold * 0.12 + p.y * 0.006);
                        if (heat > 0)
                            c = mix(c, root.hot, heat);
                        // Dissolve: pixels drift and fade in a random order
                        if (out > 0) {
                            const k = clamp((out - rnd(i, 5) * 0.6) / 0.4);
                            a *= 1 - k;
                            y += k * s * 6 * (rnd(i, 6) - 0.3);
                            x += k * s * 6 * (rnd(i, 7) - 0.5);
                        }
                        if (a <= 0)
                            continue;
                        g.globalAlpha = a;
                        g.fillStyle = c;
                        g.fillRect(Math.round(x), Math.round(y), s, s);
                    }
                    g.globalAlpha = 1;
                }

                // 60 fps is plenty, and cheap while you're away
                Timer {
                    running: root.active
                    repeat: true
                    interval: 16
                    onTriggered: cv.requestPaint()
                }
            }
        }
    }
}
