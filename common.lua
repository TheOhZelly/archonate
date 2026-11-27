-- Loaded for every rice (after the rice, before the mode).

local home   = os.getenv("HOME")
local picker = "qs -p " .. home .. "/.config/hypr/picker"

-- The style picker (toggle): styles, with the mode row under them
hl.bind("SUPER + F9", hl.dsp.exec_cmd(picker .. " kill >/dev/null 2>&1 || " .. picker))

-- The rice-switch cover appears instantly (its fade is its own)
hl.layer_rule({ match = { namespace = "archonate-cover" }, no_anim = true })

-- `archonate theme preview`: two floating terminals placed so the wallpaper shows
hl.window_rule({ match = { class = "archonate-preview-a" }, float = true, center = false,
    size = "(monitor_w*0.4) (monitor_h*0.42)", move = "(monitor_w*0.05) (monitor_h*0.12)" })
hl.window_rule({ match = { class = "archonate-preview-b" }, float = true, center = false,
    size = "(monitor_w*0.44) (monitor_h*0.5)", move = "(monitor_w*0.51) (monitor_h*0.43)" })

-- Archonate's install/remove terminals float, centred
hl.window_rule({ match = { class = "archonate-term" }, float = true, center = true, size = "(monitor_w*0.62) (monitor_h*0.7)" })

-- The Archonate menu: everything the desktop can do, searchable
hl.bind("SUPER + Escape", hl.dsp.exec_cmd(home .. "/.local/bin/archonate menu"))
hl.bind("SUPER + slash", hl.dsp.exec_cmd(home .. "/.local/bin/archonate keys"))
hl.bind("SUPER + BackSpace", hl.dsp.exec_cmd(home .. "/.local/bin/archonate layout next"))
hl.bind("SUPER + H", hl.dsp.exec_cmd(home .. "/.local/bin/archonate window minimize"))

-- Grab text from the screen (OCR) to the clipboard
hl.bind("SUPER + CTRL + Print", hl.dsp.exec_cmd(home .. "/.local/bin/archonate capture text"))

-- Notifications from the keyboard: 1-9 buttons, enter, del, c copies a code
hl.bind("SUPER + CTRL + Comma", hl.dsp.exec_cmd(home .. "/.local/bin/archonate notifications keys"))

-- Wallpaper switcher (carousel of this rice's wallpapers)
hl.bind("SUPER + CTRL + W", hl.dsp.exec_cmd(home .. "/.local/bin/archonate wallpaper pick"))

-- Effects: SUPER + F12 desktop widget
hl.bind("SUPER + F12", hl.dsp.exec_cmd(home .. "/.local/bin/archonate toggle widgets"))

-- Rice Settings app (toggle): SUPER + I
hl.bind("SUPER + I", hl.dsp.exec_cmd(home .. "/.config/hypr/lib/settings.sh"))

-- Apps can't force themselves maximized (kitty asks to open maximized, which
-- covered everything instead of tiling). Fullscreen on SUPER+F still works.
hl.window_rule({ match = { class = ".*" }, suppress_event = "maximize" })

-- No automatic HDR switch when a fullscreen app shows HDR content
hl.config({ render = { cm_auto_hdr = 0 } })

-- Display and keyboard/mouse choices from the Settings app
-- (~/.local/state/hypr-rice/settings.json -> global.display / global.input)
do
    local ok, json = pcall(require, "utils.json")
    local f = ok and io.open(home .. "/.local/state/hypr-rice/settings.json")
    if f then
        local good, s = pcall(json.decode, f:read("*a"))
        f:close()
        local g = good and type(s) == "table" and s.global or {}

        for output, d in pairs(g.display or {}) do
            hl.monitor({ output = output, mode = d.mode or "preferred", position = "auto", scale = d.scale or 1 })
        end

        local i = g.input or {}
        local input = {}
        if i.layouts then input.kb_layout = i.layouts end
        if i.switchKey then input.kb_options = i.switchKey end
        if i.repeatDelay then input.repeat_delay = i.repeatDelay end
        if i.repeatRate then input.repeat_rate = i.repeatRate end
        if i.sensitivity then input.sensitivity = i.sensitivity end
        if i.accel then input.accel_profile = i.accel end
        if i.naturalScroll ~= nil then input.natural_scroll = i.naturalScroll end
        if next(input) then hl.config({ input = input }) end
    end
end

-- Night light (Settings > Night light): start hyprsunset with its schedule at login
hl.on("hyprland.start", function()
    hl.exec_cmd("python3 " .. home .. "/.config/hypr/lib/desktop.py nightlight")
    -- Your post-boot hooks (~/.config/archonate/hooks/post-boot.d)
    hl.exec_cmd("sleep 3 && " .. home .. "/.local/bin/archonate hook post-boot")
    -- Crashed programs get an "Ask AI why" notification (archonate agent crash)
    hl.exec_cmd("sleep 5 && " .. home .. "/.local/bin/archonate agent crashwatch")
end)
