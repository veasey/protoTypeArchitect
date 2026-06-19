local cfg     = require("config")
local map     = require("map")
local Denizen = require("denizen")
local Comfort = require("comfort")
local Entity  = require("entity")
local effects = require("effects")
local audio   = require("audio")
local util    = require("util")
local logger  = require("logger")

local game = {}

game.denizens  = {}
game.comforts  = {}
game.entities  = {}
game.foods     = {}
game.exits     = {}
game.corpses   = {}
game.escapedCount = 0

game.entityTemplate = {
    speed          = cfg.ENTITY_DEFAULTS.speed,
    radius         = cfg.ENTITY_DEFAULTS.radius,
    despairPerSec  = cfg.ENTITY_DEFAULTS.despairPerSec,
    aggression     = cfg.ENTITY_DEFAULTS.aggression,
    lightAvoidance = cfg.ENTITY_DEFAULTS.lightAvoidance,
    hearingRange   = cfg.ENTITY_DEFAULTS.hearingRange,
}

game.spawnTimer = 0
game.aiTimer    = 0
game.lightmap = {}

game.familiarity = 0
game.unease = 0
game.dread = 0
game.dreadSpawnTimer = 0
game.paused = false

game.familiarityResource = 1.0
game.uneaseResource      = 1.0

-- ============================================================
--  Helpers
-- ============================================================
local function comfortToTable(c)
    return { x = c.x, y = c.y }
end

local function entityToTable(e)
    return {
        x = e.x, y = e.y,
        speed = e.speed, radius = e.radius, despairPerSec = e.despairPerSec,
        aggression = e.aggression, lightAvoidance = e.lightAvoidance,
        hearingRange = e.hearingRange, state = e.state, active = e.active,
    }
end

local function denizenToTable(d)
    return {
        x = d.x, y = d.y, vx = d.vx, vy = d.vy, state = d.state,
        name = d.name, personality = d.personality,
        profile = {
            anxiety = d.profile.anxiety,
            despair = d.profile.despair,
            speed   = d.profile.speed,
        },
        wanderTimer  = d.wanderTimer,
        nextWander   = d.nextWander,
        hidingTimer  = d.hidingTimer,
        hideCooldown = d.hideCooldown,
        fearTimer    = d.fearTimer,
        lastChaserPos = d.lastChaserPos,
        frozenTimer = d.frozenTimer,
        psychoticTimer = d.psychoticTimer,
        events = d.events,   -- not needed to save but can be saved
    }
end

local function entityFromTable(ed)
    local ent = Entity.create(ed.x, ed.y, {
        speed = ed.speed, radius = ed.radius, despairPerSec = ed.despairPerSec,
        aggression = ed.aggression, lightAvoidance = ed.lightAvoidance,
        hearingRange = ed.hearingRange or cfg.ENTITY_DEFAULTS.hearingRange,
    })
    ent.active = ed.active
    ent.state = ed.state or "lurking"
    return ent
end

local function denizenFromTable(dd)
    local den = Denizen.create(dd.x, dd.y)
    den.vx = dd.vx; den.vy = dd.vy; den.state = dd.state
    den.name = dd.name or "Unknown"
    den.personality = dd.personality or "brave"
    den.persData = cfg.PERSONALITIES[den.personality] or {}
    den.profile.anxiety = dd.profile.anxiety; den.profile.despair = dd.profile.despair
    den.profile.speed = dd.profile.speed
    den.wanderTimer = dd.wanderTimer; den.nextWander = dd.nextWander
    den.hidingTimer = dd.hidingTimer or 0; den.hideCooldown = dd.hideCooldown or 0
    den.fearTimer = dd.fearTimer or 0
    den.lastChaserPos = dd.lastChaserPos or nil
    den.frozenTimer = dd.frozenTimer or 0
    den.psychoticTimer = dd.psychoticTimer or 0
    den.events = dd.events or {}
    return den
end

local function removeFromList(list, tx, ty, beforeRemove)
    for i = #list, 1, -1 do
        local item = list[i]
        local ix, iy = map.worldToTile(item.x, item.y)
        if ix == tx and iy == ty then
            if beforeRemove then beforeRemove(item) end
            table.remove(list, i)
        end
    end
end

local function removeDenizen(index, cause)
    local den = game.denizens[index]
    if den.events and #den.events > 0 then
        logger.logDenizen(den.name, den.personality, den.events, cause)
    end
    table.remove(game.denizens, index)
end

-- ============================================================
--  Initialisation
-- ============================================================
function game.init()
    map.generate()
    local cx = math.floor(cfg.MAP_COLS / 2)
    local cy = math.floor(cfg.MAP_ROWS / 2)
    local wx, wy = map.tileToWorld(cx, cy)
    game.addComfort(wx, wy)
    game.computeLighting()
