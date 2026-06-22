-- game_spawning.lua
local map = require("map")
local Denizen = require("denizen")
local Comfort = require("comfort")
local Entity = require("entity")
local audio = require("audio")
local cfg = require("config")

local spawning = {}

function spawning.spawnDenizen(game)
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

function spawning.addComfort(game, wx, wy)
    table.insert(game.comforts, Comfort.create(wx, wy))
    audio.addLampLoop(game.comforts[#game.comforts])
end

function spawning.addEntity(game, wx, wy)
    game.uneaseResource = math.max(0, game.uneaseResource - cfg.ENTITY_COST)
    table.insert(game.entities, Entity.create(wx, wy, game.entityTemplate))
end

function spawning.addFood(game, wx, wy)
    table.insert(game.foods, {x = wx, y = wy})
end

function spawning.addExit(game, wx, wy)
    table.insert(game.exits, {x = wx, y = wy})
end

return spawning