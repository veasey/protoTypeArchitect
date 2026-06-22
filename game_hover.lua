-- game_hover.lua
local game_hover = {}

function game_hover.getHoveredObject(game, mx, my, cam)
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

return game_hover