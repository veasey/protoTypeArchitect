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
game.lightmap = {}

function game.init()
    map.generate()

    -- Place a lamp in the centre of the starting room
    local cx = math.floor(cfg.MAP_COLS / 2)
    local cy = math.floor(cfg.MAP_ROWS / 2)
    local wx, wy = map.tileToWorld(cx, cy)
    game.addComfort(wx, wy)
end

function game.spawnDenizen()
    local floors = map.getAllFloorTiles()
    if #floors == 0 then return end
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
    game.spawnTimer = game.spawnTimer + dt
    while game.spawnTimer >= cfg.SPAWN_INTERVAL do
        game.spawnTimer = game.spawnTimer - cfg.SPAWN_INTERVAL
        game.spawnDenizen()
    end

    for _, den in ipairs(game.denizens) do
        den:update(dt, map)
    end

    for _, ent in ipairs(game.entities) do
        ent:update(dt, map)
    end

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

    game.computeLighting()
end

function game.computeLighting()
    -- Reset lightmap to 0
    local light = {}
    for r = 1, cfg.MAP_ROWS do
        light[r] = {}
        for c = 1, cfg.MAP_COLS do
            light[r][c] = 0
        end
    end

    -- Process every lamp independently, keeping the max value
    for _, lamp in ipairs(game.comforts) do
        local startTX, startTY = map.worldToTile(lamp.x, lamp.y)
        if map.isWalkable(startTX, startTY) then
            local visited = {}
            local queue = {}
            local head = 1
            visited[startTY * cfg.MAP_COLS + startTX] = true
            table.insert(queue, {x = startTX, y = startTY, intensity = 1.0})

            while head <= #queue do
                local node = queue[head]
                head = head + 1
                local curInt = node.intensity

                -- Update this tile with the brighter of the existing value and current lamp
                if curInt > light[node.y][node.x] then
                    light[node.y][node.x] = curInt
                end

                -- Stop expanding if intensity too low
                if curInt <= cfg.LIGHT_MIN_AMBIENT then
                    goto continue
                end

                local neighbours = {
                    {x = node.x - 1, y = node.y},
                    {x = node.x + 1, y = node.y},
                    {x = node.x, y = node.y - 1},
                    {x = node.x, y = node.y + 1},
                }
                for _, nb in ipairs(neighbours) do
                    if map.isWalkable(nb.x, nb.y) then
                        local key = nb.y * cfg.MAP_COLS + nb.x
                        if not visited[key] then
                            visited[key] = true
                            local newInt = curInt - cfg.LIGHT_DECAY_PER_TILE
                            if newInt > 0 then
                                table.insert(queue, {x = nb.x, y = nb.y, intensity = newInt})
                            end
                        end
                    end
                end
                ::continue::
            end
        end
    end

    game.lightmap = light
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