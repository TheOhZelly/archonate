-- archonate: omarchy's flat, tight, keyboard-first look with a living desktop:
-- a notch bar hanging from the top edge, an audio visualizer, a media card,
-- a poster clock and a stats column. Colours follow the wallpaper (desktop.json).
local layers = require("lib.layers")

-- Colours live in desktop.json (palette); edit them there
local P = require("lib.palette")("archonate")
local bg      = P.bg
local surface = P.surface
local muted   = P.muted
local text    = P.text
local accent  = P.accent

return {
    name     = "archonate",
    cursor   = { theme = "WhiteSur-cursors", size = 24 },
    terminal = "kitty",

    apply = function()
        hl.config({
            general = {
                gaps_in         = 6,
                gaps_out        = 14,
                gaps_workspaces = 30,
                border_size     = 1,
                col             = {
                    active_border   = "rgba(" .. accent .. "cc)",
                    inactive_border = "rgba(" .. muted .. "99)",
                },
            },
            decoration = {
                rounding = 10,
                blur     = { enabled = true, size = 8, passes = 3, new_optimizations = true, ignore_opacity = true, popups = true },
                shadow   = { enabled = true, range = 24, render_power = 3, color = "rgba(00000077)" },
            },
            group = {
                col = {
                    border_active   = "rgba(" .. accent .. "cc)",
                    border_inactive = "rgba(" .. muted .. "99)",
                },
                groupbar = {
                    font_family = "JetBrainsMono Nerd Font",
                    text_color  = "rgb(" .. text .. ")",
                    col         = { active = "rgba(" .. accent .. "cc)", inactive = "rgb(" .. surface .. ")" },
                },
            },
            misc = { background_color = "rgb(" .. bg .. ")" },
        })

        hl.window_rule({ match = { class = ".*" }, opacity = "0.95 override" })
        hl.window_rule({ match = { fullscreen = true }, opacity = "1.0 override" })
        hl.layer_rule({ match = { namespace = "rice-(bar|center|notifs|osd|panel|card)" }, blur = true, ignore_alpha = 0.3 })
        hl.layer_rule({ match = { namespace = "launcher" }, blur = true, animation = "slide top" })

        -- Quick like archonateold, with a softer landing
        layers.motion({
            snap  = { { 0.22, 1 }, { 0.36, 1 } },
            quick = { { 0.15, 0 }, { 0.1, 1 } },
        }, {
            windowsIn        = { 4, "snap", "popin 88%" },
            windowsOut       = { 3, "quick", "popin 88%" },
            windowsMove      = { 4, "snap" },
            workspaces       = { 5, "snap", "slide" },
            specialWorkspace = { 4, "snap", "slidevert" },
            layersIn         = { 4, "snap", "fade" },
            layersOut        = { 3, "quick", "fade" },
            fadeLayers       = { 4, "quick" },
            fade             = { 4, "quick" },
            fadeDim          = { 4, "quick" },
            border           = { 5, "quick" },
        })
    end,
}
