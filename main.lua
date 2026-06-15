local cfg     = require("config")
local game    = require("game")
local audio    = require("audio")
local draw    = require("draw")
local ui      = require("ui")
local camera  = require("camera")
local sprites = require("sprites")
local postfx  = require("postfx")

function love.load()
    love.window.setMode(cfg.WINDOW_WIDTH, cfg.WINDOW_HEIGHT, {resizable = false})
    love.math.setRandomSeed(os.time())
    audio.load()
    sprites.load()
    postfx.load()
    game.init()
end

function love.update(dt)
    game.update(dt)
    local mx, my = love.mouse.getPosition()
    game.hoveredObject = game.getHoveredObject(mx, my, camera)
end

function love.draw()
    -- Game world (with CRT)
    love.graphics.setScissor(0, cfg.MENUBAR_HEIGHT, cfg.WINDOW_WIDTH, cfg.GAME_HEIGHT)
    postfx.beginCapture()
    draw.world()
    postfx.endCapture()
    love.graphics.setScissor(0, cfg.MENUBAR_HEIGHT, cfg.WINDOW_WIDTH, cfg.GAME_HEIGHT)
    postfx.apply(love.timer.getDelta())

    -- UI (crisp, no CRT)
    love.graphics.setScissor(0, 0, cfg.WINDOW_WIDTH, cfg.WINDOW_HEIGHT)
    ui.draw(game.getEfficiency(), #game.denizens)
    love.graphics.setScissor()
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