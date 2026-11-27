// archonate desktop (run by hypr-rice: qs -p ~/.config/hypr/rices/archonate/shell)
// The shared Desktop plus the feeds the notch bar shows: one cava feed (the
// music line) and one stats poll.
import QtQuick
import Quickshell
import "common"

ShellRoot {
    id: shell

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
}
