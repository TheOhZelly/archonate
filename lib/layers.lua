-- Helpers for rice theme files.

local M = {}

-- Register curves and animation leaves.
--   curves: { name = { {x1, y1}, {x2, y2} } }
--   leafs:  { windowsIn = { speed, curve [, style] }, ... }
function M.motion(curves, leafs)
    for name, points in pairs(curves) do
        hl.curve(name, { type = "bezier", points = points })
    end
    for leaf, a in pairs(leafs) do
        hl.animation({ leaf = leaf, enabled = true, speed = a[1], bezier = a[2], style = a[3] })
    end
end

return M
