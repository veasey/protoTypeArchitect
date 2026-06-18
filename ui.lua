local cfg    = require("config")
local game   = require("game")
local camera = require("camera")
local map    = require("map")
local sprites = require("sprites")
local effects = require("effects")
local audio   = require("audio")

local ui = {}

-- ========== STATE ==========
local buttons = {}
local sliders = {}
local sliderDrag = nil
local dragStart = nil
local dragging = false

local activeTool = cfg.TOOL_NONE
local dragBuildStart = nil
local dragBuildCurrent = nil
local isDraggingBuild = false
local hoverTileX, hoverTileY = nil, nil

-- Menu state
local menuOpen = false
local viewMenuOpen = false
ui.mouseX, ui.mouseY = 0, 0

-- ========== RESOURCE CLAMPING ==========
local function clampBuildRect()
    if not isDraggingBuild or activeTool ~= cfg.TOOL_BUILD then return end
    local startTX, startTY = dragBuildStart[1], dragBuildStart[2]
    local curTX, curTY = dragBuildCurrent[1], dragBuildCurrent[2]

    local function countBuildable(x1, y1, x2, y2)
        local count = 0
        for x = x1, x2 do
            for y = y1, y2 do
                if map.isBuildable(x, y) then count = count + 1 end
            end
        end
        return count
    end

    local x1 = math.min(startTX, curTX)
    local y1 = math.min(startTY, curTY)
    local x2 = math.max(startTX, curTX)
    local y2 = math.max(startTY, curTY)

    local maxTiles = math.floor(game.familiarityResource / cfg.BUILD_COST_PER_TILE)
    if maxTiles <= 0 then
        dragBuildCurrent = {startTX, startTY}
        return
    end

    local tiles = countBuildable(x1, y1, x2, y2)
    if tiles <= maxTiles then return end

    local dirX = curTX - startTX
    local dirY = curTY - startTY
    local dist = math.sqrt(dirX*dirX + dirY*dirY)
    if dist == 0 then return end
    local stepX = dirX / dist
    local stepY = dirY / dist

    local newCurTX = curTX
    local newCurTY = curTY
    for i = 1, math.ceil(dist) do
        newCurTX = newCurTX - stepX
        newCurTY = newCurTY - stepY
        local nx = math.floor(newCurTX + 0.5)
        local ny = math.floor(newCurTY + 0.5)
        local newX1 = math.min(startTX, nx)
        local newY1 = math.min(startTY, ny)
        local newX2 = math.max(startTX, nx)
        local newY2 = math.max(startTY, ny)
        local newCount = countBuildable(newX1, newY1, newX2, newY2)
        if newCount <= maxTiles then
            dragBuildCurrent = {nx, ny}
            return
        end
    end
    dragBuildCurrent = {startTX, startTY}
end

-- ========== DRAWING HELPERS ==========
local function bevelBox(x, y, w, h, sunken)
    love.graphics.setColor(sunken and cfg.COL_UI_BEVEL_LO or cfg.COL_UI_BEVEL_HI)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(sunken and cfg.COL_UI_BEVEL_HI or cfg.COL_UI_BEVEL_LO)
    love.graphics.line(x+w-1, y, x+w-1, y+h-1)
    love.graphics.line(x, y+h-1, x+w-1, y+h-1)
end

local function bevelButton(x, y, w, h, text, active)
    love.graphics.setColor(active and cfg.COL_UI_BUTTON_HI or cfg.COL_UI_BUTTON)
    love.graphics.rectangle("fill", x, y, w, h)
    bevelBox(x, y, w, h, active)
    love.graphics.setColor(cfg.COL_UI_TEXT)
    local tw = love.graphics.getFont():getWidth(text)
    local th = love.graphics.getFont():getHeight()
    love.graphics.print(text, x + (w - tw)/2, y + (h - th)/2)
end

-- ========== TOOL & HOVER GETTERS ==========
function ui.getActiveTool()
    return activeTool
