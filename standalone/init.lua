-- The base for every rice: each runs its own Quickshell desktop from
-- rices/<name>/shell; this sets the shared Hyprland behaviour (input,
-- gestures, rules, keybinds), the login daemons, then the rice's look, then
-- your overrides (user.lua). Modes (modes/*.lua) apply after all of it.

local M = {}

local home = os.getenv("HOME")
local hypr = home .. "/.config/hypr"

local function keys(k)
    if type(k) == "table" then return k end
    return { k }
end

-- Rebind every key in `k` (a vars.kb* value) to `action`
local function rebind(k, action, flags)
    for _, key in ipairs(keys(k)) do
        hl.unbind(key)
        hl.bind(key, action, flags)
    end
end

function M.load(rice)
    local vars  = require("variables")
    local fn    = require("utils.functions")
    local shell = hypr .. "/rices/" .. rice.name .. "/shell"
    local qs    = "qs -p " .. shell
    local ipc   = qs .. " ipc call rice "
    local fuzzel = "fuzzel --config " .. hypr .. "/rices/" .. rice.name .. "/fuzzel.ini"
    local bin   = hypr .. "/lib/"

    hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

    -- Environment. qtengine reads the per-rice Qt colours lib/desktop.py writes.
    local cursor = rice.cursor or { theme = vars.cursorTheme, size = vars.cursorSize }
    hl.env("XCURSOR_THEME", cursor.theme)
    hl.env("XCURSOR_SIZE", cursor.size)
    hl.env("QT_QPA_PLATFORMTHEME", "qtengine")
    hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
    hl.env("GDK_BACKEND", "wayland,x11")
    hl.env("QT_QPA_PLATFORM", "wayland;xcb")
    hl.env("SDL_VIDEODRIVER", "wayland,x11,windows")
    hl.env("CLUTTER_BACKEND", "wayland")
    hl.env("ELECTRON_OZONE_PLATFORM_HINT", "auto")
    hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
    hl.env("XDG_SESSION_TYPE", "wayland")
    hl.env("XDG_SESSION_DESKTOP", "Hyprland")
    hl.env("_JAVA_AWT_WM_NONREPARENTING", "1")

    -- Layout and misc behaviour (looks come from the rice)
    hl.config({
        general = { layout = "dwindle", allow_tearing = false },
        dwindle = { preserve_split = true, smart_split = false, smart_resizing = true },
        misc    = {
            animate_manual_resizes       = false,
            animate_mouse_windowdragging = false,
            disable_hyprland_logo        = true,
            force_default_wallpaper      = 0,
            on_focus_under_fullscreen    = 2,
            allow_session_lock_restore   = true,
            middle_click_paste           = false,
            focus_on_activate            = true,
            mouse_move_enables_dpms      = true,
            key_press_enables_dpms       = true,
        },
    })

    -- Shared behaviour: input, gestures, window rules, keybinds
    require("hyprland.input")
    require("hyprland.gestures")
    require("hyprland.rules")
    require("hyprland.layouts") -- tiling / scrolling / floating (SUPER + Backspace)
    require("hyprland.keybinds")

    -- Login-only daemons. The rice's own shell is started here too; hypr-rice
    -- swaps shells at runtime, since exec-once style hooks never re-run.
    hl.on("hyprland.start", function()
        hl.exec_cmd("/usr/lib/polkit-gnome/polkit-gnome-authentication-agent-1")
        hl.exec_cmd("wl-paste --type text --watch cliphist store")
        hl.exec_cmd("wl-paste --type image --watch cliphist store")
        hl.exec_cmd("trash-empty 30")
        hl.exec_cmd("hyprctl setcursor " .. cursor.theme .. " " .. cursor.size)
        hl.exec_cmd("/usr/lib/geoclue-2.0/demos/agent")
        hl.exec_cmd("sleep 1 && gammastep")
        hl.exec_cmd("mpris-proxy")
        hl.exec_cmd(qs .. " -d")
    end)

    -- Bitwarden / picture-in-picture resizers
    local function apply_resizer_rules(win)
        local float_center = {
            hl.dsp.window.float({ action = "on", window = win }),
            hl.dsp.window.center({ window = win }),
        }
        fn.resizer(win, "Bitwarden", 20, 54, float_center, true, "class")
        fn.resizer(win, "^Extension: %(Bitwarden Password Manager%) %- Bitwarden", 20, 54, float_center, false)
        fn.resizer(win, "nngceckbapebfimnlniiiahkandclblb", 20, 54, float_center, true, "class")
        fn.resizer(win, "Picture[- ]in[- ][Pp]icture", 0, 0, fn.move_actions(win) or {}, false)
    end
    hl.on("window.title", apply_resizer_rules)
    hl.on("window.open", apply_resizer_rules)

    -- The rice's look, then the user's own overrides (kb layout, kwallet...)
    rice.apply()

    -- Optional screen shader (rices/<name>/shader.frag), toggled with SUPER+F11.
    -- Modes run after this and can switch it off again.
    local shader = hypr .. "/rices/" .. rice.name .. "/shader.frag"
    local effects = io.open(home .. "/.local/state/hypr-rice/effects.json")
    local shader_on = true
    if effects then
        shader_on = not effects:read("*a"):match('"shader"%s*:%s*false')
        effects:close()
    end
    local f = io.open(shader)
    if f and shader_on then
        hl.config({ decoration = { screen_shader = shader } })
    end
    if f then f:close() end
    -- your own overrides: ~/.config/hypr/user.lua (optional; see user.lua.example)
    local ok, err = pcall(require, "user")
    if not ok and not tostring(err):find("module 'user' not found", 1, true) then
        error(err, 0) -- a real mistake in user.lua should still show up
    end
end

return M
