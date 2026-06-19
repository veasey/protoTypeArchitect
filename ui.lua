local cfg    = require("config")
local game   = require("game")
local camera = require("camera")
local map    = require("map")
local sprites = require("sprites")
local effects = require("effects")
local audio   = require("audio")

local menu      = require("ui/menu")
local statusbar = require("ui/statusbar")
local toolpanel = require("ui/toolpanel")
local tooltip   = require("ui/tooltip")

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
local lastPauseRect = { x = 0, y = 0, w = 60, h = 16 }

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

-- ========== TOOL & HOVER GETTERS ==========
function ui.getActiveTool() return activeTool end
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

    -- Dropdown menus (File)
    if menuOpen then
        local dropdownX = 5
        local dropdownY = cfg.MENUBAR_HEIGHT
        local dropdownW = 120
        local itemH = 20
        local items = {"Save", "Load", "Exit"}
        for i, item in ipairs(items) do
            local iy = dropdownY + (i-1) * itemH
            if mx >= dropdownX and mx <= dropdownX + dropdownW and my >= iy and my <= iy + itemH then
                if item == "Save" then game.save()
                elseif item == "Load" then game.load()
                elseif item == "Exit" then love.event.quit() end
                menuOpen = false
                return
            end
        end
        menuOpen = false
        return
    end

    -- Dropdown menus (View)
    if viewMenuOpen then
        local dropdownX = 55
        local dropdownY = cfg.MENUBAR_HEIGHT
        local dropdownW = 120
        local itemH = 20
        local items = {"Log", "Achievements", "About"}
        for i, item in ipairs(items) do
            local iy = dropdownY + (i-1) * itemH
            if mx >= dropdownX and mx <= dropdownX + dropdownW and my >= iy and my <= iy + itemH then
                if item == "Log" then require("popups.logviewer").open = true
                elseif item == "Achievements" then require("popups.achievements").open = true
                elseif item == "About" then require("popups.about").open = true end
                viewMenuOpen = false
                return
            end
        end
        viewMenuOpen = false
        return
    end

    -- Menu bar
    if my <= cfg.MENUBAR_HEIGHT then
        if mx >= 5 and mx <= 55 then
            menuOpen = true; viewMenuOpen = false; return
        end
        if mx >= 55 and mx <= 105 then
            viewMenuOpen = true; menuOpen = false; return
        end
        return
    end

    -- Pause button
    if mx >= lastPauseRect.x and mx <= lastPauseRect.x + lastPauseRect.w
       and my >= lastPauseRect.y and my <= lastPauseRect.y + lastPauseRect.h then
        game.togglePauseState()
        return
    end

    -- Right panel
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

    -- Game world
    if activeTool == cfg.TOOL_NONE then
        dragStart = {x = mx, y = my}; dragging = true
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

            -- Resource check for build
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
        -- Single click tools
        local wx, wy = camera.screenToWorld(mx, my)
        local tx, ty = map.worldToTile(wx, wy)
        if tx and ty and map.isWalkable(tx, ty) then
            local px, py = map.tileToWorld(tx, ty)

            if activeTool == cfg.TOOL_LAMP then
                if game.familiarityResource >= cfg.LAMP_COST then
                    game.addComfort(px, py)
                    game.familiarityResource = math.max(0, game.familiarityResource - cfg.LAMP_COST)
                    audio.playLampPlaceSound()
                end
            elseif activeTool == cfg.TOOL_ENTITY then
                if game.uneaseResource >= cfg.ENTITY_COST then
                    game.addEntity(px, py)
                    audio.playEntityPlaceSound()
                end
            elseif activeTool == cfg.TOOL_FOOD then
                if game.familiarityResource >= cfg.FOOD_COST then
                    game.addFood(px, py)
                    game.familiarityResource = math.max(0, game.familiarityResource - cfg.FOOD_COST)
                end
            elseif activeTool == cfg.TOOL_EXIT then
                if game.familiarityResource >= cfg.EXIT_COST then
                    game.addExit(px, py)
                    game.familiarityResource = math.max(0, game.familiarityResource - cfg.EXIT_COST)
                end
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
    menu.draw(menuOpen, viewMenuOpen, ui.mouseX, ui.mouseY)
    lastPauseRect = statusbar.draw(game, denizenCount, efficiency, ui.getDragRect)
    toolpanel.draw(activeTool, game.entityTemplate, buttons, sliders)
    tooltip.draw(game.hoveredObject, ui.mouseX, ui.mouseY)
end

return ui