end

function ui.setActiveTool(tool)
    activeTool = tool
    isDraggingBuild = false
    dragBuildStart = nil
    dragBuildCurrent = nil
    hoverTileX, hoverTileY = nil, nil
end

function ui.getDragRect()
    if not isDraggingBuild or not dragBuildStart or not dragBuildCurrent then return nil end
    if not dragBuildStart[1] or not dragBuildStart[2] or not dragBuildCurrent[1] or not dragBuildCurrent[2] then return nil end
    return {
        x1 = math.min(dragBuildStart[1], dragBuildCurrent[1]),
        y1 = math.min(dragBuildStart[2], dragBuildCurrent[2]),
        x2 = math.max(dragBuildStart[1], dragBuildCurrent[1]),
        y2 = math.max(dragBuildStart[2], dragBuildCurrent[2]),
    }
end

function ui.getHoverTile()
    if activeTool == cfg.TOOL_NONE or isDraggingBuild then return nil end
    if not hoverTileX or not hoverTileY then return nil end
    return {x = hoverTileX, y = hoverTileY}
end

-- ========== MOUSE HANDLERS ==========
function ui.mousepressed(mx, my, button)
    if button ~= 1 then return end

    -- ==== Dropdown menu items (if open) ====
    if menuOpen then
        local dropdownX = 5
        local dropdownY = cfg.MENUBAR_HEIGHT
        local dropdownW = 120
        local itemH = 20
        local items = {"Save", "Load", "Exit"}
        for i, item in ipairs(items) do
            local iy = dropdownY + (i-1) * itemH
            if mx >= dropdownX and mx <= dropdownX + dropdownW and my >= iy and my <= iy + itemH then
                if item == "Save" then
                    game.save()
                elseif item == "Load" then
                    game.load()
                elseif item == "Exit" then
                    love.event.quit()
                end
                menuOpen = false
                return
            end
        end
        menuOpen = false
        return
    end

    if viewMenuOpen then
        local dropdownX = 55
        local dropdownY = cfg.MENUBAR_HEIGHT
        local dropdownW = 120  -- widened to fit "Achievements"
        local itemH = 20
        local items = {"Log", "Achievements"}
        for i, item in ipairs(items) do
            local iy = dropdownY + (i-1) * itemH
            if mx >= dropdownX and mx <= dropdownX + dropdownW and my >= iy and my <= iy + itemH then
                if item == "Log" then
                    local logviewer = require("logviewer")
                    logviewer.open = true
                elseif item == "Achievements" then
                    local achievements = require("achievements")
                    achievements.open = true
                end
                viewMenuOpen = false
                return
            end
        end
        viewMenuOpen = false
        return
    end

    -- ==== Menu bar (top) – File / View buttons ====
    if my <= cfg.MENUBAR_HEIGHT then
        local fileBtnX = 5
        local fileBtnW = 50
        if mx >= fileBtnX and mx <= fileBtnX + fileBtnW then
            menuOpen = true
            viewMenuOpen = false
            return
        end
        local viewBtnX = 55
        local viewBtnW = 50
        if mx >= viewBtnX and mx <= viewBtnX + viewBtnW then
            viewMenuOpen = true
            menuOpen = false
            return
        end
        return
    end

    -- ==== Pause button (status bar) ====
    local pauseW, pauseH = 60, 16
    local pauseX = cfg.WINDOW_WIDTH - pauseW - 10
    local pauseY = cfg.WINDOW_HEIGHT - cfg.STATUSBAR_HEIGHT + 4
    if mx >= pauseX and mx <= pauseX + pauseW and my >= pauseY and my <= pauseY + pauseH then
        game.togglePauseState()
        return
    end

    -- ==== Right panel click ====
    if mx >= cfg.GAME_WIDTH then
        for _, btn in ipairs(buttons) do
            if mx >= btn.x and mx <= btn.x+btn.w and my >= btn.y and my <= btn.y+btn.h then
                if btn.action then btn.action() else activeTool = btn.tool end
                return
            end
        end
        for _, sld in ipairs(sliders) do
            if mx >= sld.x and mx <= sld.x+sld.w and my >= sld.y-5 and my <= sld.y+sld.h+5 then
                sliderDrag = sld
                return
            end
        end
        return
    end

    -- ==== Game world click ====
    if activeTool == cfg.TOOL_NONE then
        dragStart = {x = mx, y = my}
        dragging = true
    elseif activeTool == cfg.TOOL_BUILD or activeTool == cfg.TOOL_REMOVE then
        local wx, wy = camera.screenToWorld(mx, my)
        local tx, ty = map.worldToTile(wx, wy)
        if tx and ty and tx >= 1 and tx <= cfg.MAP_COLS and ty >= 1 and ty <= cfg.MAP_ROWS then
            dragBuildStart = {tx, ty}
            dragBuildCurrent = {tx, ty}
            isDraggingBuild = true
        end
    end
