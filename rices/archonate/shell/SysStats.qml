// System numbers for the bar and the stats column, polled every 2 s by one
// small shell read of /proc and /sys (GPU via nvidia-smi when it exists,
// every 6 s). Keeps a short history for sparklines.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    property real cpu: 0 // 0..1
    property real mem: 0 // 0..1
    property real memUsedGiB: 0
    property real memTotalGiB: 0
    property real cpuTemp: 0 // °C, 0 = unknown
    property real gpu: -1 // 0..1, -1 = no reading
    property real gpuTemp: 0
    property real rxRate: 0 // bytes/s
    property real txRate: 0
    property real diskUsed: 0 // bytes
    property real diskTotal: 0
    property real uptime: 0 // s
    property var cpuHist: []
    property var netHist: []
    readonly property int histLen: 48

    property var prevCpu: null
    property var prevNet: null
    property real prevAt: 0

    function push(arr: var, v: real): var {
        const a = arr.slice(-(histLen - 1));
        a.push(v);
        return a;
    }

    function human(b: real): string {
        const u = ["B", "K", "M", "G", "T"];
        let i = 0;
        while (b >= 1024 && i < u.length - 1) {
            b /= 1024;
            i++;
        }
        return (b >= 100 || i === 0 ? Math.round(b) : b.toFixed(1)) + u[i];
    }

    function parse(text: string): void {
        const now = Date.now() / 1000;
        const dt = prevAt ? Math.max(0.5, now - prevAt) : 0;
        prevAt = now;
        for (const line of text.split("\n")) {
            const f = line.trim().split(/\s+/);
            switch (f[0]) {
            case "cpu":
                {
                    const n = f.slice(1).map(Number);
                    const idle = n[3] + (n[4] || 0);
                    const total = n.reduce((a, b) => a + b, 0);
                    if (prevCpu) {
                        const dT = total - prevCpu.total;
                        root.cpu = dT > 0 ? Math.max(0, 1 - (idle - prevCpu.idle) / dT) : 0;
                        root.cpuHist = push(root.cpuHist, root.cpu);
                    }
                    prevCpu = {
                        idle,
                        total
                    };
                    break;
                }
            case "mem":
                {
                    const total = Number(f[1]), avail = Number(f[2]);
                    root.memTotalGiB = total / 1048576;
                    root.memUsedGiB = (total - avail) / 1048576;
                    root.mem = total ? (total - avail) / total : 0;
                    break;
                }
            case "temp":
                root.cpuTemp = Number(f[1]) / 1000;
                break;
            case "net":
                {
                    const rx = Number(f[1]), tx = Number(f[2]);
                    if (prevNet && dt) {
                        root.rxRate = Math.max(0, (rx - prevNet.rx) / dt);
                        root.txRate = Math.max(0, (tx - prevNet.tx) / dt);
                        root.netHist = push(root.netHist, root.rxRate + root.txRate);
                    }
                    prevNet = {
                        rx,
                        tx
                    };
                    break;
                }
            case "disk":
                root.diskUsed = Number(f[1]);
                root.diskTotal = Number(f[2]);
                break;
            case "up":
                root.uptime = Number(f[1]);
                break;
            }
        }
    }

    Process {
        id: poll

        command: ["sh", "-c", `
            head -1 /proc/stat
            awk '/^MemTotal:/{t=$2} /^MemAvailable:/{a=$2} END{print "mem", t, a}' /proc/meminfo
            for h in /sys/class/hwmon/hwmon*; do
                case "$(cat "$h/name" 2>/dev/null)" in coretemp|k10temp|zenpower) echo temp "$(cat "$h/temp1_input")"; break;; esac
            done
            awk 'NR>2 && $1 != "lo:" {r+=$2; t+=$10} END{print "net", r, t}' /proc/net/dev
            df -B1 --output=used,size / | awk 'NR==2{print "disk", $1, $2}'
            awk '{print "up", $1}' /proc/uptime`]
        stdout: StdioCollector {
            onStreamFinished: root.parse(text)
        }
    }
    Timer {
        running: true
        repeat: true
        triggeredOnStart: true
        interval: 2000
        onTriggered: poll.running = true
    }

    // NVIDIA, when present
    property bool hasNvidia: false
    Process {
        running: true
        command: ["sh", "-c", "command -v nvidia-smi"]
        onExited: code => root.hasNvidia = code === 0
    }
    Process {
        id: gpuPoll

        command: ["nvidia-smi", "--query-gpu=utilization.gpu,temperature.gpu", "--format=csv,noheader,nounits"]
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.split("\n")[0].split(",").map(s => parseFloat(s));
                if (!isNaN(f[0])) {
                    root.gpu = f[0] / 100;
                    root.gpuTemp = f[1] || 0;
                }
            }
        }
    }
    Timer {
        running: root.hasNvidia
        repeat: true
        triggeredOnStart: true
        interval: 6000
        onTriggered: gpuPoll.running = true
    }
}
