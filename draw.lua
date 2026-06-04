local cfg    = require("config")
local map    = require("map")
local camera = require("camera")
local game   = require("game")
local sprites = require("sprites")

local draw = {}

function draw.world()
    camera.applyTransform()

    local invZoom = 1 / camera.zoom
    local left  = math.max(1, math.floor((camera.x - cfg.GAME_WIDTH/2 * invZoom) / cfg.TILE_SIZE))
    local right = math.min(cfg.MAP_COLS, math.ceil((camera.x + cfg.GAME_WIDTH/2 * invZoom) / cfg.TILE_SIZE))
    local top   = math.max(1, math.floor((camera.y - cfg.WINDOW_HEIGHT/2 * invZoom) / cfg.TILE_SIZE))
    local bottom = math.min(cfg.MAP_ROWS, math.ceil((camera.y + cfg.WINDOW_HEIGHT/2 * invZoom) / cfg.TILE_SIZE))

    -- Draw tiles
    for r = top, bottom do
        for c = left, right do
            local tile = map.grid[r][c]
            local tx = (c-1) * cfg.TILE_SIZE
            local ty = (r-1) * cfg.TILE_SIZE
            if tile == cfg.VOID then
                -- Deep darkness with subtle grain
                love.graphics.setColor(cfg.COL_VOID)
                love.graphics.rectangle("fill", tx, ty, cfg.TILE_SIZE, cfg.TILE_SIZE)
                -- Optional: faint star-like noise (costly, so use sparingly)
                if love.math.random() < 0.1 then
                    love.graphics.setColor(0.1, 0.1, 0.15)
                    love.graphics.points(tx + love.math.random(32), ty + love.math.random(32))
                end
            else
                love.graphics.setColor(1, 1, 1)
                love.graphics.draw(sprites.floor, tx, ty)
            end
        end
    end

    -- Comfort lamps
    for _, lamp in ipairs(game.comforts) do
        love.graphics.draw(sprites.lamp, lamp.x - 16, lamp.y - 16)
    end

    -- Entities
    for _, ent in ipairs(game.entities) do
        love.graphics.setColor(cfg.COL_ENTITY_RADIUS)
        love.graphics.circle("line", ent.x, ent.y, ent.radius)
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(sprites.entity, ent.x - 16, ent.y - 16)
    end

    -- Denizens
    for _, den in ipairs(game.denizens) do
        local col = den:getColor()
        love.graphics.setColor(col)
        love.graphics.draw(sprites.denizen, den.x - 16, den.y - 16)
        love.graphics.setColor(1, 1, 1)
    end

    camera.popTransform()
end

return draw