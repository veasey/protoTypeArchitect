local PopupWindow = require("popups.popupwindow")

local about = PopupWindow.create({
    title = "About",
    width = 400,
    height = 250,
    hasMaximize = false,
})

function about.mousepressed(mx, my, button)
    if not about.open then return false end
    return PopupWindow.mousepressed(about, mx, my, button)
end

function about.mousereleased(mx, my, button)
    PopupWindow.mousereleased(about, mx, my, button)
end

function about.mousemoved(mx, my, dx, dy)
    PopupWindow.mousemoved(about, mx, my, dx, dy)
end

function about.draw()
    if not about.open then return end
    PopupWindow.drawBackground(about)

    local x, y, w, h = about.x, about.y, about.width, about.height
    love.graphics.setScissor(x, y+20, w, h-20)
    love.graphics.setColor(1, 1, 1)
    local lines = {
        "Backrooms Architect",
        "Version: 0.1.0 (Early Prototype)",
        " ",
        "Hotkeys:",
        "P / PAUSE   - Pause / Resume",
        "L           - Open Log Viewer",
        "M           - Open Achievements",
        "F5          - Save game",
        "F6          - Load game",
        " ",
        "A backrooms management sim developed by Clint Veasey.", 
        "",
        "Inspired by the backrooms creepypasta.",
        "",
        "If you have any questions, comments, or suggestions",
        "please reach out to me within a shared dreamstate of",
        "liminal horror.",
    }
    local lineH = 16
    local cy = y + 25
    for _, line in ipairs(lines) do
        love.graphics.print(line, x+10, cy)
        cy = cy + lineH
    end
    love.graphics.setScissor()
end

return about