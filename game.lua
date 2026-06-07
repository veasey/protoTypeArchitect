local cfg     = require("config")
local map     = require("map")
local Denizen = require("denizen")
local Comfort = require("comfort")
local Entity  = require("entity")
local effects = require("effects")
local audio   = require("audio")
local camera  = require("camera")

local game = {}

game.denizens  = {}
game.comforts  = {}
game.entities  = {}

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

function game.init()
    map.generate()

    -- Place a lamp in the centre of the starting room
    local cx = math.floor(cfg.MAP_COLS / 2)
    local cy = math.floor(cfg.MAP_ROWS / 2)
    local wx, wy = map.tileToWorld(cx, cy)
    game.addComfort(wx, wy)
    audio.addLampLoop(game.comforts[#game.comforts])

    -- Compute initial lighting so spawn checks work
    game.computeLighting()
end

function game.spawnDenizen()
    local floors = map.getAllFloorTiles()
    local candidates = {}
    for _, tile in ipairs(floors) do
        local light = game.lightmap[tile.y] and game.lightmap[tile.y][tile.x] or 0
        if light >= cfg.DENIZEN_SPAWN_MIN_LIGHT then
            table.insert(candidates, tile)
            audio.playDenizenEnterLeaveSound()
        end
    end
    if #candidates == 0 then return end
    local tile = candidates[love.math.random(#candidates)]
    local wx, wy = map.tileToWorld(tile.x, tile.y)
    table.insert(game.denizens, Denizen.create(wx, wy))
end

function game.addComfort(wx, wy)
    table.insert(game.comforts, Comfort.create(wx, wy))
    audio.addLampLoop(game.comforts[#game.comforts])
end

function game.addEntity(wx, wy)
    table.insert(game.entities, Entity.create(wx, wy, game.entityTemplate))
end

function game.clearTile(tileX, tileY)
    local worldX, worldY = map.tileToWorld(tileX, tileY)

    -- Remove comforts with fade
    for i = #game.comforts, 1, -1 do
        local c = game.comforts[i]
        local tx, ty = map.worldToTile(c.x, c.y)
        if tx == tileX and ty == tileY then
            effects.addObjectFade("lamp", c.x, c.y, 1, 1)
            table.remove(game.comforts, i)
            audio.removeLampLoop(c)
        end
    end

    -- Remove entities with fade
    for i = #game.entities, 1, -1 do
        local e = game.entities[i]
        local tx, ty = map.worldToTile(e.x, e.y)
        if tx == tileX and ty == tileY then
            local scale = e.radius / 16
            effects.addObjectFade("entity", e.x, e.y, 1, 1)
            table.remove(game.entities, i)
        end
    end

    -- Remove denizens with fade
    for i = #game.denizens, 1, -1 do
        local d = game.denizens[i]
        local tx, ty = map.worldToTile(d.x, d.y)
        if tx == tileX and ty == tileY then
            effects.addObjectFade("denizen", d.x, d.y, 1, 1)
            table.remove(game.denizens, i)
            audio.playDenizenEnterLeaveSound()
        end
    end
end

function game.update(dt)
    -- Spawning
    game.spawnTimer = game.spawnTimer + dt
    while game.spawnTimer >= cfg.SPAWN_INTERVAL do
        game.spawnTimer = game.spawnTimer - cfg.SPAWN_INTERVAL
        game.spawnDenizen()
    end

    -- Denizen movement (needs entities for sight/flee)
    for _, den in ipairs(game.denizens) do
        den:update(dt, map, game.entities, game.lightmap)
    end

    -- Entity movement (needs denizens for chase and lightmap for light bias)
    for _, ent in ipairs(game.entities) do
        ent:update(dt, map, game.denizens, game.lightmap)
    end

    -- Despair system
    game.aiTimer = game.aiTimer + dt
    while game.aiTimer >= cfg.AI_INTERVAL do
        game.aiTimer = game.aiTimer - cfg.AI_INTERVAL
        for i = #game.denizens, 1, -1 do
            local den = game.denizens[i]
            if den:updateDespair(cfg.AI_INTERVAL, game.comforts, game.entities) then
                effects.addObjectFade("denizen", den.x, den.y, 1, 1)
                table.remove(game.denizens, i)
            end
        end
    end

    -- Recalculate lighting (after all movements and possible tile changes)
    game.computeLighting()

    -- Update fade animations
    effects.update(dt)

    -- If no tile fade effects remain, stop the building sound
    local hasTileFade = false
    for _, e in ipairs(effects.list) do
        if e.type == "tile_fade_in" or e.type == "tile_fade_out" then
            hasTileFade = true
            break
        end
    end
    if not hasTileFade then
        audio.stopBuildSound()
    end
end

function game.computeLighting()
    local light = {}
    for r = 1, cfg.MAP_ROWS do
        light[r] = {}
        for c = 1, cfg.MAP_COLS do
            light[r][c] = 0
        end
    end

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

                if curInt > light[node.y][node.x] then
                    light[node.y][node.x] = curInt
                end

                if curInt > cfg.LIGHT_MIN_AMBIENT then
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
                end
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

-- ========== SAVE / LOAD (unchanged) ==========
local SAVE_FILE = "backrooms_save.lua"

function game.save()
    local saveData = {
        map = {},
        comforts = {},
        entities = {},
        denizens = {},
        entityTemplate = game.entityTemplate,
    }
    for r = 1, cfg.MAP_ROWS do
        saveData.map[r] = {}
        for c = 1, cfg.MAP_COLS do
            saveData.map[r][c] = map.grid[r][c]
        end
    end
    for _, c in ipairs(game.comforts) do
        table.insert(saveData.comforts, {x = c.x, y = c.y})
    end
    for _, e in ipairs(game.entities) do
        table.insert(saveData.entities, {
            x = e.x, y = e.y,
            speed = e.speed, radius = e.radius, despairPerSec = e.despairPerSec,
            aggression = e.aggression, lightAvoidance = e.lightAvoidance,
            hearingRange = e.hearingRange,
            state = e.state,          -- <-- add
            active = e.active,
        })
    end
    for _, d in ipairs(game.denizens) do
        table.insert(saveData.denizens, {
            x = d.x, y = d.y, vx = d.vx, vy = d.vy, state = d.state,
            profile = { anxiety = d.profile.anxiety, despair = d.profile.despair, speed = d.profile.speed },
            wanderTimer = d.wanderTimer, nextWander = d.nextWander,
        })
    end
    local serialized = "return " .. table.show(saveData, "saveData")
    local ok, err = love.filesystem.write(SAVE_FILE, serialized)
    if ok then print("Game saved.") else print("Save error: " .. tostring(err)) end
end

function game.load()
    local info = love.filesystem.getInfo(SAVE_FILE)
    if not info then print("No save file found.") return end
    local chunk, loadErr = love.filesystem.load(SAVE_FILE)
    if not chunk then print("Load error: " .. tostring(loadErr)) return end
    local success, saveData = pcall(chunk)
    if not success then print("Failed to execute save file: " .. tostring(saveData)) return end

    for r = 1, cfg.MAP_ROWS do
        for c = 1, cfg.MAP_COLS do
            map.grid[r][c] = saveData.map[r][c] or cfg.VOID
        end
    end
    game.entityTemplate = saveData.entityTemplate or game.entityTemplate
    game.comforts = {}
    game.entities = {}
    game.denizens = {}
    for _, cd in ipairs(saveData.comforts) do game.addComfort(cd.x, cd.y) end
    for _, ed in ipairs(saveData.entities) do
        local ent = Entity.create(ed.x, ed.y, {
            speed = ed.speed,
            radius = ed.radius,
            despairPerSec = ed.despairPerSec,
            aggression = ed.aggression,
            lightAvoidance = ed.lightAvoidance,
            hearingRange = ed.hearingRange or cfg.ENTITY_DEFAULTS.hearingRange,
        })
        ent.active = ed.active
        ent.state = ed.state or "lurking"   -- <-- restore or default
        table.insert(game.entities, ent)
    end
    for _, dd in ipairs(saveData.denizens) do
        local den = Denizen.create(dd.x, dd.y)
        den.vx = dd.vx; den.vy = dd.vy; den.state = dd.state
        den.profile.anxiety = dd.profile.anxiety; den.profile.despair = dd.profile.despair
        den.profile.speed = dd.profile.speed
        den.wanderTimer = dd.wanderTimer; den.nextWander = dd.nextWander
        table.insert(game.denizens, den)
    end
    game.computeLighting()
    print("Game loaded.")
end

function table.show(t, name, indent)
    indent = indent or ""
    local str = "{\n"
    local isArray = true
    for k, v in pairs(t) do
        if type(k) ~= "number" then isArray = false break end
    end
    for k, v in pairs(t) do
        local keyStr = isArray and "" or "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "] = "
        if type(v) == "table" then
            str = str .. indent .. "  " .. keyStr .. table.show(v, name, indent .. "  ") .. ",\n"
        elseif type(v) == "string" then
            str = str .. indent .. "  " .. keyStr .. string.format("%q", v) .. ",\n"
        elseif type(v) == "number" or type(v) == "boolean" then
            str = str .. indent .. "  " .. keyStr .. tostring(v) .. ",\n"
        end
    end
    str = str .. indent .. "}"
    return str
end

-- Returns the entity or denizen closest to the mouse cursor, if within 24px.
-- Call this once per frame from draw or update.
function game.getHoveredObject(mx, my, camera)
    -- Convert mouse screen coords to world coords
    local wx, wy = camera.screenToWorld(mx, my)
    local bestDist = 24  -- pixel radius to pick an object
    local bestObj = nil

    -- Check entities
    for _, ent in ipairs(game.entities) do
        local dx, dy = ent.x - wx, ent.y - wy
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < bestDist then
            bestDist = dist
            bestObj = { type = "entity", data = ent }
        end
    end

    -- Check denizens
    for _, den in ipairs(game.denizens) do
        local dx, dy = den.x - wx, den.y - wy
        local dist = math.sqrt(dx*dx + dy*dy)
        if dist < bestDist then
            bestDist = dist
            bestObj = { type = "denizen", data = den }
        end
    end

    return bestObj
end

return game