end

function ui.mousereleased(mx, my, button)
    if button ~= 1 then return end
    if isDraggingBuild then
        local rect = ui.getDragRect()
        if rect then
            local fillType = (activeTool == cfg.TOOL_BUILD) and cfg.FLOOR or cfg.VOID

            if activeTool == cfg.TOOL_BUILD then
                local tilesToBuild = 0
                for x = rect.x1, rect.x2 do
                    for y = rect.y1, rect.y2 do
                        if map.isBuildable(x, y) then tilesToBuild = tilesToBuild + 1 end
                    end
                end
                if game.familiarityResource < tilesToBuild * cfg.BUILD_COST_PER_TILE then
                    isDraggingBuild = false; dragBuildStart = nil; dragBuildCurrent = nil
                    dragging = false; sliderDrag = nil
                    return
                end
            end

            local startTX, startTY = dragBuildStart[1], dragBuildStart[2]
            local endTX, endTY = dragBuildCurrent[1], dragBuildCurrent[2]
            local dirX = endTX - startTX
            local dirY = endTY - startTY
            local maxDist = math.sqrt(dirX*dirX + dirY*dirY)
            if maxDist == 0 then maxDist = 1 end
            local maxDelay = 0.4

            for x = rect.x1, rect.x2 do
                for y = rect.y1, rect.y2 do
                    if fillType == cfg.FLOOR then
                        if map.isBuildable(x, y) then
                            map.setTile(x, y, fillType)
                            game.familiarityResource = math.max(0, game.familiarityResource - cfg.BUILD_COST_PER_TILE)
                            local proj = ((x - startTX) * dirX + (y - startTY) * dirY) / maxDist
                            local delay = math.max(0, math.min((proj + 0.5) * maxDelay, maxDelay))
                            effects.addTileFadeIn(x, y, delay)
                            game.witnessTileChange(x, y)
                        end
                    else
                        if map.grid[y] and map.grid[y][x] == cfg.FLOOR then
                            local lightLevel = game.lightmap[y] and game.lightmap[y][x] or cfg.LIGHT_MIN_AMBIENT
                            map.setTile(x, y, fillType)
                            game.clearTile(x, y)
                            game.familiarityResource = math.min(1, game.familiarityResource + cfg.REMOVE_REFUND)
                            local proj = ((x - startTX) * dirX + (y - startTY) * dirY) / maxDist
                            local delay = math.max(0, math.min((proj + 0.5) * maxDelay, maxDelay))
                            effects.addTileFadeOut(x, y, lightLevel, delay)
                            game.witnessTileChange(x, y)
                        end
                    end
                end
            end
            game.computeLighting()
            audio.playBuildSound()
        end
        isDraggingBuild = false
        dragBuildStart = nil
        dragBuildCurrent = nil
    else
        local wx, wy = camera.screenToWorld(mx, my)
        local tx, ty = map.worldToTile(wx, wy)
        if tx and ty and map.isWalkable(tx, ty) then
            local px, py = map.tileToWorld(tx, ty)
            if activeTool == cfg.TOOL_LAMP then
                game.addComfort(px, py)
                audio.playLampPlaceSound()
            elseif activeTool == cfg.TOOL_ENTITY then
                if game.uneaseResource >= cfg.ENTITY_COST then
                    game.addEntity(px, py)
                    audio.playEntityPlaceSound()
                end
            elseif activeTool == cfg.TOOL_FOOD then
                game.addFood(px, py)
            -- Exit placement removed
            end
        end
    end
    dragging = false
    sliderDrag = nil
