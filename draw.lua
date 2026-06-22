local cfg    = require("config")
local map    = require("map")
local camera = require("camera")
local game   = require("game")
local sprites = require("sprites")
local ui     = require("ui")
local effects = require("effects")

local draw = {}

function draw.world()
    camera.applyTransform()

    local invZoom = 1 / camera.zoom
    local left  = math.max(1, math.floor((camera.x - cfg.GAME_WIDTH/2 * invZoom) / cfg.TILE_SIZE))
    local right = math.min(cfg.MAP_COLS, math.ceil((camera.x + cfg.GAME_WIDTH/2 * invZoom) / cfg.TILE_SIZE))
    local top   = math.max(1, math.floor((camera.y - cfg.GAME_HEIGHT/2 * invZoom) / cfg.TILE_SIZE))
    local bottom = math.min(cfg.MAP_ROWS, math.ceil((camera.y + cfg.GAME_HEIGHT/2 * invZoom) / cfg.TILE_SIZE))

    for r = top, bottom do
        for c = left, right do
            local tile = map.grid[r][c]
            local tx = (c-1) * cfg.TILE_SIZE
            local ty = (r-1) * cfg.TILE_SIZE
            if tile == cfg.VOID then
                love.graphics.setColor(cfg.COL_VOID)
                love.graphics.rectangle("fill", tx, ty, cfg.TILE_SIZE, cfg.TILE_SIZE)
            else
                if not effects.isTileFadingIn(c, r) then
                    local lightLevel = game.lightmap[r] and game.lightmap[r][c] or 0
                    lightLevel = math.max(lightLevel, cfg.LIGHT_MIN_AMBIENT)
                    love.graphics.setColor(lightLevel, lightLevel, lightLevel)
                    love.graphics.draw(sprites.floor, tx, ty)
                end
            end
        end
    end

    for _, e in ipairs(effects.list) do
        if e.type == "tile_fade_in" then
            local lightLevel = game.lightmap[e.tileY] and game.lightmap[e.tileY][e.tileX] or 0
            lightLevel = math.max(lightLevel, cfg.LIGHT_MIN_AMBIENT)
            love.graphics.setColor(lightLevel, lightLevel, lightLevel, 1 - e.alpha)
            love.graphics.draw(sprites.floor, (e.tileX-1)*cfg.TILE_SIZE, (e.tileY-1)*cfg.TILE_SIZE)
        elseif e.type == "tile_fade_out" then
            local light = e.lightLevel or 1
            love.graphics.setColor(light, light, light, e.alpha)
            love.graphics.draw(sprites.floor, (e.tileX-1)*cfg.TILE_SIZE, (e.tileY-1)*cfg.TILE_SIZE)
        end
    end

    for _, e in ipairs(effects.list) do
        if e.type == "object_fade" then
            love.graphics.setColor(1, 1, 1, e.alpha)
            if e.objType == "lamp" then
                love.graphics.draw(sprites.lamp, e.x - 16, e.y - 16)
            elseif e.objType == "entity" then
                love.graphics.draw(sprites.entity, e.x - 16, e.y - 16)
            elseif e.objType == "denizen" then
                love.graphics.draw(sprites.denizen, e.x - 16, e.y - 16)
            end
        end
    end

    local rect = ui.getDragRect()
    if rect then
        local tool = ui.getActiveTool()
        local r, g, b, a
        if tool == cfg.TOOL_BUILD then
            local maxTiles = math.floor(game.familiarityResource / cfg.BUILD_COST_PER_TILE)
            local canBuild = false
            for x = rect.x1, rect.x2 do
                for y = rect.y1, rect.y2 do
                    if map.isBuildable(x, y) then canBuild = true; break end
                end
            end
            if maxTiles <= 0 or not canBuild then
                r, g, b, a = 0.8, 0.2, 0.2, 0.4
            else
                r, g, b, a = 0.2, 0.8, 0.2, 0.4
            end
        else
            r, g, b, a = 0.8, 0.2, 0.2, 0.4
        end
        for x = rect.x1, rect.x2 do
            for y = rect.y1, rect.y2 do
                local current = map.grid[y] and map.grid[y][x]
                if tool == cfg.TOOL_BUILD and current == cfg.VOID then
                    love.graphics.setColor(r, g, b, a)
                    love.graphics.rectangle("fill", (x-1)*cfg.TILE_SIZE, (y-1)*cfg.TILE_SIZE, cfg.TILE_SIZE, cfg.TILE_SIZE)
                elseif tool == cfg.TOOL_REMOVE and current == cfg.FLOOR then
                    love.graphics.setColor(r, g, b, a)
                    love.graphics.rectangle("fill", (x-1)*cfg.TILE_SIZE, (y-1)*cfg.TILE_SIZE, cfg.TILE_SIZE, cfg.TILE_SIZE)
                end
            end
        end
        love.graphics.setColor(r, g, b, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", (rect.x1-1)*cfg.TILE_SIZE, (rect.y1-1)*cfg.TILE_SIZE,
                                (rect.x2-rect.x1+1)*cfg.TILE_SIZE, (rect.y2-rect.y1+1)*cfg.TILE_SIZE)
        love.graphics.setLineWidth(1)
    end

    local hover = ui.getHoverTile()
    if hover and not ui.getDragRect() then
        local tx = (hover.x-1)*cfg.TILE_SIZE
        local ty = (hover.y-1)*cfg.TILE_SIZE
        local valid = false
        local tool = ui.getActiveTool()
        if tool == cfg.TOOL_LAMP then
            valid = map.isWalkable(hover.x, hover.y) and game.familiarityResource >= cfg.LAMP_COST
        elseif tool == cfg.TOOL_ENTITY then
            valid = map.isWalkable(hover.x, hover.y) and game.uneaseResource >= cfg.ENTITY_COST
        elseif tool == cfg.TOOL_FOOD then
            valid = map.isWalkable(hover.x, hover.y) and game.familiarityResource >= cfg.FOOD_COST
        elseif tool == cfg.TOOL_BUILD then
            valid = map.isBuildable(hover.x, hover.y) and game.familiarityResource >= cfg.BUILD_COST_PER_TILE
        elseif tool == cfg.TOOL_REMOVE then
            valid = (map.grid[hover.y] and map.grid[hover.y][hover.x] == cfg.FLOOR)
        end
        local r, g, b = 1, 1, 1
        if not valid then r, g, b = 1, 0.3, 0.3 end
        love.graphics.setColor(r, g, b, 0.5)
        love.graphics.rectangle("fill", tx, ty, cfg.TILE_SIZE, cfg.TILE_SIZE)
        love.graphics.setColor(r, g, b, 0.9)
        love.graphics.rectangle("line", tx, ty, cfg.TILE_SIZE, cfg.TILE_SIZE)
    end

    for _, lamp in ipairs(game.comforts) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprites.lamp, lamp.x - 16, lamp.y - 16)
    end

    for _, ent in ipairs(game.entities) do
        love.graphics.setColor(cfg.COL_ENTITY_RADIUS)
        love.graphics.circle("line", ent.x, ent.y, ent.radius)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprites.entity, ent.x - 16, ent.y - 16)
    end

    for _, den in ipairs(game.denizens) do
        local col = den:getColor()
        love.graphics.setColor(col)
        love.graphics.draw(sprites.denizen, den.x - 16, den.y - 16)
        if den.state == "hiding" then
            love.graphics.setColor(1, 0.9, 0, 1)
            love.graphics.circle("fill", den.x, den.y - 18, 3)
            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.print("!", den.x - 4, den.y - 26)
            love.graphics.setColor(1, 1, 1, 1)
        end
    end

    for _, food in ipairs(game.foods) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprites.food, food.x - 16, food.y - 16)
    end

    for _, exitObj in ipairs(game.exits) do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprites.exit, exitObj.x - 16, exitObj.y - 16)
    end

    -- Corpses
    for _, corpse in ipairs(game.corpses) do
        love.graphics.setColor(0.5, 0.2, 0.2, 0.8)
        love.graphics.circle("fill", corpse.x, corpse.y, 6)
        love.graphics.setColor(0.8, 0.1, 0.1, 0.6)
        love.graphics.line(corpse.x-4, corpse.y-4, corpse.x+4, corpse.y+4)
        love.graphics.line(corpse.x+4, corpse.y-4, corpse.x-4, corpse.y+4)
    end

    local hovered = game.hoveredObject
    if hovered and hovered.data then
        local obj = hovered.data
        local s = 16
        love.graphics.setColor(1, 1, 0, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", obj.x - s, obj.y - s, s*2, s*2)
        love.graphics.setLineWidth(1)
    end

    camera.popTransform()

    -- Resource‑drop shards (screen space, subtle pulsing circles)
    for _, d in ipairs(effects.resourceDrops) do
        local alpha = d.life / d.maxLife
        local pulse = 1 + 0.3 * math.sin((1 - alpha) * 10 + d.phase)   -- gentle wobble
        local radius = 2 * pulse
        love.graphics.setColor(d.color[1], d.color[2], d.color[3], alpha * 0.7)
        love.graphics.circle("fill", d.x, d.y, radius)
    end
end

return draw