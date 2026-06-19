-- ui/bevel.lua
local cfg = require("config")

local bevel = {}

function bevel.bevelBox(x, y, w, h, sunken)
    love.graphics.setColor(sunken and cfg.COL_UI_BEVEL_LO or cfg.COL_UI_BEVEL_HI)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(sunken and cfg.COL_UI_BEVEL_HI or cfg.COL_UI_BEVEL_LO)
    love.graphics.line(x+w-1, y, x+w-1, y+h-1)
    love.graphics.line(x, y+h-1, x+w-1, y+h-1)
end

function bevel.bevelButton(x, y, w, h, text, active)
    love.graphics.setColor(active and cfg.COL_UI_BUTTON_HI or cfg.COL_UI_BUTTON)
    love.graphics.rectangle("fill", x, y, w, h)
    bevel.bevelBox(x, y, w, h, active)
    love.graphics.setColor(cfg.COL_UI_TEXT)
    local tw = love.graphics.getFont():getWidth(text)
    local th = love.graphics.getFont():getHeight()
    love.graphics.print(text, x + (w - tw)/2, y + (h - th)/2)
end

return bevel