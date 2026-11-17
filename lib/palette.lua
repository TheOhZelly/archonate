-- A rice's colours, read from rices/<rice>/desktop.json ("palette"): the one
-- place a rice's colours are written. The shell (qs-common/Palette.qml), the
-- app templates (desktop.py) and Hyprland (theme.lua, through this) all read it.
--   local P = require("lib.palette")("kyoto")   -- P.accent == "8f9a5a"

local cache = {}

return function(rice)
    if cache[rice] then
        return cache[rice]
    end
    local p = {}
    local ok, json = pcall(require, "utils.json")
    local f = ok and io.open(os.getenv("HOME") .. "/.config/hypr/rices/" .. rice .. "/desktop.json")
    if f then
        local good, d = pcall(json.decode, f:read("*a"))
        f:close()
        if good and type(d) == "table" and type(d.palette) == "table" then
            p = d.palette
        end
    end
    -- A missing key reads as magenta, so a typo shows instead of hiding
    p = setmetatable(p, { __index = function() return "ff00ff" end })
    cache[rice] = p
    return p
end
