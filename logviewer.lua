-- logviewer.lua
local logviewer = {}
logviewer.open = false
logviewer.x = 50
logviewer.y = 50
logviewer.width = 600
logviewer.height = 400
logviewer.scrollY = 0
logviewer.selectedIndex = nil
logviewer.maximized = false
logviewer.dragging = false
logviewer.dragOffX = 0
logviewer.dragOffY = 0
logviewer.viewMode = "live"   -- "live" or "records"

local function clampToGameArea()
    local maxX = 1200 - 280 - logviewer.width
    local maxY = 800 - 28 - logviewer.height
    logviewer.x = math.max(0, math.min(logviewer.x, maxX))
    logviewer.y = math.max(0, math.min(logviewer.y, maxY))
end

function logviewer.isInside(mx, my)
    return mx >= logviewer.x and mx <= logviewer.x + logviewer.width
       and my >= logviewer.y and my <= logviewer.y + logviewer.height
end

function logviewer.mousepressed(mx, my, button)
    if not logviewer.open then return end
    -- close button
    if mx >= logviewer.x + logviewer.width - 20 and mx <= logviewer.x + logviewer.width - 5
       and my >= logviewer.y + 5 and my <= logviewer.y + 20 then
        logviewer.open = false
        return
    end
    -- maximize button
    if mx >= logviewer.x + logviewer.width - 40 and mx <= logviewer.x + logviewer.width - 25
       and my >= logviewer.y + 5 and my <= logviewer.y + 20 then
        logviewer.maximized = not logviewer.maximized
        if logviewer.maximized then
            logviewer.x = 0
            logviewer.y = 0
            logviewer.width = 1200 - 280
            logviewer.height = 800 - 28
        else
            logviewer.width = 600
            logviewer.height = 400
            logviewer.x = 50
            logviewer.y = 50
            clampToGameArea()
        end
        return
    end
    -- toggle view mode button
    if mx >= logviewer.x + logviewer.width - 80 and mx <= logviewer.x + logviewer.width - 45
       and my >= logviewer.y + 5 and my <= logviewer.y + 20 then
        logviewer.viewMode = (logviewer.viewMode == "live") and "records" or "live"
        logviewer.selectedIndex = nil
        return
    end
    -- title bar drag
    if my <= logviewer.y + 20 then
        logviewer.dragging = true
        logviewer.dragOffX = mx - logviewer.x
        logviewer.dragOffY = my - logviewer.y
        return
    end
    -- content area clicks
    local logger = require("logger")
    local lineH = 16
    local y = logviewer.y + 30 - logviewer.scrollY
    if logviewer.viewMode == "records" then
        for i, rec in ipairs(logger.records) do
            local line = rec.type .. ": " .. (rec.name or rec.state) .. " - " .. rec.cause
            if my >= y and my < y + lineH then
                logviewer.selectedIndex = i
                return
            end
            y = y + lineH
            if logviewer.selectedIndex == i then
                for _, ev in ipairs(rec.events) do
                    y = y + lineH
                end
            end
        end
    end
end

function logviewer.mousereleased(mx, my, button)
    logviewer.dragging = false
end

function logviewer.mousemoved(mx, my, dx, dy)
    if logviewer.dragging then
        logviewer.x = mx - logviewer.dragOffX
        logviewer.y = my - logviewer.dragOffY
        clampToGameArea()
    end
end

function logviewer.wheelmoved(x, y)
    if not logviewer.open then return end
    logviewer.scrollY = math.max(0, logviewer.scrollY + y * 20)
end

function logviewer.draw()
    if not logviewer.open then return end
    local x, y, w, h = logviewer.x, logviewer.y, logviewer.width, logviewer.height
    -- translucent background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.6, 0.6, 0.6, 0.9)
    love.graphics.rectangle("line", x, y, w, h)
    -- title bar
    love.graphics.setColor(0.3, 0.3, 0.3, 0.9)
    love.graphics.rectangle("fill", x, y, w, 20)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("Log Viewer", x+5, y+3)
    -- close / maximize / view toggle buttons
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", x+w-20, y+5, 15, 12)
    love.graphics.print("X", x+w-17, y+4)
    love.graphics.setColor(0.5, 0.5, 0.5)
    love.graphics.rectangle("fill", x+w-40, y+5, 15, 12)
    love.graphics.print("[]", x+w-38, y+4)
    -- View mode toggle
    love.graphics.setColor(0.4, 0.4, 0.6)
    love.graphics.rectangle("fill", x+w-80, y+5, 35, 12)
    love.graphics.setColor(1,1,1)
    love.graphics.print(logviewer.viewMode == "live" and "Live" or "Recs", x+w-78, y+4)

    love.graphics.setScissor(x, y+20, w, h-20)
    love.graphics.setColor(1, 1, 1)
    local logger = require("logger")
    local lineH = 16
    local cy = y + 25 - logviewer.scrollY

    if logviewer.viewMode == "live" then
        -- Display live entries from logger.liveEntries
        local entries = logger.liveEntries
        for i = #entries, 1, -1 do  -- newest first
            local entry = entries[i]
            local line = entry.time .. " " .. entry.name .. ": " .. entry.event
            love.graphics.print(line, x+5, cy)
            cy = cy + lineH
        end
    else
        -- Display completed records
        for i, rec in ipairs(logger.records) do
            local line = rec.type .. ": " .. (rec.name or rec.state) .. " - " .. rec.cause
            local textColor = (logviewer.selectedIndex == i) and {1, 1, 0} or {1, 1, 1}
            love.graphics.setColor(textColor)
            love.graphics.print(line, x+5, cy)
            cy = cy + lineH
            if logviewer.selectedIndex == i then
                for _, ev in ipairs(rec.events) do
                    love.graphics.print("    " .. ev, x+5, cy)
                    cy = cy + lineH
                end
            end
        end
    end
    love.graphics.setScissor()
end

return logviewer