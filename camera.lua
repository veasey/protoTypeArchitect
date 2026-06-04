local cfg = require("config")

local camera = {
    x = cfg.WORLD_WIDTH / 2,
    y = cfg.WORLD_HEIGHT / 2,
    zoom = 1,
}

function camera.applyTransform()
    love.graphics.push()
    love.graphics.translate(cfg.GAME_WIDTH / 2, cfg.WINDOW_HEIGHT / 2)
    love.graphics.scale(camera.zoom)
    love.graphics.translate(-camera.x, -camera.y)
end

function camera.popTransform()
    love.graphics.pop()
end

-- Convert screen coordinates to world coordinates
function camera.screenToWorld(sx, sy)
    local wx = (sx - cfg.GAME_WIDTH / 2) / camera.zoom + camera.x
    local wy = (sy - cfg.WINDOW_HEIGHT / 2) / camera.zoom + camera.y
    return wx, wy
end

return camera