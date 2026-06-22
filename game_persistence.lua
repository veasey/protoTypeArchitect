-- game_persistence.lua
local map = require("map")
local Entity = require("entity")
local Denizen = require("denizen")
local util = require("util")
local cfg = require("config")

local persistence = {}

-- helpers for table serialization
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
        events = d.events,
    }
end

function persistence.save(game)
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

function persistence.load(game)
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

    local spawning = require("game_spawning")
    for _, cd in ipairs(saveData.comforts) do spawning.addComfort(game, cd.x, cd.y) end
    for _, ed in ipairs(saveData.entities) do
        local ent = Entity.create(ed.x, ed.y, {
            speed = ed.speed, radius = ed.radius, despairPerSec = ed.despairPerSec,
            aggression = ed.aggression, lightAvoidance = ed.lightAvoidance,
            hearingRange = ed.hearingRange or cfg.ENTITY_DEFAULTS.hearingRange,
        })
        ent.active = ed.active
        ent.state = ed.state or "lurking"
        table.insert(game.entities, ent)
    end
    for _, dd in ipairs(saveData.denizens) do
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
        table.insert(game.denizens, den)
    end
    for _, fd in ipairs(saveData.foods or {}) do spawning.addFood(game, fd.x, fd.y) end
    for _, ed in ipairs(saveData.exits or {}) do spawning.addExit(game, ed.x, ed.y) end
    for _, cd in ipairs(saveData.corpses or {}) do
        table.insert(game.corpses, {x = cd.x, y = cd.y, rotTimer = 10, maxRotTimer = 10})
    end

    game.computeLighting()
    print("Game loaded.")
end

return persistence