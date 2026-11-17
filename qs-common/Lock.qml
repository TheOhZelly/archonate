// Lockscreen: Wayland session lock + PAM password check, styled by the rice.
// Locks on IPC (`lock`) and after `idleMinutes` of inactivity; turns the
// screens off after `screenOffMinutes` (any input wakes them).
// If this shell ever dies while locked, SUPER+ALT+L restarts it and relocks.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pam

Scope {
    id: root

    required property QtObject theme
    property int idleMinutes: 10
    property bool caffeine: false // Keep awake: no idle lock or screen-off
    property int screenOffMinutes: 15
    property bool previewing: false
    property string image: "" // current wallpaper (still or gif)

    property string buffer: ""
    property string message: ""
    readonly property bool busy: pam.active

    signal wasLocked
    signal wasUnlocked
    signal wrongPassword

    function lock(): void {
        buffer = "";
        message = "";
        lock.locked = true;
        root.wasLocked();
    }

    // Shows the lock design in a normal overlay for a few seconds (no real lock)
    function preview(): void {
        previewing = true;
        previewTimer.restart();
    }

    function submit(): void {
        if (pam.active || buffer === "")
            return;
        message = "";
        pam.start();
    }

    function handleKey(event: var): void {
        if (pam.active)
            return;
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter)
            submit();
        else if (event.key === Qt.Key_Escape)
            buffer = "";
        else if (event.key === Qt.Key_Backspace)
            buffer = (event.modifiers & Qt.ControlModifier) ? "" : buffer.slice(0, -1);
        else if (/^[^\x00-\x1F\x7F-\x9F]+$/.test(event.text))
            buffer += event.text;
    }

    PamContext {
        id: pam

        config: "passwd"
        configDirectory: Quickshell.shellPath("common/pam.d")

        onResponseRequiredChanged: {
            if (!responseRequired)
                return;
            respond(root.buffer);
            root.buffer = "";
        }

        onCompleted: res => {
            if (res === PamResult.Success) {
                lock.locked = false;
                root.message = "";
                root.wasUnlocked();
            } else if (res === PamResult.MaxTries) {
                root.message = "too many attempts";
            } else {
                root.message = root.theme.lockWrong;
                root.wrongPassword();
            }
        }
    }

    IdleMonitor {
        enabled: root.idleMinutes > 0 && !root.caffeine
        timeout: Math.max(1, root.idleMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: {
            if (isIdle)
                root.lock();
        }
    }

    IdleMonitor {
        enabled: root.screenOffMinutes > 0 && !root.caffeine
        timeout: Math.max(1, root.screenOffMinutes) * 60
        respectInhibitors: true
        onIsIdleChanged: Hyprland.dispatch(`hl.dsp.dpms({ action = "${isIdle ? "disable" : "enable"}" })`)
    }

    Timer {
        id: previewTimer

        interval: 6000
        onTriggered: root.previewing = false
    }

    SystemClock {
        id: clock

        precision: SystemClock.Seconds
    }

    component Content: Rectangle {
        color: root.theme.bg

        Image {
            anchors.fill: parent
            source: root.image ? "file://" + root.image : ""
            fillMode: Image.PreserveAspectCrop
            opacity: root.theme.lockImageOpacity
            asynchronous: true
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 14

            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.theme.caps(root.theme.lockTitle)
                color: root.theme.accent
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize + 2
                font.letterSpacing: root.theme.tracking * 2
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: Qt.formatDateTime(clock.date, root.theme.lockClock)
                color: root.theme.text
                font.family: root.theme.displayFont
                font.pixelSize: root.theme.lockClockSize
                font.weight: root.theme.lockClockWeight
                font.letterSpacing: root.theme.lockClockSize * (root.theme.displayTracking ?? 0)
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.theme.caps(Qt.formatDateTime(clock.date, root.theme.longDate))
                color: root.theme.textDim
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize + 1
                font.letterSpacing: root.theme.tracking
            }

            // Password field: dots only, never the text
            Rectangle {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 24
                implicitWidth: 320
                implicitHeight: 46
                radius: root.theme.radius
                color: root.theme.surface
                border.width: Math.max(1, root.theme.borderWidth)
                border.color: root.message !== "" ? root.theme.urgent : root.busy ? root.theme.textDim : root.theme.accent

                Text {
                    anchors.centerIn: parent
                    text: root.busy ? "…" : root.buffer.length > 0 ? root.theme.lockDot.repeat(Math.min(root.buffer.length, 24)) : root.theme.caps(root.theme.lockPrompt)
                    color: root.buffer.length > 0 ? root.theme.accent : root.theme.textDim
                    font.family: root.theme.font
                    font.pixelSize: root.theme.fontSize + 1
                    font.letterSpacing: root.buffer.length > 0 ? 4 : root.theme.tracking
                }
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                text: root.theme.caps(root.message)
                visible: root.message !== ""
                color: root.theme.urgent
                font.family: root.theme.font
                font.pixelSize: root.theme.fontSize
                font.letterSpacing: root.theme.tracking
            }
        }
    }

    WlSessionLock {
        id: lock

        WlSessionLockSurface {
            color: root.theme.bg

            Content {
                anchors.fill: parent
                focus: true
                Keys.onPressed: event => root.handleKey(event)
            }
        }
    }

    Variants {
        model: root.previewing ? Quickshell.screens : []

        PanelWindow {
            required property var modelData

            screen: modelData
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "rice-lock-preview"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }

            Content {
                anchors.fill: parent
            }
        }
    }
}
