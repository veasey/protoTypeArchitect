-- effects.lua
-- Manages visual fade-in/fade-out animations for tiles and objects.

local effects = {}
effects.list = {}

-- Tile fade-in: a dark overlay on a new floor tile fades out
function effects.addTileFadeIn(tileX, tileY, duration)
    duration = duration or 0.5
    table.insert(effects.list, {
        type = "tile_fade_in",
        tileX = tileX,
        tileY = tileY,
        startAlpha = 1,
        targetAlpha = 0,
        alpha = 1,
        duration = duration,
        elapsed = 0,
    })
end

-- Tile fade-out: a floor sprite on a void tile fades out
function effects.addTileFadeOut(tileX, tileY, duration)
    duration = duration or 0.5
    table.insert(effects.list, {
        type = "tile_fade_out",
        tileX = tileX,
        tileY = tileY,
        startAlpha = 1,
        targetAlpha = 0,
        alpha = 1,
        duration = duration,
        elapsed = 0,
    })
end

-- Object fade-out (for lamps, entities, denizens that are removed)
function effects.addObjectFade(objType, x, y, scaleX, scaleY, duration)
    duration = duration or 0.3
    table.insert(effects.list, {
        type = "object_fade",
        objType = objType,
        x = x,
        y = y,
        scaleX = scaleX or 1,
        scaleY = scaleY or 1,
        startAlpha = 1,
        targetAlpha = 0,
        alpha = 1,
        duration = duration,
        elapsed = 0,
    })
end

function effects.update(dt)
    for i = #effects.list, 1, -1 do
        local e = effects.list[i]
        e.elapsed = e.elapsed + dt
        if e.elapsed >= e.duration then
            table.remove(effects.list, i)
        else
            local progress = e.elapsed / e.duration
            e.alpha = e.startAlpha + (e.targetAlpha - e.startAlpha) * progress
        end
    end
end

return effects