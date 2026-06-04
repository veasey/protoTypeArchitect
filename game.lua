local cfg     = require("config")
local map     = require("map")
local Denizen = require("denizen")
local Comfort = require("comfort")
local Entity  = require("entity")

local game = {}

game.denizens  = {}
game.comforts  = {}
game.entities  = {}

game.entityTemplate = {
    speed    = cfg.ENTITY_DEFAULTS.speed,
    radius   = cfg.ENTITY_DEFAULTS.radius,
    despairPerSec = cfg.ENTITY_DEFAULTS.despairPerSec,
}

game.spawnTimer = 0
game.aiTimer    = 0

function game.init()
    map.generate()
end

function game.spawnDenizen()
    local floors = map.getAllFloorTiles()
    if #floors == 0 then return end   -- no floor, no spawn

    local tile = floors[love.math.random(#floors)]
    local wx, wy = map.tileToWorld(tile.x, tile.y)
    table.insert(game.denizens, Denizen.create(wx, wy))
end

function game.addComfort(wx, wy)
    table.insert(game.comforts, Comfort.create(wx, wy))
end

function game.addEntity(wx, wy)
    table.insert(game.entities, Entity.create(wx, wy, game.entityTemplate))
end

function game.update(dt)
    -- Spawning
    game.spawnTimer = game.spawnTimer + dt
    while game.spawnTimer >= cfg.SPAWN_INTERVAL do
        game.spawnTimer = game.spawnTimer - cfg.SPAWN_INTERVAL
        game.spawnDenizen()
    end

    -- Denizen movement
    for _, den in ipairs(game.denizens) do
        den:update(dt, map)
    end

    -- Entity movement
    for _, ent in ipairs(game.entities) do
        ent:update(dt, map)
    end

    -- Despair system
    game.aiTimer = game.aiTimer + dt
    while game.aiTimer >= cfg.AI_INTERVAL do
        game.aiTimer = game.aiTimer - cfg.AI_INTERVAL
        for i = #game.denizens, 1, -1 do
            local den = game.denizens[i]
            if den:updateDespair(cfg.AI_INTERVAL, game.comforts, game.entities) then
                table.remove(game.denizens, i)
            end
        end
    end
end

function game.getEfficiency()
    if #game.denizens == 0 then return 0 end
    local count = 0
    for _, den in ipairs(game.denizens) do
        local d = den.profile.despair
        if d >= cfg.SWEET_SPOT_LOW and d <= cfg.SWEET_SPOT_HIGH then
            count = count + 1
        end
    end
    return math.floor((count / #game.denizens) * 100)
end

return game