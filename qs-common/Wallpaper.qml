// Wallpapers from <rice>/assets: `wallpaper.*` plus anything in `wallpapers/`.
// Still images, animated gifs, or looping silent video (mp4/webm/mkv/mov).
// next()/prev() cycle them (the choice is remembered per rice); with
// `minutes` > 0 they also rotate on a timer. `live: false` pauses gifs/video.
//
// Intros (omarchy's animated backgrounds): a still `x.webp` with a clip at
// `intros/x.mp4` beside it plays that clip once whenever it comes up (shell
// start, a rice/style switch, picking it), then fades into the still.
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

Scope {
    id: root

    required property QtObject theme
    property bool live: true
    property int minutes: 0
    property bool intros: true // the "intros" switch; off in gaming/minimal via live

    property var files: []
    property int index: 0
    readonly property string path: files.length ? files[index % files.length] : ""

    readonly property string rice: Quickshell.shellPath("").replace(/\/shell\/?$/, "").split("/").pop()
    readonly property string stateFile: Quickshell.env("HOME") + "/.local/state/hypr-rice/wall-" + rice
    readonly property string ext: path.split(".").pop().toLowerCase()
    readonly property bool isVideo: ["mp4", "webm", "mkv", "mov"].includes(ext)
    readonly property bool isGif: ext === "gif"

    // The intro clip for the current still, if it has one
    property var introFiles: []
    readonly property string intro: {
        if (!path || isVideo || isGif)
            return "";
        const dir = path.slice(0, path.lastIndexOf("/"));
        const stem = path.slice(path.lastIndexOf("/") + 1).replace(/\.[^.]+$/, "");
        const want = dir + "/intros/" + stem + ".mp4";
        return introFiles.includes(want) ? want : "";
    }
    property bool introPlaying: false
    onPathChanged: maybeIntro()
    onIntroChanged: maybeIntro()
    property string introShown: "" // the still whose intro last played
    function maybeIntro(): void {
        if (intro && intros && live && introShown !== path) {
            introShown = path;
            introPlaying = true;
            introGuard.restart();
        } else if (!intro && introPlaying && introShown !== path) {
            introPlaying = false; // moved to a wallpaper without one
        }
    }
    Timer {
        id: introGuard // never hold a broken clip on screen

        interval: 15000
        onTriggered: root.introPlaying = false
    }

    function rescan(): void {
        finder.running = true;
    }

    function step(d: int): void {
        if (files.length < 2)
            return;
        index = (index + d + files.length) % files.length;
        saver.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf %s \"$2\" > \"$1\"", "sh", stateFile, String(index)];
        saver.running = true;
    }

    function next(): void {
        step(1);
    }

    function prev(): void {
        step(-1);
    }

    Process {
        id: finder

        running: true
        // Same order as desktop.py wallpapers(): wallpaper.* first, then
        // wallpapers/*, each sorted bytewise (LC_ALL=C), so an index means the
        // same file to the shell, the switcher and Settings
        command: ["sh", "-c", "cd \"$0\" 2>/dev/null && { LC_ALL=C ls -1d wallpaper.* 2>/dev/null; LC_ALL=C ls -1d wallpapers/* 2>/dev/null; } | grep -iE '\\.(png|jpe?g|webp|gif|mp4|webm|mkv|mov)$' | sed \"s|^|$0/|\"; echo @@intros; LC_ALL=C ls -1d \"$0\"/intros/*.mp4 \"$0\"/wallpapers/intros/*.mp4 2>/dev/null; echo @@state; cat \"$1\" 2>/dev/null", Quickshell.shellPath("../assets"), root.stateFile]
        stdout: StdioCollector {
            onStreamFinished: {
                const [walls, rest] = text.split("@@intros");
                const [intros, state] = (rest ?? "").split("@@state");
                root.introFiles = (intros ?? "").split("\n").filter(s => s.trim() !== "");
                root.files = walls.split("\n").filter(s => s.trim() !== "");
                const saved = parseInt((state ?? "").trim());
                root.index = isNaN(saved) ? 0 : saved % Math.max(1, root.files.length);
            }
        }
    }

    Process {
        id: saver
    }

    Timer {
        running: root.minutes > 0 && root.live
        repeat: true
        interval: root.minutes * 60000
        onTriggered: root.next()
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            required property var modelData

            screen: modelData
            WlrLayershell.layer: WlrLayer.Background
            WlrLayershell.namespace: "rice-wallpaper"
            exclusionMode: ExclusionMode.Ignore
            anchors {
                top: true
                bottom: true
                left: true
                right: true
            }
            color: root.theme.bg

            Image {
                anchors.fill: parent
                visible: !root.isVideo && !root.isGif && root.path !== ""
                source: visible ? "file://" + root.path : ""
                fillMode: Image.PreserveAspectCrop
                smooth: !(root.theme.pixelArt ?? false) // pixel art stays crisp when scaled up
                asynchronous: true
                cache: false
            }

            AnimatedImage {
                anchors.fill: parent
                visible: root.isGif
                source: visible ? "file://" + root.path : ""
                fillMode: Image.PreserveAspectCrop
                smooth: !(root.theme.pixelArt ?? false)
                playing: root.live
                cache: false
            }

            // The intro, over the still, once; then it fades away
            Video {
                id: introVid

                anchors.fill: parent
                z: 2
                visible: opacity > 0
                opacity: root.introPlaying ? 1 : 0
                source: root.introPlaying ? "file://" + root.intro : ""
                fillMode: VideoOutput.PreserveAspectCrop
                loops: 1
                muted: true
                autoPlay: true
                // Done when the clip itself reaches its end (not when a new one
                // replaces it)
                onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState && String(source) === "file://" + root.intro && duration > 0 && position >= duration - 400)
                    root.introPlaying = false
                // A clip that vanished (a style switch swaps the folder) mustn't
                // cancel the one that replaced it: only the current clip counts
                onErrorOccurred: if (String(source) === "file://" + root.intro)
                    root.introPlaying = false
                // A new clip starts from the top even if another was mid-play
                onSourceChanged: if (String(source) !== "") {
                    position = 0;
                    play();
                }
                Behavior on opacity {
                    NumberAnimation {
                        duration: 700
                        easing.type: Easing.InOutQuad
                    }
                }
            }

            Video {
                id: video

                anchors.fill: parent
                visible: root.isVideo
                source: visible ? "file://" + root.path : ""
                fillMode: VideoOutput.PreserveAspectCrop
                loops: MediaPlayer.Infinite
                muted: true
                autoPlay: true

                Connections {
                    target: root

                    function onLiveChanged(): void {
                        if (root.live)
                            video.play();
                        else
                            video.pause();
                    }
                }
            }
        }
    }
}
