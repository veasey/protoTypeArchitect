-- Generates all game sprites as Love2D Images using Canvases.
-- This keeps the prototype self‑contained and makes future
-- asset‑swapping trivial.

local sprites = {}

local function createFloorTile()
    local canvas = love.graphics.newCanvas(32, 32)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    for x = 0, 31 do
        for y = 0, 31 do
            local shade = 0.75 + (love.math.noise(x/8, y/8) * 0.1)
            love.graphics.setColor(shade, shade * 0.9, shade * 0.7)
            love.graphics.points(x, y)
        end
    end
    love.graphics.setColor(0.6, 0.55, 0.45)
    for i = 0, 31, 8 do
        love.graphics.line(0, i, 31, i)
    end
    love.graphics.setCanvas()
    return canvas
end

local function createWallTile()
    local canvas = love.graphics.newCanvas(32, 32)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    love.graphics.setColor(0.3, 0.25, 0.2)
    love.graphics.rectangle("fill", 0, 0, 32, 32)
    love.graphics.setColor(0.25, 0.2, 0.15)
    for x = 8, 31, 8 do
        love.graphics.line(x, 0, x, 31)
    end
    love.graphics.setColor(0.4, 0.35, 0.1, 0.3)
    love.graphics.circle("fill", 20, 10, 6)
    love.graphics.setCanvas()
    return canvas
end

local function createDenizenFallback()
    local canvas = love.graphics.newCanvas(32, 32)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    love.graphics.setColor(0.7, 0.8, 0.9)
    love.graphics.circle("fill", 16, 8, 4)
    love.graphics.line(16, 12, 16, 22)
    love.graphics.line(16, 14, 10, 20)
    love.graphics.line(16, 14, 22, 20)
    love.graphics.line(16, 22, 10, 30)
    love.graphics.line(16, 22, 22, 30)
    love.graphics.setCanvas()
    return canvas
end

local function createLampSprite()
    local canvas = love.graphics.newCanvas(32, 32)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    -- Glowing orb
    love.graphics.setColor(0.95, 0.9, 0.4, 0.5)
    love.graphics.rectangle("fill", 12, 7, 5, 18)
    -- Soft halo
    for r = 7, 12 do
        love.graphics.setColor(0.95, 0.9, 0.4, 0.1)
        love.graphics.rectangle("fill", 12, 7, 6, 19)
    end
    love.graphics.setCanvas()
    return canvas
end

local function createEntitySprite()
    local canvas = love.graphics.newCanvas(32, 32)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    -- Shadowy form
    love.graphics.setColor(0.3, 0.2, 0.4, 0.9)
    love.graphics.ellipse("fill", 16, 20, 8, 12)
    love.graphics.circle("fill", 16, 8, 5)
    -- Dark tendrils
    love.graphics.setColor(0.2, 0.1, 0.3, 0.8)
    love.graphics.line(16, 8, 6, 2)
    love.graphics.line(16, 8, 26, 2)
    love.graphics.setCanvas()
    return canvas
end

local function createFoodSprite()
    local canvas = love.graphics.newCanvas(32, 32)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    -- A small can or box
    love.graphics.setColor(0.5, 0.3, 0.2)
    love.graphics.rectangle("fill", 10, 12, 12, 10)
    love.graphics.setColor(0.6, 0.4, 0.1)
    love.graphics.rectangle("fill", 12, 10, 8, 4)
    love.graphics.setColor(0.4, 0.2, 0.1)
    love.graphics.rectangle("fill", 14, 8, 4, 4)
    -- A simple "FOOD" line
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.line(14, 16, 18, 16)
    love.graphics.line(16, 14, 16, 18)
    love.graphics.setCanvas()
    return canvas
end

local function createExitSprite()
    local canvas = love.graphics.newCanvas(32, 32)
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
    -- Glowing doorway
    love.graphics.setColor(0.2, 0.6, 0.9, 0.6)
    love.graphics.rectangle("fill", 8, 4, 16, 24)
    love.graphics.setColor(0.3, 0.7, 1.0)
    love.graphics.rectangle("line", 8, 4, 16, 24)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 16, 16, 4)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.line(16, 4, 16, 28)   -- vertical centre line
    love.graphics.setCanvas()
    return canvas
end

function sprites.load()
    sprites.floor   = createFloorTile()
    sprites.wall    = createWallTile()
    sprites.lamp    = createLampSprite()
    sprites.entity  = createEntitySprite()
    sprites.food    = createFoodSprite()
    sprites.exit    = createExitSprite()

    -- Load custom denizen PNG, fallback to procedural if missing
    local denizenFile = "sprites/denizen.png"
    if love.filesystem.getInfo(denizenFile) then
        sprites.denizen = love.graphics.newImage(denizenFile)
    else
        sprites.denizen = createDenizenFallback()
        print("denizen.png not found, using fallback stick figure.")
    end
end

return sprites