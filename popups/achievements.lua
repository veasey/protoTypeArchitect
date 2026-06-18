local PopupWindow = require("popups.popupwindow")

local achievements = PopupWindow.create({
    title = "Achievements",
    width = 500,
    height = 340,
    hasMaximize = false,
})
achievements.earned = {}
achievements.titles = {
    maxFamiliarity = "Blinding Comfort",
    maxDread = "Abyssal Dread",
    maxAnxiety = "Panic's Peak",
    perfectEquilibrium = "The Golden Mean",
}
achievements.descriptions = {
    maxFamiliarity = "Reach maximum Familiarity",
    maxDread = "Reach maximum Dread",
    maxAnxiety = "Reach maximum Unease",
    perfectEquilibrium = "Balance all resources for 60s",
}
achievements.notifications = {}
achievements.NOTIFICATION_DURATION = 5

function achievements.addNotification(text)
    table.insert(achievements.notifications, {
        text = text,
        timer = achievements.NOTIFICATION_DURATION,
        alpha = 1,
    })
end

function achievements.check(gameState)
    if not achievements.earned.maxFamiliarity and gameState.familiarity >= 0.99 then
        achievements.earned.maxFamiliarity = true
        achievements.addNotification("Achievement: Blinding Comfort")
    end
    if not achievements.earned.maxDread and gameState.dread >= 0.99 then
        achievements.earned.maxDread = true
        achievements.addNotification("Achievement: Abyssal Dread")
    end
    if not achievements.earned.maxAnxiety and gameState.unease >= 0.99 then
        achievements.earned.maxAnxiety = true
        achievements.addNotification("Achievement: Panic's Peak")
    end
    if not achievements.earned.perfectEquilibrium and (gameState.perfectEquilibriumTimer or 0) >= 60 then
        achievements.earned.perfectEquilibrium = true
        achievements.addNotification("Achievement: The Golden Mean")
    end
end

function achievements.update(dt)
    for i = #achievements.notifications, 1, -1 do
        local notif = achievements.notifications[i]
        notif.timer = notif.timer - dt
        if notif.timer <= 0 then
            table.remove(achievements.notifications, i)
        else
            notif.alpha = math.min(1, notif.timer / 1.5)
        end
    end
end

function achievements.drawNotifications()
    if #achievements.notifications == 0 then return end
    local maxWidth = 0
    for _, notif in ipairs(achievements.notifications) do
        local w = love.graphics.getFont():getWidth(notif.text)
        if w > maxWidth then maxWidth = w end
    end
    local boxW = maxWidth + 20
    local boxH = 20 + #achievements.notifications * 18
    local boxX = (1200 - 280) / 2 - boxW / 2
    local boxY = 50

    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", boxX, boxY, boxW, boxH)
    love.graphics.setColor(1, 1, 0, 0.5)
    love.graphics.rectangle("line", boxX, boxY, boxW, boxH)

    for i, notif in ipairs(achievements.notifications) do
        love.graphics.setColor(1, 1, 0, notif.alpha)
        love.graphics.print(notif.text, boxX + 10, boxY + 5 + (i-1)*18)
    end
end

function achievements.mousepressed(mx, my, button)
    if not mx or not my then return end
    if not achievements.open then return false end
    return PopupWindow.mousepressed(achievements, mx, my, button)
end

function achievements.mousereleased(mx, my, button)
    PopupWindow.mousereleased(achievements, mx, my, button)
end

function achievements.mousemoved(mx, my, dx, dy)
    PopupWindow.mousemoved(achievements, mx, my, dx, dy)
end

function achievements.draw()
    if not achievements.open then return end
    PopupWindow.drawBackground(achievements)

    local x, y, w, h = achievements.x, achievements.y, achievements.width, achievements.height
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

        love.graphics.setColor(earned and {0.15, 0.4, 0.15} or {0.25, 0.25, 0.25})
        love.graphics.rectangle("fill", bx, by, badgeW, badgeH)
        love.graphics.setColor(earned and {0.4, 0.8, 0.4} or {0.5, 0.5, 0.5})
        love.graphics.rectangle("line", bx, by, badgeW, badgeH)

        love.graphics.setColor(earned and {1, 1, 0.8} or {0.7, 0.7, 0.7})
        love.graphics.print(achievements.titles[key], bx+4, by+4)
        love.graphics.setColor(0.9, 0.9, 0.9)
        love.graphics.print(achievements.descriptions[key], bx+4, by+20)
        if earned then
            love.graphics.setColor(0.2, 1, 0.2)
            love.graphics.print("EARNED", bx+4, by+badgeH-16)
        end
    end
end

return achievements