end

-- ============================================================
--  Spawning & placement
-- ============================================================
function game.spawnDenizen()
    local floors = map.getAllFloorTiles()
    local candidates = {}
    for _, tile in ipairs(floors) do
        local light = game.lightmap[tile.y] and game.lightmap[tile.y][tile.x] or 0
        if light >= cfg.DENIZEN_SPAWN_MIN_LIGHT then
            table.insert(candidates, tile)
        end
    end
    if #candidates == 0 then return end
    local tile = candidates[love.math.random(#candidates)]
    local wx, wy = map.tileToWorld(tile.x, tile.y)
    table.insert(game.denizens, Denizen.create(wx, wy))
    audio.playDenizenEnterLeaveSound()
end

function game.addComfort(wx, wy)
    table.insert(game.comforts, Comfort.create(wx, wy))
    audio.addLampLoop(game.comforts[#game.comforts])
end

function game.addEntity(wx, wy)
    game.uneaseResource = math.max(0, game.uneaseResource - cfg.ENTITY_COST)
    table.insert(game.entities, Entity.create(wx, wy, game.entityTemplate))
end

function game.addFood(wx, wy)
    table.insert(game.foods, {x = wx, y = wy})
end

function game.addExit(wx, wy)
    table.insert(game.exits, {x = wx, y = wy})
end

-- ============================================================
--  Tile management
-- ============================================================
function game.clearTile(tileX, tileY)
    local tx, ty = tileX, tileY
    removeFromList(game.comforts, tx, ty, function(c) audio.removeLampLoop(c) end)
    removeFromList(game.entities, tx, ty, function(e) effects.addObjectFade("entity", e.x, e.y, 1, 1) end)
    -- Denizens removed via tile clearing are logged
    for i = #game.denizens, 1, -1 do
        local d = game.denizens[i]
        local ix, iy = map.worldToTile(d.x, d.y)
        if ix == tx and iy == ty then
            effects.addObjectFade("denizen", d.x, d.y, 1, 1)
            removeDenizen(i, "tile removed by player")
            audio.playDenizenEnterLeaveSound()
        end
    end
    removeFromList(game.foods,   tx, ty)
    removeFromList(game.exits,   tx, ty)
    removeFromList(game.corpses, tx, ty)
end

function game.witnessTileChange(tileX, tileY)
    local worldX, worldY = map.tileToWorld(tileX, tileY)
    for _, den in ipairs(game.denizens) do
        local dist = util.distance(den.x, den.y, worldX, worldY)
        if dist <= cfg.WITNESS_SIGHT_RANGE and util.hasLineOfSight(map, den.x, den.y, worldX, worldY) then
            den.profile.anxiety = math.min(1, den.profile.anxiety + cfg.WITNESS_ANXIETY_SPIKE)
            den.profile.despair = math.min(1, den.profile.despair + cfg.WITNESS_DESPAIR_SPIKE)
        end
    end
end

-- ============================================================
--  Main update loop
-- ============================================================
function game.update(dt)
    if game.paused then return end

    game.spawnTimer = game.spawnTimer + dt
    local spawnMult = cfg.FAMILIARITY_SPAWN_MULT * game.familiarity
    while game.spawnTimer >= cfg.SPAWN_INTERVAL do
        game.spawnTimer = game.spawnTimer - cfg.SPAWN_INTERVAL
        local numSpawns = math.max(1, math.floor(1 + spawnMult))
        for _ = 1, numSpawns do
            game.spawnDenizen()
        end
    end

    for _, den in ipairs(game.denizens) do
        den:update(dt, map, game.entities, game.lightmap, game.unease, game.foods, game.exits, game.denizens, game.familiarity)
        if den.escaped then
            game.escapedCount = game.escapedCount + 1
            game.familiarity = math.min(1, game.familiarity + cfg.EXIT_FAMILIARITY_BOOST)
            audio.playDenizenEnterLeaveSound()
            den.toRemove = true
        end
    end

    -- Handle outcomes
    for i = #game.denizens, 1, -1 do
        local den = game.denizens[i]
        if den.becomeCorpse then
            removeDenizen(i, "became a corpse")
            table.insert(game.corpses, {x = den.x, y = den.y})
        elseif den.becomeEntity then
            removeDenizen(i, "became an entity")
            game.addEntity(den.x, den.y)
        end
    end

    -- Remove escapees / toRemove
    for i = #game.denizens, 1, -1 do
        if game.denizens[i].toRemove then
            removeDenizen(i, "escaped")
        end
    end

    for _, ent in ipairs(game.entities) do
        ent:update(dt, map, game.denizens, game.lightmap)
    end

    game.aiTimer = game.aiTimer + dt
    while game.aiTimer >= cfg.AI_INTERVAL do
        game.aiTimer = game.aiTimer - cfg.AI_INTERVAL
        for i = #game.denizens, 1, -1 do
            local den = game.denizens[i]
            if den:updateDespair(cfg.AI_INTERVAL, game.comforts, game.entities, game.foods, game.corpses) then
                effects.addObjectFade("denizen", den.x, den.y, 1, 1)
                removeDenizen(i, "despair min/max")
                audio.playDenizenEnterLeaveSound()
            end
        end
    end

    -- Compute global resources (social + light)
    local totalFamiliarityScore = 0
    local totalAnxiety = 0
    local totalDespair = 0
    local denCount = #game.denizens
    if denCount > 0 then
        for _, den in ipairs(game.denizens) do
            local tileX, tileY = map.worldToTile(den.x, den.y)
            local light = math.max(game.lightmap[tileY] and game.lightmap[tileY][tileX] or 0, cfg.LIGHT_MIN_AMBIENT)
            local social = (den.nearbyDenizenCount > 0) and 1 or 0
            local score = 0.6 * light + 0.4 * social
            totalFamiliarityScore = totalFamiliarityScore + score
            totalAnxiety = totalAnxiety + den.profile.anxiety
            totalDespair = totalDespair + den.profile.despair
        end
        local targetFamiliarity = math.max(0, math.min(1, totalFamiliarityScore / denCount))
        local targetUnease = math.max(0, math.min(1, totalAnxiety / denCount))
        local targetDread = math.max(0, math.min(1, totalDespair / denCount))

        local maxChange = 0.05 * dt
        game.familiarity = game.familiarity + util.clamp(targetFamiliarity - game.familiarity, -maxChange, maxChange)
        game.unease = game.unease + util.clamp(targetUnease - game.unease, -maxChange, maxChange)
        game.dread = game.dread + util.clamp(targetDread - game.dread, -maxChange, maxChange)
    else
        game.familiarity = 0
        game.unease = 0
        game.dread = 0
    end

    -- Perfect equilibrium tracking (all three between 0.4 and 0.6)
    if game.familiarity >= 0.4 and game.familiarity <= 0.6
       and game.unease >= 0.4 and game.unease <= 0.6
       and game.dread >= 0.4 and game.dread <= 0.6 then
        game.perfectEquilibriumTimer = (game.perfectEquilibriumTimer or 0) + dt
    else
        game.perfectEquilibriumTimer = 0
    end

    -- Spendable resources increase toward global averages, but never drop
    local rechargeRate = 0.025 * dt   -- 5% of the bar per second
    if game.familiarityResource < game.familiarity then
        game.familiarityResource = math.min(game.familiarity, game.familiarityResource + rechargeRate)
    end
    if game.uneaseResource < game.unease then
        game.uneaseResource = math.min(game.unease, game.uneaseResource + rechargeRate)
    end

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

    game.computeLighting()
    effects.update(dt)

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

-- ============================================================
--  Lighting
-- ============================================================
function game.computeLighting()
    local light = {}
    for r = 1, cfg.MAP_ROWS do
        light[r] = {}
        for c = 1, cfg.MAP_COLS do light[r][c] = 0 end
    end
    for _, lamp in ipairs(game.comforts) do
        local startTX, startTY = map.worldToTile(lamp.x, lamp.y)
        if map.isWalkable(startTX, startTY) then
            local visited, queue = {}, {}
            local head = 1
            visited[startTY * cfg.MAP_COLS + startTX] = true
            table.insert(queue, {x = startTX, y = startTY, intensity = 1.0})
            while head <= #queue do
                local node = queue[head]; head = head + 1
                local curInt = node.intensity
                if curInt > light[node.y][node.x] then
                    light[node.y][node.x] = curInt
                end
                if curInt > cfg.LIGHT_MIN_AMBIENT then
                    for _, nb in ipairs({{-1,0},{1,0},{0,-1},{0,1}}) do
                        local nx, ny = node.x + nb[1], node.y + nb[2]
                        if map.isWalkable(nx, ny) then
                            local key = ny * cfg.MAP_COLS + nx
                            if not visited[key] then
                                visited[key] = true
                                local newInt = curInt - cfg.LIGHT_DECAY_PER_TILE
                                if newInt > 0 then
                                    table.insert(queue, {x=nx, y=ny, intensity=newInt})
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    game.lightmap = light
end

-- ============================================================
--  Metrics & pause
-- ============================================================
function game.getEfficiency()
    if #game.denizens == 0 then return 0 end
    local count = 0
    for _, den in ipairs(game.denizens) do
        local d = den.profile.despair
        if d >= cfg.SWEET_SPOT_LOW and d <= cfg.SWEET_SPOT_HIGH then count = count + 1 end
    end
    return math.floor((count / #game.denizens) * 100)
end

function game.togglePauseState()
    game.paused = not game.paused
    if game.paused then audio.pauseAll() else audio.resumeAll() end
end

-- ============================================================
--  Save / Load
-- ============================================================
function game.save()
    local saveData = {
        map = {},
        comforts = {},
        entities = {},
        denizens = {},
        foods = {},
        exits = {},
        corpses = {},
        entityTemplate = game.entityTemplate,
        escapedCount = game.escapedCount,
        familiarity = game.familiarity,
        unease = game.unease,
        dread = game.dread,
        dreadSpawnTimer = game.dreadSpawnTimer,
        familiarityResource = game.familiarityResource,
        uneaseResource = game.uneaseResource,
    }
    for r = 1, cfg.MAP_ROWS do
        saveData.map[r] = {}
        for c = 1, cfg.MAP_COLS do
            saveData.map[r][c] = map.grid[r][c]
        end
    end
    for _, c in ipairs(game.comforts) do
        table.insert(saveData.comforts, comfortToTable(c))
    end
    for _, e in ipairs(game.entities) do
        table.insert(saveData.entities, entityToTable(e))
    end
    for _, d in ipairs(game.denizens) do
        table.insert(saveData.denizens, denizenToTable(d))
    end
    for _, f in ipairs(game.foods) do
        table.insert(saveData.foods, {x = f.x, y = f.y})
    end
    for _, e in ipairs(game.exits) do
        table.insert(saveData.exits, {x = e.x, y = e.y})
    end
    for _, c in ipairs(game.corpses) do
        table.insert(saveData.corpses, {x = c.x, y = c.y})
    end
    local serialized = "return " .. util.tableShow(saveData, "saveData")
    local ok, err = love.filesystem.write("backrooms_save.lua", serialized)
    if ok then print("Game saved.") else print("Save error: " .. tostring(err)) end
end

function game.load()
    local info = love.filesystem.getInfo("backrooms_save.lua")
    if not info then print("No save file found.") return end
    local chunk, loadErr = love.filesystem.load("backrooms_save.lua")
    if not chunk then print("Load error: " .. tostring(loadErr)) return end
    local success, saveData = pcall(chunk)
    if not success then print("Failed to execute save file: " .. tostring(saveData)) return end

    for r = 1, cfg.MAP_ROWS do
        for c = 1, cfg.MAP_COLS do
            map.grid[r][c] = saveData.map[r][c] or cfg.VOID
        end
    end
    game.entityTemplate = saveData.entityTemplate or game.entityTemplate
    game.escapedCount = saveData.escapedCount or 0
    game.familiarity = saveData.familiarity or 0
    game.unease = saveData.unease or 0
    game.dread = saveData.dread or 0
    game.dreadSpawnTimer = saveData.dreadSpawnTimer or 0
    game.familiarityResource = saveData.familiarityResource or 1.0
    game.uneaseResource = saveData.uneaseResource or 1.0

    game.comforts = {}
    game.entities = {}
    game.denizens = {}
    game.foods = {}
    game.exits = {}
    game.corpses = {}

    for _, cd in ipairs(saveData.comforts) do game.addComfort(cd.x, cd.y) end
    for _, ed in ipairs(saveData.entities) do
        table.insert(game.entities, entityFromTable(ed))
    end
    for _, dd in ipairs(saveData.denizens) do
        table.insert(game.denizens, denizenFromTable(dd))
    end
    for _, fd in ipairs(saveData.foods or {}) do game.addFood(fd.x, fd.y) end
    for _, ed in ipairs(saveData.exits or {}) do game.addExit(ed.x, ed.y) end
    for _, cd in ipairs(saveData.corpses or {}) do
        table.insert(game.corpses, {x = cd.x, y = cd.y})
    end

    game.computeLighting()
    print("Game loaded.")
end

-- ============================================================
--  Mouse hover
-- ============================================================
function game.getHoveredObject(mx, my, cam)
    local wx, wy = cam.screenToWorld(mx, my)
    local bestDist = 24
    local bestObj = nil

    local function checkList(list, objType)
        for _, obj in ipairs(list) do
            local dx, dy = obj.x - wx, obj.y - wy
            local dist = math.sqrt(dx*dx + dy*dy)
            if dist < bestDist then
                bestDist = dist
                bestObj = { type = objType, data = obj }
            end
        end
    end

    checkList(game.entities, "entity")
    checkList(game.denizens, "denizen")
    checkList(game.foods,    "food")
    checkList(game.exits,    "exit")
    checkList(game.corpses,  "corpse")

    return bestObj
end

return game