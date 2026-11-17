// Wi-Fi through NetworkManager (nmcli), so saved networks work everywhere.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: page

    spacing: 12

    property bool radio: true
    property string device: ""
    property var networks: []   // [{ ssid, signal, secure, active, saved }]
    property var saved: []      // saved Wi-Fi connection names
    property var details: ({})  // IP of the current connection
    property string asking: ""  // SSID waiting for a password
    property string busy: ""    // SSID being connected to
    property string error: ""
    property bool scanning: false

    // nmcli -t escapes ':' inside fields as '\:'
    function fields(line: string): var {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            if (line[i] === "\\" && i + 1 < line.length) {
                cur += line[++i];
            } else if (line[i] === ":") {
                out.push(cur);
                cur = "";
            } else {
                cur += line[i];
            }
        }
        out.push(cur);
        return out;
    }

    function reload(): void {
        App.run(["nmcli", "-t", "-f", "WIFI", "general"], (c, out) => page.radio = out.trim() === "enabled");
        App.run(["nmcli", "-t", "-f", "NAME,TYPE,DEVICE", "connection", "show"], (c, out) => {
            const rows = out.trim().split("\n").map(page.fields).filter(r => r[1] === "802-11-wireless");
            page.saved = rows.map(r => r[0]);
            const live = rows.find(r => r[2]);
            page.device = live ? live[2] : (page.device || "wlan0");
            App.run(["nmcli", "-t", "-f", "IP4.ADDRESS,IP4.GATEWAY,IP4.DNS,GENERAL.CONNECTION", "device", "show", page.device], (c2, o2) => {
                const d = {};
                for (const l of o2.trim().split("\n")) {
                    const i = l.indexOf(":");
                    d[l.slice(0, i).replace(/\[\d+\]/, "")] = l.slice(i + 1);
                }
                page.details = d;
            });
            App.run(["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "device", "wifi", "list", "--rescan", "no"], (c3, o3) => {
                const best = {};
                for (const l of o3.trim().split("\n")) {
                    const [use, ssid, signal, sec] = page.fields(l);
                    if (!ssid)
                        continue;
                    const n = best[ssid] ?? { ssid: ssid, signal: 0, secure: sec !== "" && sec !== "--", active: false, saved: page.saved.includes(ssid) };
                    n.signal = Math.max(n.signal, parseInt(signal) || 0);
                    n.active = n.active || use === "*";
                    best[ssid] = n;
                }
                page.networks = Object.values(best).sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
                page.scanning = false;
            });
        });
    }

    function rescan(): void {
        scanning = true;
        App.run(["nmcli", "device", "wifi", "rescan"], () => reloadTimer.restart());
    }

    function connect(n: var, password: string): void {
        error = "";
        busy = n.ssid;
        const cmd = n.saved && password === "" ? ["nmcli", "connection", "up", "id", n.ssid] : password !== "" ? ["nmcli", "device", "wifi", "connect", n.ssid, "password", password] : ["nmcli", "device", "wifi", "connect", n.ssid];
        App.run(cmd, (code, out, err) => {
            busy = "";
            if (code !== 0) {
                // Wrong or missing password: ask (again)
                if (/secrets|password|802-1x|key-mgmt/i.test(err) && !n.saved) {
                    asking = n.ssid;
                    error = password !== "" ? "That password didn't work." : "";
                } else {
                    error = err.trim().replace(/^Error:\s*/, "") || "Couldn't connect.";
                }
            } else {
                asking = "";
            }
            page.reload();
        });
    }

    function icon(signal: int): string {
        return signal > 70 ? "signal_wifi_4_bar" : signal > 45 ? "network_wifi_3_bar" : signal > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar";
    }

    Component.onCompleted: reload()

    Timer {
        running: true
        repeat: true
        interval: 10000
        onTriggered: page.reload()
    }
    Timer {
        id: reloadTimer

        interval: 3500
        onTriggered: page.reload()
    }

    SHeading {
        text: "Wi-Fi"
    }

    SCard {
        SRow {
            label: "Wi-Fi"
            note: page.radio ? (page.details["GENERAL.CONNECTION"] ? "Connected to " + page.details["GENERAL.CONNECTION"] : "Not connected") : "Off"

            SToggle {
                checked: page.radio
                onToggled: App.run(["nmcli", "radio", "wifi", page.radio ? "off" : "on"], () => page.reload())
            }
        }
        GridLayout {
            visible: page.radio && (page.details["GENERAL.CONNECTION"] ?? "") !== ""
            columns: 2
            columnSpacing: 24
            rowSpacing: 4

            Repeater {
                model: [["IP address", "IP4.ADDRESS"], ["Router", "IP4.GATEWAY"], ["DNS", "IP4.DNS"]]

                SLabel {
                    required property var modelData
                    required property int index

                    Layout.row: index
                    Layout.column: 0
                    text: modelData[0]
                    color: App.dim
                    font.pixelSize: 13
                }
            }
            Repeater {
                model: ["IP4.ADDRESS", "IP4.GATEWAY", "IP4.DNS"]

                SLabel {
                    required property string modelData
                    required property int index

                    Layout.row: index
                    Layout.column: 1
                    text: page.details[modelData] ?? "—"
                    font.pixelSize: 13
                }
            }
        }
    }

    RowLayout {
        visible: page.radio
        Layout.fillWidth: true

        SSection {
            title: "Networks"
            Layout.fillWidth: true
        }
        SChip {
            text: page.scanning ? "Scanning…" : "Scan"
            onClicked: page.rescan()
        }
    }

    SLabel {
        visible: page.error !== ""
        Layout.fillWidth: true
        text: page.error
        color: App.danger
        wrapMode: Text.Wrap
    }

    Repeater {
        model: page.radio ? page.networks : []

        ColumnLayout {
            id: net

            required property var modelData

            Layout.fillWidth: true
            spacing: 6

            SListItem {
                icon: page.icon(net.modelData.signal)
                title: net.modelData.ssid
                subtitle: (net.modelData.active ? "Connected" : page.busy === net.modelData.ssid ? "Connecting…" : net.modelData.saved ? "Saved" : "") + (net.modelData.secure ? (net.modelData.active || net.modelData.saved || page.busy === net.modelData.ssid ? " · " : "") + "Secured" : "")
                active: net.modelData.active
                onClicked: {
                    if (net.modelData.active)
                        return;
                    if (net.modelData.secure && !net.modelData.saved) {
                        page.asking = page.asking === net.modelData.ssid ? "" : net.modelData.ssid;
                        page.error = "";
                    } else {
                        page.connect(net.modelData, "");
                    }
                }

                Text {
                    visible: net.modelData.secure
                    text: "lock"
                    font.family: "Material Symbols Rounded"
                    font.pixelSize: 16
                    color: App.dim
                }
                SChip {
                    visible: net.modelData.active
                    text: "Disconnect"
                    onClicked: App.run(["nmcli", "device", "disconnect", page.device], () => page.reload())
                }
                SChip {
                    visible: net.modelData.saved
                    text: "Forget"
                    danger: true
                    onClicked: App.run(["nmcli", "connection", "delete", "id", net.modelData.ssid], () => page.reload())
                }
            }

            // Password row for secured networks we haven't saved yet
            RowLayout {
                visible: page.asking === net.modelData.ssid
                Layout.leftMargin: 50
                spacing: 8

                SField {
                    id: pw

                    placeholder: "Password for " + net.modelData.ssid
                    echoMode: show.selected ? TextInput.Normal : TextInput.Password
                    onAccepted: page.connect(net.modelData, pw.text)
                    onVisibleChanged: if (visible) {
                        text = "";
                        focusInput();
                    }
                }
                SChip {
                    id: show

                    text: "Show"
                    onClicked: selected = !selected
                }
                SChip {
                    text: "Connect"
                    selected: true
                    onClicked: page.connect(net.modelData, pw.text)
                }
            }
        }
    }
}
