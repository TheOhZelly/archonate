-- Window layouts: tiling, scrolling or floating, for the whole desktop.
-- SUPER + Backspace cycles them (`archonate layout next`); the choice lives in
-- ~/.local/state/hypr-rice/layout so a reload or a new login keeps it.
--
--   tiling     Hyprland's dwindle: windows split the screen
--   scrolling  Hyprland's built-in scrolling layout: a strip of columns you
--              scroll along
--   floating   every window floats; new ones open floating (and centred, by the
--              rule in rules.lua), with a dock of open apps at the bottom
--
-- Floating isn't a Hyprland layout: it's one rule, archonate_float_rule,
-- switched on and off live by `archonate layout` (lib/desktop.py). Windows it
-- floats are tagged archonate-floated, so leaving floating tiles exactly them.

local state = os.getenv("HOME") .. "/.local/state/hypr-rice/layout"
local f = io.open(state)
local layout = f and f:read("l") or "tiling"
if f then f:close() end

hl.config({
    general = { layout = layout == "scrolling" and "scrolling" or "dwindle" },
    scrolling = {
        column_width = 0.5,          -- two columns fill the screen
        fullscreen_on_one_column = true, -- a lone window takes the whole width
        follow_focus = true,         -- the strip scrolls to whatever you focus
        focus_fit_method = 1,        -- ...just enough to show it
    },
})

_G.archonate_float_rule = hl.window_rule({
    name    = "archonate-float-all",
    match   = { class = ".*" },
    float   = true,
    tag     = "+archonate-floated",
    enabled = layout == "floating",
})
