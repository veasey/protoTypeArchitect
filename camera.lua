-- camera.lua
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

-- ============================================================
--  RTS‑style panning (keyboard + edge scrolling)
-- ============================================================
function camera.update(dt, mx, my, popupOpen)
    -- Keyboard panning (WASD / Arrows)
    local panSpeed = cfg.CAM_PAN_SPEED * dt
    if love.keyboard.isDown("w") or love.keyboard.isDown("up") then
        camera.y = camera.y - panSpeed
    end
    if love.keyboard.isDown("s") or love.keyboard.isDown("down") then
        camera.y = camera.y + panSpeed
    end
    if love.keyboard.isDown("a") or love.keyboard.isDown("left") then
        camera.x = camera.x - panSpeed
    end
    if love.keyboard.isDown("d") or love.keyboard.isDown("right") then
        camera.x = camera.x + panSpeed
    end

    -- Edge scrolling (only when mouse is inside the game area and no popup is open)
    if not popupOpen
       and mx > 0 and mx < cfg.GAME_WIDTH
       and my > cfg.MENUBAR_HEIGHT and my < cfg.GAME_HEIGHT + cfg.MENUBAR_HEIGHT then
        local edgeSpeed = cfg.EDGE_SCROLL_SPEED * dt
        if mx < cfg.EDGE_ZONE then
            camera.x = camera.x - edgeSpeed
        elseif mx > cfg.GAME_WIDTH - cfg.EDGE_ZONE then
            camera.x = camera.x + edgeSpeed
        end
        if my < cfg.MENUBAR_HEIGHT + cfg.EDGE_ZONE then
            camera.y = camera.y - edgeSpeed
        elseif my > cfg.GAME_HEIGHT + cfg.MENUBAR_HEIGHT - cfg.EDGE_ZONE then
            camera.y = camera.y + edgeSpeed
        end
    end

    -- Optional: clamp to world bounds (uncomment if you want to prevent looking at void)
    -- camera.x = math.max(0, math.min(cfg.WORLD_WIDTH, camera.x))
    -- camera.y = math.max(0, math.min(cfg.WORLD_HEIGHT, camera.y))
end

return camera