// One rice's whole desktop: wallpaper, bar (per rice), notifications + center,
// volume OSD, lockscreen, and the IPC that the Hyprland keybinds call:
//   qs -p <shell dir> ipc call rice <lock|toggleCenter|clearNotifs|media X|setMode M|
//                                   nextWallpaper|prevWallpaper|setWidgets B|previewLock>
//
// The rice passes `bar`, a Component whose root takes `required property var
// modelData` (the screen); it can reach `services`/`notifs` through the
// Desktop's id in the rice's shell.qml.
import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root

    required property QtObject theme
    required property Component bar

    // Active mode: gaming/minimal pause live wallpapers, gaming hides bars over fullscreen
    property string mode: "normal"
    readonly property bool gaming: mode === "gaming"
    readonly property Services services: svc
    readonly property Notifs notifs: notifCenter
    readonly property Toggles toggles: tog
    readonly property Settings cfg: cfg
    readonly property Panels panels: quick

    // This rice's sounds (assets/sounds/<event>.oga, made by
    // lib/archonate/make-sounds.py). "rice:<event>" names one of them.
    readonly property string soundDir: Quickshell.shellPath("../assets/sounds/")
    function soundPath(s: string): string {
        return s.startsWith("rice:") ? soundDir + s.slice(5) + ".oga" : s;
    }
    readonly property bool uiSounds: cfg.globalVal("uiSounds", true)
    function sfx(event: string): void {
        if (uiSounds)
            Quickshell.execDetached(["pw-play", soundDir + event + ".oga"]);
    }

    // Share the handles with every bar and panel (see Arch.qml)
    Component.onCompleted: {
        Arch.theme = root.theme;
        Arch.services = svc;
        Arch.toggles = tog;
        Arch.notifs = notifCenter;
        Arch.panels = quick;
    }

    Panels {
        id: quick
    }

    // The Archonate menu (SUPER+Escape / archonate menu)
    ArchMenu {
        id: archMenu

        theme: root.theme
    }

    // The floating layout's dock (SUPER + Backspace to floating)
    Dock {
        theme: root.theme
    }

    // The keyboard cheat sheet (SUPER + / / archonate keys)
    Cheatsheet {
        id: cheatsheet

        theme: root.theme
    }

    // Day/night rices (Settings > Day & night): ask once a minute, and soon
    // after starting so a login catches up
    Process {
        id: scheduleTick

        command: ["python3", Quickshell.env("HOME") + "/.config/hypr/lib/desktop.py", "schedule-tick"]
    }
    Timer {
        running: cfg.globalVal("schedule", {})?.enabled ?? false
        repeat: true
        triggeredOnStart: false
        interval: 60000
        onTriggered: scheduleTick.running = true
    }
    Timer {
        running: cfg.globalVal("schedule", {})?.enabled ?? false
        interval: 8000
        onTriggered: scheduleTick.running = true
    }

    // A rice switch holds a still of the old desktop over the screen
    // (cover/shell.qml); lift it once this one has had a moment to draw
    Timer {
        running: true
        interval: 900
        onTriggered: root.sfx("hello")
    }

    Timer {
        running: true
        interval: 650
        onTriggered: Quickshell.execDetached(["qs", "-p", Quickshell.env("HOME") + "/.config/hypr/cover", "ipc", "call", "cover", "fade"])
    }

    Services {
        id: svc
    }

    // Overrides from the Rice Settings app, live
    Settings {
        id: cfg
    }

    Toggles {
        id: tog

        cfg: cfg
        mode: root.mode
        onChanged: (id, label, icon, on) => osd.announce(icon, label + (on ? " on" : " off"))
    }

    Wallpaper {
        id: wall

        theme: root.theme
        live: !["gaming", "minimal"].includes(root.mode)
        intros: tog.intros
        minutes: cfg.riceVal("wallpaperMinutes", root.theme.wallpaperMinutes ?? 0)
    }

    Variants {
        model: Quickshell.screens
        delegate: root.bar
    }

    Notifs {
        id: notifCenter

        theme: root.theme
        services: svc
        sound: root.soundPath(cfg.riceVal("notifSound", root.theme.notifSound ?? ""))
        dnd: tog.dnd
    }

    Osd {
        id: osd

        theme: root.theme
        services: svc
    }

    Widget {
        id: widget

        theme: root.theme
        services: svc
        pos: cfg.riceVal("widgetPos", root.theme.widgetPos ?? "bottom-left")
        // A rice with its own widgets (theme.ownWidgets) draws them in its shell.qml
        shown: tog.widgets && !(root.theme.ownWidgets ?? false)
    }

    Screensaver {
        id: saver

        theme: root.theme
        enabled: tog.screensaver && !tog.caffeine && !root.gaming
        minutes: cfg.globalVal("screensaverMinutes", 5)
    }

    Lock {
        id: locker

        theme: root.theme
        image: wall.isVideo ? "" : wall.path
        idleMinutes: cfg.globalVal("idleMinutes", 10)
        screenOffMinutes: cfg.globalVal("screenOffMinutes", 15)
        caffeine: tog.caffeine
        onWasLocked: root.sfx("lock")
        onWasUnlocked: root.sfx("unlock")
        onWrongPassword: root.sfx("wrong")
    }

    // hypr-mode calls setMode; this covers startup
    Process {
        running: true
        command: ["readlink", Quickshell.env("HOME") + "/.config/hypr/active-mode.lua"]
        stdout: StdioCollector {
            onStreamFinished: root.mode = text.trim().replace(/^.*\//, "").replace(/\.lua$/, "")
        }
    }

    IpcHandler {
        target: "rice"

        // Quick panels: control network bluetooth sound calendar media power updates
        function panel(name: string): void {
            if (quick.current === name)
                quick.close();
            else
                quick.openNamed(name);
        }
        function checkUpdates(): void {
            svc.checkUpdates();
        }
        function closePanel(): void {
            quick.close();
        }
        // The Archonate menu; section "" toggles it, otherwise opens there
        function menu(section: string): void {
            archMenu.show(section);
        }
        // A short popup: archonate layout uses it ("Scrolling", "Floating")
        function announce(icon: string, text: string): void {
            osd.announce(icon, text);
        }
        // The keyboard cheat sheet; a second call closes it
        function keys(): void {
            cheatsheet.toggle();
        }
        // The first-login welcome again (archonate welcome)
        function welcome(): void {
            cheatsheet.greet();
        }
        function screensaver(): void {
            saver.start();
        }
        function stopScreensaver(): void {
            saver.stop();
        }
        function lock(): void {
            locker.lock();
        }
        function previewLock(): void {
            locker.preview();
        }
        function toggleCenter(): void {
            notifCenter.centerOpen = !notifCenter.centerOpen;
        }
        // Keyboard control of the notifications on screen (or the last five)
        function notifKeys(): void {
            notifCenter.keys();
        }
        function clearNotifs(): void {
            notifCenter.clearAll();
        }
        function media(cmd: string): void {
            svc.media(cmd);
        }
        // Kept for old callers; the widget follows effects.json by itself
        function setWidgets(on: bool): void {}
        function setMode(name: string): void {
            root.mode = name;
        }
        function rescanWallpaper(): void {
            wall.rescan();
        }
        function nextWallpaper(): void {
            wall.next();
        }
        function prevWallpaper(): void {
            wall.prev();
        }
    }
}
