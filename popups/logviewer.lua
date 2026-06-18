local PopupWindow = require("popups.popupwindow")
local logger = require("logger")

local logviewer = PopupWindow.create({
    title = "Log Viewer",
    width = 600,
    height = 400,
    hasMaximize = true,
})
logviewer.scrollY = 0
logviewer.selectedIndex = nil
logviewer.viewMode = "live"   -- "live" or "records"

function logviewer.mousepressed(mx, my, button)
    if not logviewer.open then return false end
    -- let the base handle close/maximize/drag
    local handled = PopupWindow.mousepressed(logviewer, mx, my, button)
    if handled then return true end

    -- toggle view mode button (bottom of title bar area)
    if mx >= logviewer.x + logviewer.width - 80 and mx <= logviewer.x + logviewer.width - 45
       and my >= logviewer.y + 5 and my <= logviewer.y + 20 then
        logviewer.viewMode = (logviewer.viewMode == "live") and "records" or "live"
        logviewer.selectedIndex = nil
        return true
    end

    -- content clicks (records only)
    local lineH = 16
    local y = logviewer.y + 30 - logviewer.scrollY
    if logviewer.viewMode == "records" then
        for i, rec in ipairs(logger.records) do
            local line = rec.type .. ": " .. (rec.name or rec.state) .. " - " .. rec.cause
            if my >= y and my < y + lineH then
                logviewer.selectedIndex = i
                return true
            end
            y = y + lineH
            if logviewer.selectedIndex == i then
                for _ in ipairs(rec.events) do y = y + lineH end
            end
        end
    end
    return true
end

function logviewer.mousereleased(mx, my, button)
    PopupWindow.mousereleased(logviewer, mx, my, button)
end

function logviewer.mousemoved(mx, my, dx, dy)
    PopupWindow.mousemoved(logviewer, mx, my, dx, dy)
end

function logviewer.wheelmoved(x, y)
    if not logviewer.open then return end
    logviewer.scrollY = math.max(0, logviewer.scrollY + y * 20)
end

function logviewer.draw()
    if not logviewer.open then return end
    PopupWindow.drawBackground(logviewer)

    local x, y, w, h = logviewer.x, logviewer.y, logviewer.width, logviewer.height

    -- view mode button
    love.graphics.setColor(0.4, 0.4, 0.6)
    love.graphics.rectangle("fill", x+w-80, y+5, 35, 12)
    love.graphics.setColor(1,1,1)
    love.graphics.print(logviewer.viewMode == "live" and "Live" or "Recs", x+w-78, y+4)

    love.graphics.setScissor(x, y+20, w, h-20)
    love.graphics.setColor(1, 1, 1)
    local lineH = 16
    local cy = y + 25 - logviewer.scrollY

    if logviewer.viewMode == "live" then
        local entries = logger.liveEntries or {}
        for i = #entries, 1, -1 do
            local entry = entries[i]
            love.graphics.print(entry.time .. " " .. entry.name .. ": " .. entry.event, x+5, cy)
            cy = cy + lineH
        end
    else
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