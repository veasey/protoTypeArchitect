-- game_update.lua
local map = require("map")
local Denizen = require("denizen")
local effects = require("effects")
local audio = require("audio")
local util = require("util")
local cfg = require("config")
local logger = require("logger")
local camera = require("camera")
local effects = require("effects")

local update = {}

local function removeDenizen(game, index, cause)
    local den = game.denizens[index]
    if den.events and #den.events > 0 then
        logger.logDenizen(den.name, den.personality, den.events, cause)
    end
    table.remove(game.denizens, index)
end

function update.run(game, dt)
    if game.paused then return end

    -- Spawning
    game.spawnTimer = game.spawnTimer + dt
    local spawnMult = cfg.FAMILIARITY_SPAWN_MULT * game.familiarity
    while game.spawnTimer >= cfg.SPAWN_INTERVAL do
        game.spawnTimer = game.spawnTimer - cfg.SPAWN_INTERVAL
        local numSpawns = math.max(1, math.floor(1 + spawnMult))
        for _ = 1, numSpawns do
            game.spawnDenizen()
        end
    end

    -- Denizen movement & exit detection
    for _, den in ipairs(game.denizens) do
        den:update(dt, map, game.entities, game.lightmap, game.unease, game.foods, game.exits, game.denizens, game.familiarity)
    end

    -- ============================================================
    --  DENIZEN REMOVAL OUTCOMES (grouped)
    -- ============================================================
    -- 1. Escape
    for i = #game.denizens, 1, -1 do
        local den = game.denizens[i]
        if den.escaped then
            game.escapedCount = game.escapedCount + 1
            game.familiarity = math.min(1, game.familiarity + cfg.EXIT_FAMILIARITY_BOOST)
            effects.addParticleBurst(den.x, den.y, 15)

            -- Resource‑drop effect
            local screenX = (den.x - camera.x) * camera.zoom + cfg.GAME_WIDTH / 2
            local screenY = (den.y - camera.y) * camera.zoom + cfg.WINDOW_HEIGHT / 2
            local targetX, targetY = getFamiliarityBarCenter()
            effects.addResourceDrop(screenX, screenY, targetX, targetY, {0.2, 0.8, 0.2})

            removeDenizen(game, i, "escaped")
            audio.playDenizenEnterLeaveSound()
        end
    end

    -- 2. Noclip
    for i = #game.denizens, 1, -1 do
        if game.denizens[i].toRemove then
            effects.addParticleBurst(game.denizens[i].x, game.denizens[i].y, 15)
            removeDenizen(game, i, "noclipped out")
        end
    end

    -- 3. Despair death
    game.aiTimer = game.aiTimer + dt
    while game.aiTimer >= cfg.AI_INTERVAL do
        game.aiTimer = game.aiTimer - cfg.AI_INTERVAL
        for i = #game.denizens, 1, -1 do
            local den = game.denizens[i]
            if den:updateDespair(cfg.AI_INTERVAL, game.comforts, game.entities, game.foods, game.corpses) then
                effects.addObjectFade("denizen", den.x, den.y, 1, 1)
                table.insert(game.corpses, { x = den.x, y = den.y, rotTimer = 10, maxRotTimer = 10 })
                effects.addParticleBurst(den.x, den.y, 6)
                removeDenizen(game, i, "despair min/max")
                audio.playDenizenEnterLeaveSound()
            end
        end
    end

    -- 4. Frozen to corpse
    for i = #game.denizens, 1, -1 do
        local den = game.denizens[i]
        if den.becomeCorpse then
            table.insert(game.corpses, { x = den.x, y = den.y, rotTimer = 10, maxRotTimer = 10 })
            effects.addParticleBurst(den.x, den.y, 6)
            removeDenizen(game, i, "became a corpse")
        end
    end

    -- 5. Psychotic → entity
    for i = #game.denizens, 1, -1 do
        local den = game.denizens[i]
        if den.becomeEntity then
            game.addEntity(den.x, den.y)
            effects.addParticleBurst(den.x, den.y, 12)
            removeDenizen(game, i, "became an entity")
        end
    end

    -- Entity movement
    for _, ent in ipairs(game.entities) do
        ent:update(dt, map, game.denizens, game.lightmap)
    end

    -- Resources (delegated)
    game.computeResources(dt)

    -- Dread entity spawning
    game.dreadSpawnTimer = game.dreadSpawnTimer + dt
    if game.dreadSpawnTimer >= cfg.DREAD_SPAWN_INTERVAL then
        game.dreadSpawnTimer = 0
        if game.dread >= cfg.DREAD_SPAWN_THRESHOLD and love.math.random() < cfg.DREAD_SPAWN_CHANCE then
            local floors = map.getAllFloorTiles()
            local darkTiles = {}
            for _, tile in ipairs(floors) do
                local light = game.lightmap[tile.y] and game.lightmap[tile.y][tile.x] or 0
                if light <= cfg.DREAD_SPAWN_MIN_LIGHT then
                    table.insert(darkTiles, tile)
                end
            end
            if #darkTiles > 0 then
                local tile = darkTiles[love.math.random(#darkTiles)]
                local wx, wy = map.tileToWorld(tile.x, tile.y)
                game.addEntity(wx, wy)
            end
        end
    end

    -- Corpse rotting
    for i = #game.corpses, 1, -1 do
        local c = game.corpses[i]
        c.rotTimer = c.rotTimer - dt
        if c.rotTimer <= 0 then
            table.remove(game.corpses, i)
        end
    end

    -- ============================================================
    --  RESOURCE DROPS (subtle pulsing particles toward status bars)
    -- ============================================================
    for _, den in ipairs(game.denizens) do
        local screenX = (den.x - camera.x) * camera.zoom + cfg.GAME_WIDTH / 2
        local screenY = (den.y - camera.y) * camera.zoom + cfg.WINDOW_HEIGHT / 2

        -- Unease drop when a denizen starts hiding (sees an entity)
        if den.justStartedHiding then
            local targetX, targetY = util.getUneaseBarCenter()
            effects.addResourceDrop(screenX, screenY, targetX, targetY, {0.8, 0.8, 0.2})
            den.justStartedHiding = nil
        end

        -- Dread drop when a denizen flees, freezes, or goes psychotic
        if den.justGotScared then
            local targetX, targetY = util.getDreadBarCenter()
            effects.addResourceDrop(screenX, screenY, targetX, targetY, {0.8, 0.2, 0.2})
            den.justGotScared = nil
        end
    end

    game.computeLighting()
    effects.update(dt)

    -- Auto‑stop build sound
    local hasTileFade = false
    for _, e in ipairs(effects.list) do
        if e.type == "tile_fade_in" or e.type == "tile_fade_out" then
            hasTileFade = true; break
        end
    end
    if not hasTileFade and audio.stopBuildSound then
        audio.stopBuildSound()
    end
end

return update