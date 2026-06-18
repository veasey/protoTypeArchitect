-- popupwindow.lua
-- Base class for draggable, translucent windows.

local PopupWindow = {}
PopupWindow.__index = PopupWindow

function PopupWindow.create(params)
    local self = setmetatable({}, PopupWindow)
    self.open = params.open or false
    self.x = params.x or 100
    self.y = params.y or 100
    self.width = params.width or 400
    self.height = params.height or 300
    self.title = params.title or "Window"
    self.dragging = false
    self.dragOffX = 0
    self.dragOffY = 0
    self.maximized = params.maximized or false
    self.maximizedWidth = params.maximizedWidth or 920   -- 1200-280
    self.maximizedHeight = params.maximizedHeight or 772 -- 800-28
    self.normalWidth = self.width
    self.normalHeight = self.height
    self.normalX = self.x
    self.normalY = self.y
    self.hasMaximize = params.hasMaximize or false
    return self
end

function PopupWindow:isInside(mx, my)
    return mx >= self.x and mx <= self.x + self.width
       and my >= self.y and my <= self.y + self.height
end

function PopupWindow:clampToGameArea()
    local maxX = 1200 - 280 - self.width
    local maxY = 800 - 28 - self.height
    self.x = math.max(0, math.min(self.x, maxX))
    self.y = math.max(0, math.min(self.y, maxY))
end

function PopupWindow:mousepressed(mx, my, button)
    if not self.open then return false end
    -- close button
    if mx >= self.x + self.width - 20 and mx <= self.x + self.width - 5
       and my >= self.y + 5 and my <= self.y + 20 then
        self.open = false
        return true
    end
    -- maximize button (if present)
    if self.hasMaximize
       and mx >= self.x + self.width - 40 and mx <= self.x + self.width - 25
       and my >= self.y + 5 and my <= self.y + 20 then
        self:toggleMaximize()
        return true
    end
    -- title bar drag
    if my <= self.y + 20 then
        self.dragging = true
        self.dragOffX = mx - self.x
        self.dragOffY = my - self.y
        return true
    end
    return false
end

function PopupWindow:mousereleased(mx, my, button)
    self.dragging = false
end

function PopupWindow:mousemoved(mx, my, dx, dy)
    if self.dragging then
        self.x = mx - self.dragOffX
        self.y = my - self.dragOffY
        self:clampToGameArea()
    end
end

function PopupWindow:toggleMaximize()
    if not self.hasMaximize then return end
    if self.maximized then
        -- restore
        self.x = self.normalX
        self.y = self.normalY
        self.width = self.normalWidth
        self.height = self.normalHeight
        self.maximized = false
    else
        -- store current size and position
        self.normalX = self.x
        self.normalY = self.y
        self.normalWidth = self.width
        self.normalHeight = self.height
        self.x = 0
        self.y = 0
        self.width = self.maximizedWidth
        self.height = self.maximizedHeight
        self.maximized = true
    end
end

function PopupWindow:drawBackground()
    if not self.open then return end
    local x, y, w, h = self.x, self.y, self.width, self.height
    -- translucent background
    love.graphics.setColor(0.1, 0.1, 0.1, 0.85)
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.6, 0.6, 0.6, 0.9)
    love.graphics.rectangle("line", x, y, w, h)
    -- title bar
    love.graphics.setColor(0.3, 0.3, 0.3, 0.9)
    love.graphics.rectangle("fill", x, y, w, 20)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(self.title, x+5, y+3)
    -- close button
    love.graphics.setColor(0.8, 0.2, 0.2)
    love.graphics.rectangle("fill", x+w-20, y+5, 15, 12)
    love.graphics.print("X", x+w-17, y+4)
    -- maximize button (if enabled)
    if self.hasMaximize then
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("fill", x+w-40, y+5, 15, 12)
        love.graphics.print("[]", x+w-38, y+4)
    end
end

return PopupWindow