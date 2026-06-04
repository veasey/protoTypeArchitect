local util = {}

function util.clamp(val, low, high)
    return math.max(low, math.min(high, val))
end

function util.distance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx*dx + dy*dy)
end

-- Linear interpolation between two colour tables (r,g,b)
function util.lerpColor(c1, c2, t)
    t = util.clamp(t, 0, 1)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t,
    }
end

return util