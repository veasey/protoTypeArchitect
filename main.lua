local cfg     = require("config")
local game    = require("game")
local draw    = require("draw")
local ui      = require("ui")
local camera  = require("camera")
local sprites = require("sprites")
local postfx  = require("postfx")
local logviewer = require("popups.logviewer")
local achievements = require("popups.achievements")
local about = require("popups.about")

function love.load()
    love.window.setMode(cfg.WINDOW_WIDTH, cfg.WINDOW_HEIGHT, {resizable = false})
    love.math.setRandomSeed(os.time())
    sprites.load()
    postfx.load()
    game.init()
end

function love.update(dt)
    game.update(dt)
    local mx, my = love.mouse.getPosition()
    game.hoveredObject = game.getHoveredObject(mx, my, camera)
    achievements.update(dt)
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
    logviewer.draw()
    achievements.draw()
    about.draw()
    achievements.drawNotifications()
    love.graphics.setScissor()
end

function love.mousepressed(x, y, button)
    if logviewer.open and logviewer:isInside(x, y) then
        logviewer.mousepressed(x, y, button)
        return
    end
    if achievements.open and achievements:isInside(x, y) then
        achievements.mousepressed(x, y, button)
        return
    end
    if about.open and about:isInside(x, y) then
        about.mousepressed(x, y, button)
        return
    end
    ui.mousepressed(x, y, button)
end

function love.mousereleased(x, y, button)
    if logviewer.open then
        logviewer.mousereleased(x, y, button)
    end
    if achievements.open then
        achievements.mousereleased(x, y, button)
    end
    if about.open then
        about.mousereleased(x, y, button)
    end
    ui.mousereleased(x, y, button)
end

function love.mousemoved(x, y, dx, dy)
    if logviewer.open then
        logviewer.mousemoved(x, y, dx, dy)
    end
    if achievements.open then
        achievements.mousemoved(x, y, dx, dy)
    end
    if about.open then
        about.mousemoved(x, y, dx, dy)
    end
    ui.mousemoved(x, y, dx, dy)
end

function love.wheelmoved(x, y)
    if logviewer.open then
        logviewer.wheelmoved(x, y)
        return
    end
    if about.open then
        about.wheelmoved(x, y)
        return
    end
    if achievements.open then
        achievements.wheelmoved(x, y)
        return
    end
    ui.wheelmoved(x, y)
end

function love.keypressed(key)
    if key == "p" or key == "pause" then
        game.togglePauseState()
    elseif key == "l" then
        logviewer.open = not logviewer.open
    elseif key == "a" then
        achievements.open = not achievements.open
    elseif key == "f5" then
        game.save()
    elseif key == "f6" then
        game.load()
    end
end