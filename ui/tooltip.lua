-- ui/tooltip.lua
local cfg = require("config")
local bevel = require("ui/bevel")

local tooltip = {}

function tooltip.draw(hovered, mouseX, mouseY)
    if not hovered then return end

    local tipW, tipH = 130, 96
    local tipX = mouseX + 16
    local tipY = mouseY + 16
    if tipX + tipW > cfg.GAME_WIDTH then tipX = mouseX - tipW - 16 end
    if tipY + tipH > cfg.GAME_HEIGHT then tipY = mouseY - tipH - 16 end

    love.graphics.setColor(cfg.COL_UI_BG)
    love.graphics.rectangle("fill", tipX, tipY, tipW, tipH)
    bevel.bevelBox(tipX, tipY, tipW, tipH, false)
    love.graphics.setColor(cfg.COL_UI_TEXT)

    if hovered.type == "entity" then
        local e = hovered.data
        love.graphics.print("Entity", tipX+4, tipY+4)
        love.graphics.print("State: " .. (e.state or "?"), tipX+4, tipY+18)
        love.graphics.print(string.format("Spd:%.0f Rad:%.0f", e.speed, e.radius), tipX+4, tipY+32)
        love.graphics.print(string.format("Desp/s:%.2f Agg:%.2f", e.despairPerSec, e.aggression), tipX+4, tipY+46)
    elseif hovered.type == "denizen" then
        local d = hovered.data
        love.graphics.print(d.name, tipX+4, tipY+4)
        love.graphics.print("State: " .. d.state, tipX+4, tipY+18)
        love.graphics.print(string.format("Desp:%.2f Anx:%.2f", d.profile.despair, d.profile.anxiety), tipX+4, tipY+32)
        love.graphics.print(string.format("Speed:%.0f", d.profile.speed), tipX+4, tipY+46)
    elseif hovered.type == "food" then
        love.graphics.print("Food", tipX+4, tipY+4)
    elseif hovered.type == "exit" then
        love.graphics.print("Exit", tipX+4, tipY+4)
    elseif hovered.type == "corpse" then
        love.graphics.print("Corpse", tipX+4, tipY+4)
    end
end

return tooltip