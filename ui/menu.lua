-- ui/menu.lua
local cfg = require("config")
local bevel = require("ui/bevel")

local menu = {}

function menu.draw(menuOpen, viewMenuOpen, mouseX, mouseY)
    love.graphics.setColor(cfg.COL_UI_BG)
    love.graphics.rectangle("fill", 0, 0, cfg.WINDOW_WIDTH, cfg.MENUBAR_HEIGHT)
    bevel.bevelBox(0, 0, cfg.WINDOW_WIDTH, cfg.MENUBAR_HEIGHT, true)

    local fileBtnX = 5
    local fileBtnW = 50
    local fileBtnH = cfg.MENUBAR_HEIGHT - 2
    bevel.bevelButton(fileBtnX, 1, fileBtnW, fileBtnH, "File", menuOpen)

    local viewBtnX = 55
    local viewBtnW = 50
    bevel.bevelButton(viewBtnX, 1, viewBtnW, fileBtnH, "View", viewMenuOpen)

    -- File dropdown
    if menuOpen then
        local dropdownX = fileBtnX
        local dropdownY = cfg.MENUBAR_HEIGHT
        local dropdownW = 120
        local itemH = 20
        local items = {"Save", "Load", "Exit"}
        love.graphics.setColor(cfg.COL_UI_BG)
        love.graphics.rectangle("fill", dropdownX, dropdownY, dropdownW, itemH * #items)
        bevel.bevelBox(dropdownX, dropdownY, dropdownW, itemH * #items, false)
        for i, item in ipairs(items) do
            local iy = dropdownY + (i-1) * itemH
            local hover = mouseX >= dropdownX and mouseX <= dropdownX + dropdownW
                         and mouseY >= iy and mouseY <= iy + itemH
            love.graphics.setColor(hover and cfg.COL_UI_BUTTON_HI or cfg.COL_UI_BUTTON)
            love.graphics.rectangle("fill", dropdownX+2, iy+1, dropdownW-4, itemH-2)
            love.graphics.setColor(cfg.COL_UI_TEXT)
            love.graphics.print(item, dropdownX+6, iy+3)
        end
    end

    -- View dropdown
    if viewMenuOpen then
        local dropdownX = viewBtnX
        local dropdownY = cfg.MENUBAR_HEIGHT
        local dropdownW = 120
        local itemH = 20
        local items = {"Log", "Achievements", "About"}
        love.graphics.setColor(cfg.COL_UI_BG)
        love.graphics.rectangle("fill", dropdownX, dropdownY, dropdownW, itemH * #items)
        bevel.bevelBox(dropdownX, dropdownY, dropdownW, itemH * #items, false)
        for i, item in ipairs(items) do
            local iy = dropdownY + (i-1) * itemH
            local hover = mouseX >= dropdownX and mouseX <= dropdownX + dropdownW
                         and mouseY >= iy and mouseY <= iy + itemH
            love.graphics.setColor(hover and cfg.COL_UI_BUTTON_HI or cfg.COL_UI_BUTTON)
            love.graphics.rectangle("fill", dropdownX+2, iy+1, dropdownW-4, itemH-2)
            love.graphics.setColor(cfg.COL_UI_TEXT)
            love.graphics.print(item, dropdownX+6, iy+3)
        end
    end
end

return menu