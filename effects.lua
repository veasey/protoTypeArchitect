-- effects.lua
-- Manages visual fade-in/fade-out animations for tiles and objects,
-- plus death particles and resource drops.

local effects = {}
effects.list = {}
effects.particles = {}
effects.resourceDrops = {}

-- ============================================================
--  TILE / OBJECT FADES (unchanged)
-- ============================================================
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

function effects.isTileFadingIn(tileX, tileY)
    for _, e in ipairs(effects.list) do
        if e.type == "tile_fade_in" and e.tileX == tileX and e.tileY == tileY then
            return true
        end
    end
    return false
end

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
    -- existing tile/object fades
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

    -- particle bursts (death)
    effects.updateParticles(dt)
    -- resource drops (bonds/escapes)
    effects.updateResourceDrops(dt)
end

-- ============================================================
--  DEATH PARTICLES
-- ============================================================
function effects.addParticleBurst(x, y, count)
    count = count or 10
    for i = 1, count do
        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random(30, 80)
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed
        table.insert(effects.particles, {
            x = x, y = y,
            vx = vx, vy = vy,
            life = 0.4 + love.math.random() * 0.3,
            maxLife = 0.4 + love.math.random() * 0.3,
            color = love.math.random() < 0.5 and {1,1,1} or {0,0,0},
        })
    end
end

function effects.updateParticles(dt)
    for i = #effects.particles, 1, -1 do
        local p = effects.particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(effects.particles, i)
        end
    end
end

-- ============================================================
--  RESOURCE DROPS (shards flying to Familiarity bar)
-- ============================================================
function effects.addResourceDrop(screenX, screenY, targetX, targetY, color)
    table.insert(effects.resourceDrops, {
        x = screenX, y = screenY,
        startX = screenX, startY = screenY,
        targetX = targetX, targetY = targetY,
        color = color,
        life = 0.6,
        maxLife = 0.6,
    })
end

function effects.updateResourceDrops(dt)
    for i = #effects.resourceDrops, 1, -1 do
        local d = effects.resourceDrops[i]
        d.life = d.life - dt
        if d.life <= 0 then
            table.remove(effects.resourceDrops, i)
        else
            local t = 1 - (d.life / d.maxLife)
            d.x = d.startX + (d.targetX - d.startX) * t
            d.y = d.startY + (d.targetY - d.startY) * t
        end
    end
end

function effects.addResourceDrop(screenX, screenY, targetX, targetY, color)
    table.insert(effects.resourceDrops, {
        x = screenX, y = screenY,
        startX = screenX, startY = screenY,
        targetX = targetX, targetY = targetY,
        color = color,
        life = 0.6,
        maxLife = 0.6,
        phase = love.math.random() * math.pi * 2,   -- random pulse phase
    })
end

return effects