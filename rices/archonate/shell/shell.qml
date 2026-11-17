// archonate desktop (run by hypr-rice: qs -p ~/.config/hypr/rices/archonate/shell)
// The shared Desktop plus archonate's own living layer: one cava feed and one
// stats poll shared by the notch bar and four desktop widgets. SUPER+F12
// (the widgets switch) hides the widgets; gaming and minimal modes do too.
import QtQuick
import Quickshell
import "common"

ShellRoot {
    id: shell

    readonly property bool widgetsOn: desktop.toggles.widgets && desktop.mode === "normal"

    Desktop {
        id: desktop

        theme: Theme {}
        bar: Component {
            Bar {
                theme: desktop.theme
                services: desktop.services
                notifs: desktop.notifs
                cava: cavaFeed
                stats: sysStats
                cfg: desktop.cfg
                autoHide: desktop.gaming
            }
        }
    }

    Cava {
        id: cavaFeed

        active: (desktop.services.player?.isPlaying ?? false) && !desktop.gaming
    }

    SysStats {
        id: sysStats
    }

    Visualizer {
        theme: desktop.theme
        cava: cavaFeed
        services: desktop.services
        shown: shell.widgetsOn
    }
    MediaCard {
        theme: desktop.theme
        services: desktop.services
        shown: shell.widgetsOn
    }
    PosterClock {
        theme: desktop.theme
        shown: shell.widgetsOn
    }
    StatsColumn {
        theme: desktop.theme
        stats: sysStats
        shown: shell.widgetsOn
    }
}
