-- gaming: nothing that costs frames. No blur/animations/gaps/rounding/shadows,
-- VRR in fullscreen, tearing allowed for fullscreen windows.
-- Standalone shells also pause live wallpapers in this mode.
return {
    apply = function()
        hl.config({
            animations = { enabled = false },
            general    = {
                gaps_in         = 0,
                gaps_out        = 0,
                gaps_workspaces = 0,
                allow_tearing   = true,
            },
            decoration = {
                rounding      = 0,
                dim_inactive  = false,
                screen_shader = "",
                blur         = { enabled = false },
                shadow       = { enabled = false },
            },
            misc       = { vrr = 2 },            -- fullscreen only
            render     = { direct_scanout = 2 }, -- fullscreen games only
        })
        -- single-window workspace rules carry their own gaps
        hl.workspace_rule({ workspace = "w[tv1]s[false]", gaps_out = 0 })
        hl.workspace_rule({ workspace = "f[1]s[false]", gaps_out = 0 })
        hl.window_rule({ match = { class = ".*" }, opacity = "1.0 override" })
        hl.window_rule({ match = { fullscreen = true }, immediate = true })
    end,
}
