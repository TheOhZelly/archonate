// Network: Wi-Fi on/off, nearby networks (saved ones connect in one click),
// or the wired link. Anything needing a password goes to Settings > Wi-Fi.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ColumnLayout {
    id: page

    readonly property var svc: Arch.services
    property bool radio: true
    property bool hasWifi: false
    property var nets: []
    property var saved: []
    property string busy: ""

    width: 344
    spacing: 8

    // nmcli -t escapes ':' inside a field as '\:'
    function fields(line: string): var {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length)
                cur += line[++i];
            else if (line[i] === ":") {
                out.push(cur);
                cur = "";
            } else
                cur += line[i];
        }
        out.push(cur);
        return out;
    }

    function reload(): void {
        sh.exec(["sh", "-c", "nmcli -t -f WIFI general; echo ---; nmcli -t -f TYPE device | grep -qx wifi && echo yes; echo ---; nmcli -t -f NAME,TYPE connection show; echo ---; nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no"]);
    }

    function connect(n: var): void {
        if (n.inUse)
            return;
        if (!n.saved && n.security !== "") {
            Arch.settings("wifi"); // needs a password
            return;
        }
        busy = n.ssid;
        Quickshell.execDetached(["sh", "-c", n.saved ? `nmcli connection up id '${n.ssid.replace(/'/g, "'\\''")}'` : `nmcli device wifi connect '${n.ssid.replace(/'/g, "'\\''")}'`]);
        settle.restart();
    }

    // Show what's known now, then look around and refresh
    Component.onCompleted: {
        reload();
        Quickshell.execDetached(["nmcli", "device", "wifi", "rescan"]);
        settle.restart();
    }

    Timer {
        id: settle

        interval: 4000
        onTriggered: {
            page.busy = "";
            page.reload();
        }
    }

    Process {
        id: sh

        stdout: StdioCollector {
            onStreamFinished: {
                const parts = text.split("---\n");
                page.radio = (parts[0] ?? "").trim() === "enabled";
                page.hasWifi = (parts[1] ?? "").trim() === "yes";
                page.saved = (parts[2] ?? "").trim().split("\n").map(l => page.fields(l)).filter(f => f[1] === "802-11-wireless").map(f => f[0]);
                const seen = {};
                page.nets = (parts[3] ?? "").trim().split("\n").filter(l => l).map(l => {
                    const f = page.fields(l);
                    return { inUse: f[0] === "*", ssid: f[1], signal: parseInt(f[2]) || 0, security: f[3] ?? "", saved: page.saved.includes(f[1]) };
                }).filter(n => n.ssid && !seen[n.ssid] && (seen[n.ssid] = true)).sort((a, b) => b.inUse - a.inUse || b.saved - a.saved || b.signal - a.signal).slice(0, 7);
            }
        }
    }

    QHeader {
        Layout.fillWidth: true
        icon: page.svc?.netIcon ?? "wifi"
        title: "Network"

        QToggle {
            visible: page.hasWifi
            checked: page.radio
            onToggled: {
                Quickshell.execDetached(["nmcli", "radio", "wifi", page.radio ? "off" : "on"]);
                page.radio = !page.radio;
                settle.restart();
            }
        }
    }

    QItem {
        Layout.fillWidth: true
        visible: !(page.svc?.netWifi ?? false) && page.svc?.netDevice !== null
        icon: "lan"
        title: "Wired"
        sub: "Connected"
        active: true
    }

    Repeater {
        model: page.radio ? page.nets : []

        QItem {
            required property var modelData

            Layout.fillWidth: true
            icon: modelData.signal > 66 ? "signal_wifi_4_bar" : modelData.signal > 33 ? "network_wifi_2_bar" : "network_wifi_1_bar"
            title: modelData.ssid
            sub: modelData.inUse ? "Connected" : modelData.saved ? "Saved" : modelData.security ? "Needs a password" : "Open"
            trailing: modelData.security ? "🔒" : ""
            active: modelData.inUse
            busy: page.busy === modelData.ssid
            onClicked: page.connect(modelData)
        }
    }

    QText {
        visible: page.hasWifi && page.radio && page.nets.length === 0
        text: "No networks found yet"
        dim: true
    }

    QLink {
        Layout.fillWidth: true
        text: page.hasWifi ? "Wi-Fi settings" : "Network settings"
        page: "wifi"
    }
}
