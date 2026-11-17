-- RICE DISPATCHER (hypr-rice checks for this marker).
--
-- Loads the active rice (active-rice.lua -> rices/<name>/theme.lua) on top of
-- standalone/init.lua, then common.lua (pickers, Archonate keys) and the
-- active mode, which overrides both.

local home = os.getenv("HOME")
local hypr = home .. "/.config/hypr"

local function load(path)
    local ok, t = pcall(dofile, path)
    return ok and type(t) == "table" and t or nil
end

local rice = load(hypr .. "/active-rice.lua") or load(hypr .. "/rices/archonate/theme.lua")

dofile(hypr .. "/standalone/init.lua").load(rice)

dofile(hypr .. "/common.lua")

local mode = load(hypr .. "/active-mode.lua")
if mode and mode.apply then mode.apply() end
