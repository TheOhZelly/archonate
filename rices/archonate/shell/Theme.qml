// archonate: omarchy's flat mono look, Ryoku-style living desktop. Every colour
// comes from ../desktop.json and recolours live.
import QtQuick
import Quickshell
import "common"

QtObject {
    // Colours live in ../desktop.json (palette); edit them there
    readonly property Palette pal: Palette {}

    // Palette
    readonly property color bg: pal.c("bg")
    readonly property color surface: pal.c("surface")
    readonly property color surfaceHi: pal.c("surface_hi")
    readonly property color text: pal.c("text")
    readonly property color textDim: pal.c("text_dim")
    readonly property color accent: pal.c("accent")
    readonly property color accent2: pal.c("tertiary")
    readonly property color hot: pal.c("secondary")
    readonly property color urgent: pal.c("error")
    readonly property color border: Qt.alpha(pal.c("accent"), 0.4)

    // Shape
    readonly property int borderWidth: 1
    readonly property int radius: 10
    readonly property int pad: 16
    readonly property int gap: 10
    readonly property real panelAlpha: 0.92
    readonly property int notifWidth: 360
    readonly property int osdBar: 4

    // Type: mono everywhere, a heavy compressed sans for the poster clock
    readonly property string font: "JetBrainsMono Nerd Font"
    readonly property string displayFont: "Fira Sans Compressed"
    readonly property int fontSize: 12
    readonly property real tracking: 0
    function caps(s: string): string {
        return s;
    }
    readonly property string longDate: "dddd, d MMMM"

    // Played on each new notification ("" = silent)
    readonly property string notifSound: "rice:notify"

    // Wallpapers: assets/wallpaper.* + assets/wallpapers/*; rotate every N minutes (0 = only on SUPER+SHIFT+W)
    readonly property int wallpaperMinutes: 0

    // archonate draws its own desktop widgets (shell.qml); the stock one stays off.
    // SUPER+F12 still toggles them all.
    readonly property bool ownWidgets: true
    readonly property bool wearsStyles: true // look.json: styles dress this rice
    readonly property string widgetPos: "top-right"
    readonly property int widgetClockSize: 190
    readonly property color widgetClockColor: text
    readonly property bool widgetItalic: false
    readonly property bool widgetCard: false

    // Lockscreen
    readonly property string lockTitle: "archonate"
    readonly property string lockPrompt: "password"
    readonly property string lockWrong: "try again"
    readonly property string lockDot: "•"
    readonly property string lockClock: "HH:mm"
    readonly property int lockClockSize: 150
    readonly property int lockClockWeight: Font.Black
    readonly property real lockImageOpacity: 0.8
}
