-- effects.lua
-- Manages visual fade-in/fade-out animations for tiles and objects.

local effects = {}
effects.list = {}

-- Tile fade-in (new floor tile appears)
function effects.addTileFadeIn(tileX, tileY, delay, duration)
    duration = duration or 0.4
    delay = delay or 0
    table.insert(effects.list, {
        type = "tile_fade_in",
        tileX = tileX,
        tileY = tileY,
        startAlpha = 1,
        targetAlpha = 0,
        alpha = 1,
        delay = delay,
        duration = duration,
        elapsed = 0,
    })
end

-- Returns true if there is an active tile_fade_in for these coordinates
function effects.isTileFadingIn(tileX, tileY)
    for _, e in ipairs(effects.list) do
        if e.type == "tile_fade_in" and e.tileX == tileX and e.tileY == tileY then
            return true
        end
    end
    return false
end

-- Tile fade-out (floor tile becomes void) – unchanged except optional lightLevel
function effects.addTileFadeOut(tileX, tileY, lightLevel, delay, duration)
    duration = duration or 0.4
    delay = delay or 0
    lightLevel = lightLevel or 1
    table.insert(effects.list, {
        type = "tile_fade_out",
        tileX = tileX,
        tileY = tileY,
        startAlpha = 1,
        targetAlpha = 0,
        alpha = 1,
        lightLevel = lightLevel,
        delay = delay,
        duration = duration,
        elapsed = 0,
    })
end

-- Object fade-out (lamps, entities, denizens)
function effects.addObjectFade(objType, x, y, scaleX, scaleY, duration)
    duration = duration or 0.3
    table.insert(effects.list, {
        type = "object_fade",
        objType = objType,
        x = x, y = y,
        scaleX = scaleX or 1, scaleY = scaleY or 1,
        startAlpha = 1, targetAlpha = 0, alpha = 1,
        delay = 0, duration = duration, elapsed = 0,
    })
end

function effects.update(dt)
    for i = #effects.list, 1, -1 do
        local e = effects.list[i]
        e.elapsed = e.elapsed + dt
        local fadeProgress = 0
        if e.elapsed >= e.delay then
            local activeTime = e.elapsed - e.delay
            fadeProgress = math.min(activeTime / e.duration, 1.0)
        end
        e.alpha = e.startAlpha + (e.targetAlpha - e.startAlpha) * fadeProgress
        if e.elapsed >= e.delay + e.duration then
            table.remove(effects.list, i)
        end
    end
end

return effects