end

function ui.mousemoved(mx, my, dx, dy)
    ui.mouseX, ui.mouseY = mx, my

    if dragging and activeTool == cfg.TOOL_NONE and dragStart then
        camera.x = camera.x - dx / camera.zoom
        camera.y = camera.y - dy / camera.zoom
        dragStart.x = mx
        dragStart.y = my
    end
    if sliderDrag then
        local sld = sliderDrag
        local frac = (mx - sld.x) / sld.w
        frac = math.max(0, math.min(1, frac))
        local val = sld.min + frac * (sld.max - sld.min)
        sld.setter(val)
    end
    if isDraggingBuild then
        local wx, wy = camera.screenToWorld(mx, my)
        local tx, ty = map.worldToTile(wx, wy)
        if tx and ty and tx >= 1 and tx <= cfg.MAP_COLS and ty >= 1 and ty <= cfg.MAP_ROWS then
            dragBuildCurrent = {tx, ty}
            clampBuildRect()
        end
    end
    if not isDraggingBuild and activeTool ~= cfg.TOOL_NONE then
        if mx < cfg.GAME_WIDTH then
            local wx, wy = camera.screenToWorld(mx, my)
            local tx, ty = map.worldToTile(wx, wy)
            if tx and ty and tx >= 1 and tx <= cfg.MAP_COLS and ty >= 1 and ty <= cfg.MAP_ROWS then
                hoverTileX, hoverTileY = tx, ty
            else
                hoverTileX, hoverTileY = nil, nil
            end
        else
            hoverTileX, hoverTileY = nil, nil
        end
    else
        hoverTileX, hoverTileY = nil, nil
    end
end

function ui.wheelmoved(x, y)
    local zoomFactor = 1.1
    if y > 0 then camera.zoom = math.min(2, camera.zoom * zoomFactor)
    else camera.zoom = math.max(0.5, camera.zoom / zoomFactor) end
end

