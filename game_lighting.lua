-- game_lighting.lua
local map = require("map")
local cfg = require("config")

local lighting = {}

function lighting.compute(game)
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

return lighting