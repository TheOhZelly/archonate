-- minimal: strips effects down to a plain, fast desktop. Layout is untouched.
-- Standalone shells also pause live wallpapers in this mode.
return {
    apply = function()
        hl.config({
            animations = { enabled = false },
            decoration = {
                rounding      = 0,
                dim_inactive  = false,
                screen_shader = "",
                blur         = { enabled = false },
                shadow       = { enabled = false },
            },
        })
        hl.window_rule({ match = { class = ".*" }, opacity = "1.0 override" })
    end,
}
