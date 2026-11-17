// Archonate's shared handles, so any bar or panel can reach the desktop
// without threading properties through every rice: Arch.theme, Arch.services,
// Arch.toggles, Arch.notifs, Arch.panels, plus run helpers. Desktop fills it in.
pragma Singleton

import QtQuick
import Quickshell

Singleton {
    id: root

    property QtObject theme: null
    property var services: null
    property var toggles: null
    property var notifs: null
    property var panels: null

    readonly property string home: Quickshell.env("HOME")
    readonly property string archonate: home + "/.local/bin/archonate"

    // archonate <args...>, fire and forget
    function cmd(args: var): void {
        Quickshell.execDetached([archonate, ...args]);
    }

    // Open Settings at a page (closes the panel first)
    function settings(page: string): void {
        panels?.close();
        cmd(["settings", page]);
    }

    // Theme-aware text casing (kyoto is lowercase, ashen upper...)
    function caps(s: string): string {
        return theme?.caps ? theme.caps(s) : s;
    }
}
