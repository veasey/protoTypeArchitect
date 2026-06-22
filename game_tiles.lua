-- game_tiles.lua
local map = require("map")
local effects = require("effects")
local audio = require("audio")
local util = require("util")
local cfg = require("config")

local tiles = {}

-- shared helper
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

function tiles.clearTile(game, tileX, tileY)
    local tx, ty = tileX, tileY
    removeFromList(game.comforts, tx, ty, function(c) audio.removeLampLoop(c) end)
    removeFromList(game.entities, tx, ty, function(e) effects.addObjectFade("entity", e.x, e.y, 1, 1) end)
    for i = #game.denizens, 1, -1 do
        local d = game.denizens[i]
        local ix, iy = map.worldToTile(d.x, d.y)
        if ix == tx and iy == ty then
            effects.addObjectFade("denizen", d.x, d.y, 1, 1)
            effects.addParticleBurst(d.x, d.y, 8)
            game.removeDenizen(i, "tile removed by player")
            audio.playDenizenEnterLeaveSound()
        end
    end
    removeFromList(game.foods,   tx, ty)
    removeFromList(game.exits,   tx, ty)
    removeFromList(game.corpses, tx, ty)
end

function tiles.witnessTileChange(game, tileX, tileY)
    local worldX, worldY = map.tileToWorld(tileX, tileY)
    for _, den in ipairs(game.denizens) do
        local dist = util.distance(den.x, den.y, worldX, worldY)
        if dist <= cfg.WITNESS_SIGHT_RANGE and util.hasLineOfSight(map, den.x, den.y, worldX, worldY) then
            den.profile.anxiety = math.min(1, den.profile.anxiety + cfg.WITNESS_ANXIETY_SPIKE)
            den.profile.despair = math.min(1, den.profile.despair + cfg.WITNESS_DESPAIR_SPIKE)
        end
    end
end

return tiles