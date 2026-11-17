// Shared state for one rice's desktop: audio sink, media player, network.
import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import Quickshell.Networking
import Quickshell.Io

Scope {
    id: root

    // Audio
    readonly property PwNode sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false
    readonly property string volumeIcon: muted ? "volume_off" : volume > 0.5 ? "volume_up" : volume > 0 ? "volume_down" : "volume_mute"

    function setVolume(v: real): void {
        if (sink?.audio) {
            sink.audio.muted = false;
            sink.audio.volume = Math.max(0, Math.min(1, v));
        }
    }

    function toggleMute(): void {
        if (sink?.audio)
            sink.audio.muted = !sink.audio.muted;
    }

    PwObjectTracker {
        objects: [root.sink]
    }

    // Media: prefer whatever is playing, else the first player
    readonly property MprisPlayer player: {
        const ps = Mpris.players.values;
        return ps.find(p => p.isPlaying) ?? ps[0] ?? null;
    }
    readonly property string nowPlaying: player ? [player.trackArtist, player.trackTitle].filter(s => s).join(" — ") : ""

    function media(cmd: string): void {
        if (!player)
            return;
        if (cmd === "toggle" && player.canTogglePlaying)
            player.togglePlaying();
        else if (cmd === "next" && player.canGoNext)
            player.next();
        else if (cmd === "prev" && player.canGoPrevious)
            player.previous();
        else if (cmd === "stop")
            player.stop();
    }

    // Network: first connected device
    readonly property var netDevice: Networking.devices.values.find(d => d.connected) ?? null
    readonly property bool netWifi: netDevice !== null && netDevice.type === DeviceType.Wifi
    readonly property string netName: {
        if (!netDevice)
            return "offline";
        if (netWifi) {
            const n = netDevice.networks.values.find(n => n.connected);
            return n ? n.name : "wifi";
        }
        return "wired";
    }
    readonly property string netIcon: !netDevice ? "signal_disconnected" : netWifi ? "wifi" : "lan"

    // Updates: checked shortly after login, then hourly. The bar shows a
    // badge, the updates panel lists them, `archonate update` installs.
    property var updates: ({ repo: [], aur: [], reboot: false, kernel: "" })
    readonly property int updateCount: (updates.repo?.length ?? 0) + (updates.aur?.length ?? 0)
    readonly property bool rebootNeeded: updates.reboot ?? false
    property bool checkingUpdates: false

    function checkUpdates(): void {
        if (updateProc.running)
            return;
        checkingUpdates = true;
        updateProc.running = true;
    }

    Process {
        id: updateProc

        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/lib/desktop.py", "updates"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.updates = JSON.parse(text);
                } catch (e) {}
                root.checkingUpdates = false;
            }
        }
        onExited: code => {
            if (code !== 0)
                root.checkingUpdates = false;
        }
    }

    Timer {
        running: true
        repeat: true
        interval: 60 * 60 * 1000
        triggeredOnStart: false
        onTriggered: root.checkUpdates()
    }
    Timer {
        running: true
        interval: 90 * 1000
        onTriggered: root.checkUpdates()
    }
}
