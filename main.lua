local cfg     = require("config")
local game    = require("game")
local draw    = require("draw")
local ui      = require("ui")
local camera  = require("camera")
local sprites = require("sprites")
local postfx  = require("postfx")
local audio   = require("audio")

-- Audio
local buildSound

function love.load()
    love.window.setMode(cfg.WINDOW_WIDTH, cfg.WINDOW_HEIGHT, {resizable = false})
    love.math.setRandomSeed(os.time())
    sprites.load()
    postfx.load()
    audio.load()

    game.init()
    game.paused = false
end

function love.update(dt)
    local effectiveDt = game.paused and 0 or dt
    game.update(effectiveDt)
    
    audio.updateLampLoops(camera.x, camera.y, camera.zoom, cfg.GAME_WIDTH, cfg.WINDOW_HEIGHT)

    -- Update hovered object (for tooltips)
    local mx, my = love.mouse.getPosition()
    game.hoveredObject = game.getHoveredObject(mx, my, camera)
end

function love.keypressed(key)
    if key == "p" then
        game.togglePauseState()
    end
end

function love.draw()
    postfx.beginCapture()
    draw.world()
    ui.draw(game.getEfficiency(), #game.denizens)
    postfx.endCapture()
    postfx.apply(love.timer.getDelta())
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

-- Expose for other modules
function playBuildSound()
    if buildSound then
        buildSound:stop()
        buildSound:play()
    end
end

function stopBuildSound()
    if buildSound then
        buildSound:stop()
    end
end