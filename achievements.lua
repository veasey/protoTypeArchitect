-- achievements.lua
local achievements = {
    open = false,
    x = 100, y = 100,
    width = 500, height = 340,
    dragging = false, dragOffX = 0, dragOffY = 0,
    earned = {},
    titles = {
        maxFamiliarity = "Blinding Comfort",
        maxDread = "Abyssal Dread",
        maxAnxiety = "Panic's Peak",
        perfectEquilibrium = "The Golden Mean",
    },
    descriptions = {
        maxFamiliarity = "Reach maximum Familiarity",
        maxDread = "Reach maximum Dread",
        maxAnxiety = "Reach maximum Unease",
        perfectEquilibrium = "Balance all resources for 60s",
    },
}

function achievements.check(gameState)
    if not achievements.earned.maxFamiliarity and gameState.familiarity >= 0.99 then
        achievements.earned.maxFamiliarity = true
    end
    if not achievements.earned.maxDread and gameState.dread >= 0.99 then
        achievements.earned.maxDread = true
    end
    if not achievements.earned.maxAnxiety and gameState.unease >= 0.99 then
        achievements.earned.maxAnxiety = true
    end
    if not achievements.earned.perfectEquilibrium and (gameState.perfectEquilibriumTimer or 0) >= 60 then
        achievements.earned.perfectEquilibrium = true
    end
end

function achievements.mousepressed(mx, my, button)
    if not mx or not my then return end
    if not achievements.open then return end
    -- close button
    if mx >= achievements.x + achievements.width - 20 and mx <= achievements.x + achievements.width - 5
       and my >= achievements.y + 5 and my <= achievements.y + 20 then
        achievements.open = false
        return true
    end
    -- title bar drag
    if my <= achievements.y + 20 then
        achievements.dragging = true
        achievements.dragOffX = mx - achievements.x
        achievements.dragOffY = my - achievements.y
        return true
    end
    return true
end

function achievements.mousereleased(mx, my, button)
    achievements.dragging = false
end

function achievements.mousemoved(mx, my, dx, dy)
    if achievements.dragging then
        achievements.x = mx - achievements.dragOffX
        achievements.y = my - achievements.dragOffY
    end
end

function achievements.draw()
    if not achievements.open then return end
    local x, y, w, h = achievements.x, achievements.y, achievements.width, achievements.height
    -- translucent background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.6, 0.6, 0.6, 0.9)
    love.graphics.rectangle("line", x, y, w, h)
    -- title bar
    love.graphics.setColor(0.3, 0.3, 0.3, 0.9)
    love.graphics.rectangle("fill", x, y, w, 20)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Achievements", x+5, y+3)
    -- close button
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", x+w-20, y+5, 15, 12)
    love.graphics.print("X", x+w-17, y+4)

    -- badges in a 2x2 grid
    local badgeW = (w - 30) / 2
    local badgeH = (h - 40) / 2
    local startX = x + 10
    local startY = y + 25
    local keys = {"maxFamiliarity", "maxDread", "maxAnxiety", "perfectEquilibrium"}
    for i, key in ipairs(keys) do
        local col = (i - 1) % 2
        local row = math.floor((i - 1) / 2)
        local bx = startX + col * (badgeW + 10)
        local by = startY + row * (badgeH + 10)
        local earned = achievements.earned[key] or false

        -- badge background
        love.graphics.setColor(earned and {0.15, 0.4, 0.15} or {0.25, 0.25, 0.25})
        love.graphics.rectangle("fill", bx, by, badgeW, badgeH)
        love.graphics.setColor(earned and {0.4, 0.8, 0.4} or {0.5, 0.5, 0.5})
        love.graphics.rectangle("line", bx, by, badgeW, badgeH)

        -- title
        love.graphics.setColor(earned and {1, 1, 0.8} or {0.7, 0.7, 0.7})
        love.graphics.print(achievements.titles[key], bx+4, by+4)
        -- description
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(achievements.descriptions[key], bx+4, by+20)
        -- status
        if earned then
            love.graphics.setColor(0.2, 1, 0.2)
            love.graphics.print("EARNED", bx+4, by+badgeH-16)
        end
    end
end

return achievements