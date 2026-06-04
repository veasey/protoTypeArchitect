local cfg     = require("config")
local game    = require("game")
local draw    = require("draw")
local ui      = require("ui")
local camera  = require("camera")
local sprites = require("sprites")   -- new

function love.load()
    love.window.setMode(cfg.WINDOW_WIDTH, cfg.WINDOW_HEIGHT, {resizable = false})
    love.math.setRandomSeed(os.time())
    sprites.load()   -- generate textures
    game.init()
end

function love.update(dt)
    game.update(dt)
end

function love.draw()
    draw.world()
    ui.draw(game.getEfficiency(), #game.denizens)
end

function love.mousepressed(x, y, button, istouch, presses)
    ui.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button, istouch, presses)
    ui.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy, istouch)
    ui.mousemoved(x, y, dx, dy)
end

function love.wheelmoved(x, y)
    ui.wheelmoved(x, y)
end