-- ========== DRAWING ==========
function ui.draw(efficiency, denizenCount)
    local panelX = cfg.GAME_WIDTH

    -- ====== TOP MENU BAR (full width) ======
    love.graphics.setColor(cfg.COL_UI_BG)
    love.graphics.rectangle("fill", 0, 0, cfg.WINDOW_WIDTH, cfg.MENUBAR_HEIGHT)
    bevelBox(0, 0, cfg.WINDOW_WIDTH, cfg.MENUBAR_HEIGHT, true)

    local fileBtnX = 5
    local fileBtnW = 50
    local fileBtnH = cfg.MENUBAR_HEIGHT - 2
    bevelButton(fileBtnX, 1, fileBtnW, fileBtnH, "File", menuOpen)

    local viewBtnX = 55
    local viewBtnW = 50
    bevelButton(viewBtnX, 1, viewBtnW, fileBtnH, "View", viewMenuOpen)

    -- File dropdown
    if menuOpen then
        local dropdownX = fileBtnX
        local dropdownY = cfg.MENUBAR_HEIGHT
        local dropdownW = 120
        local itemH = 20
        local items = {"Save", "Load", "Exit"}
        love.graphics.setColor(cfg.COL_UI_BG)
        love.graphics.rectangle("fill", dropdownX, dropdownY, dropdownW, itemH * #items)
        bevelBox(dropdownX, dropdownY, dropdownW, itemH * #items, false)
        for i, item in ipairs(items) do
            local iy = dropdownY + (i-1) * itemH
            local hover = false
            if ui.mouseX >= dropdownX and ui.mouseX <= dropdownX + dropdownW
               and ui.mouseY >= iy and ui.mouseY <= iy + itemH then
                hover = true
            end
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
        local items = {"Log", "Achievements"}
        love.graphics.setColor(cfg.COL_UI_BG)
        love.graphics.rectangle("fill", dropdownX, dropdownY, dropdownW, itemH * #items)
        bevelBox(dropdownX, dropdownY, dropdownW, itemH * #items, false)
        for i, item in ipairs(items) do
            local iy = dropdownY + (i-1) * itemH
            local hover = false
            if ui.mouseX >= dropdownX and ui.mouseX <= dropdownX + dropdownW
               and ui.mouseY >= iy and ui.mouseY <= iy + itemH then
                hover = true
            end
            love.graphics.setColor(hover and cfg.COL_UI_BUTTON_HI or cfg.COL_UI_BUTTON)
            love.graphics.rectangle("fill", dropdownX+2, iy+1, dropdownW-4, itemH-2)
            love.graphics.setColor(cfg.COL_UI_TEXT)
            love.graphics.print(item, dropdownX+6, iy+3)
        end
    end

    -- ====== BOTTOM STATUS BAR ======
    local sbY = cfg.WINDOW_HEIGHT - cfg.STATUSBAR_HEIGHT
    love.graphics.setColor(cfg.COL_UI_BG)
    love.graphics.rectangle("fill", 0, sbY, cfg.WINDOW_WIDTH, cfg.STATUSBAR_HEIGHT)
    bevelBox(0, sbY, cfg.WINDOW_WIDTH, cfg.STATUSBAR_HEIGHT, true)

    local barX = 10
    local barW = (cfg.WINDOW_WIDTH - 30) / 3
    local barH = cfg.STATUSBAR_HEIGHT - 8
    local barY = sbY + 4

    local function drawStatusBar(label, barX, barY, barW, barH, value, color)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.rectangle("fill", barX, barY, barW * value, barH)
        bevelBox(barX, barY, barW, barH, true)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(label .. ": " .. string.format("%.2f", value), barX + 4, barY + barH/2 - 7)
    end

    drawStatusBar("Familiarity", barX, barY, barW, barH, game.familiarity, {0.2, 0.6, 0.2})
    barX = barX + barW + 5
    drawStatusBar("Unease", barX, barY, barW, barH, game.unease, {0.6, 0.6, 0.2})
    barX = barX + barW + 5
    drawStatusBar("Dread", barX, barY, barW, barH, game.dread, {0.6, 0.2, 0.2})

    local sx = cfg.WINDOW_WIDTH - 200
    love.graphics.setColor(cfg.COL_UI_TEXT)
    love.graphics.print("Denizens: " .. denizenCount .. "  Eff: " .. efficiency .. "%", sx, sbY + barH/2 - 7)

    local pauseW, pauseH = 60, 16
    local pauseX = cfg.WINDOW_WIDTH - pauseW - 10
    local pauseY = sbY + barH - pauseH - 2
    bevelButton(pauseX, pauseY, pauseW, pauseH, game.paused and "Resume" or "Pause", false)

    -- ====== RIGHT PANEL ======
    love.graphics.setColor(cfg.COL_UI_BG)
    love.graphics.rectangle("fill", panelX, cfg.MENUBAR_HEIGHT, cfg.TOOL_PANEL_WIDTH, cfg.GAME_HEIGHT)
    bevelBox(panelX, cfg.MENUBAR_HEIGHT, cfg.TOOL_PANEL_WIDTH, cfg.GAME_HEIGHT, true)

    local x = panelX + 10
    local y = cfg.MENUBAR_HEIGHT + 10

    love.graphics.setColor(cfg.COL_UI_TEXT)
    love.graphics.print("TOOLS", x, y)
    y = y + 20

    buttons = {}
    sliders = {}
    local bw = cfg.TOOL_PANEL_WIDTH - 20

    local toolDefs = {
        { "None", cfg.TOOL_NONE },
        { "Lamp", cfg.TOOL_LAMP },
        { "Entity", cfg.TOOL_ENTITY },
        { "Build", cfg.TOOL_BUILD },
        { "Remove", cfg.TOOL_REMOVE },
        { "Food", cfg.TOOL_FOOD },
    }
    for _, def in ipairs(toolDefs) do
        local bh = 20
        bevelButton(x, y, bw, bh, def[1], activeTool == def[2])
        table.insert(buttons, {x=x, y=y, w=bw, h=bh, tool=def[2]})
        y = y + 26
    end

    if activeTool == cfg.TOOL_ENTITY then
        y = y + 10
        love.graphics.setColor(cfg.COL_UI_TEXT)
        love.graphics.print("ENTITY EDITOR", x, y)
        y = y + 18

        local function addSlider(label, min, max, getter, setter)
            local sw = bw
            local sh = 14
            local val = getter() or 0
            love.graphics.setColor(cfg.SLIDER_TRACK_COLOR)
            love.graphics.rectangle("fill", x, y + sh/2 - 2, sw, 4)
            bevelBox(x, y + sh/2 - 2, sw, 4, true)
            local frac = (val - min) / (max - min)
            local hx = x + frac * sw - cfg.SLIDER_HANDLE_W/2
            love.graphics.setColor(cfg.SLIDER_HANDLE_COLOR)
            love.graphics.rectangle("fill", hx, y, cfg.SLIDER_HANDLE_W, sh)
            bevelBox(hx, y, cfg.SLIDER_HANDLE_W, sh, false)
            love.graphics.setColor(cfg.COL_UI_TEXT)
            love.graphics.print(label .. ": " .. string.format("%.2f", val), x, y - 10)
            table.insert(sliders, {x=x, y=y, w=sw, h=sh, min=min, max=max, setter=setter})
            y = y + sh + 10
        end

        addSlider("Speed", 20, 150, function() return game.entityTemplate.speed end, function(v) game.entityTemplate.speed = v end)
        addSlider("Radius", 40, 250, function() return game.entityTemplate.radius end, function(v) game.entityTemplate.radius = v end)
        addSlider("Despair/s", 0.01, 0.2, function() return game.entityTemplate.despairPerSec end, function(v) game.entityTemplate.despairPerSec = v end)
        addSlider("Aggression", 0, 1, function() return game.entityTemplate.aggression end, function(v) game.entityTemplate.aggression = v end)
        addSlider("Light Avoid", -1, 1, function() return game.entityTemplate.lightAvoidance end, function(v) game.entityTemplate.lightAvoidance = v end)
        addSlider("Hearing", 50, 600, function() return game.entityTemplate.hearingRange end, function(v) game.entityTemplate.hearingRange = v end)
    end

    -- ====== HOVERED OBJECT TOOLTIP ======
    local hovered = game.hoveredObject
    if hovered then
        local mx, my = ui.mouseX, ui.mouseY
        local tipW, tipH = 130, 96
        local tipX = mx + 16
        local tipY = my + 16
        if tipX + tipW > cfg.GAME_WIDTH then tipX = mx - tipW - 16 end
        if tipY + tipH > cfg.GAME_HEIGHT then tipY = my - tipH - 16 end

        love.graphics.setColor(cfg.COL_UI_BG)
        love.graphics.rectangle("fill", tipX, tipY, tipW, tipH)
        bevelBox(tipX, tipY, tipW, tipH, false)
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
end

return ui