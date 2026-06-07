local cfg    = require("config")
local game   = require("game")
local camera = require("camera")
local map    = require("map")
local sprites = require("sprites")
local effects = require("effects")
local audio   = require("audio")

local ui = {}

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
    if not isDraggingBuild or not dragBuildStart or not dragBuildCurrent then
        return nil
    end
    if not dragBuildStart[1] or not dragBuildStart[2] or not dragBuildCurrent[1] or not dragBuildCurrent[2] then
        return nil
    end
    local x1 = math.min(dragBuildStart[1], dragBuildCurrent[1])
    local y1 = math.min(dragBuildStart[2], dragBuildCurrent[2])
    local x2 = math.max(dragBuildStart[1], dragBuildCurrent[1])
    local y2 = math.max(dragBuildStart[2], dragBuildCurrent[2])
    return {x1=x1, y1=y1, x2=x2, y2=y2}
end

function ui.getHoverTile()
    if activeTool == cfg.TOOL_NONE or isDraggingBuild then
        return nil
    end
    if not hoverTileX or not hoverTileY then
        return nil
    end
    return {x=hoverTileX, y=hoverTileY}
end

function ui.mousepressed(mx, my, button)
    if button ~= 1 then return end

    if mx >= cfg.GAME_WIDTH then
        for _, btn in ipairs(buttons) do
            if mx >= btn.bx and mx <= btn.bx+btn.bw and
               my >= btn.by and my <= btn.by+btn.bh then
                if btn.action then btn.action() end
                return
            end
        end
        for _, sld in ipairs(sliders) do
            if mx >= sld.sx and mx <= sld.sx+sld.sw and
               my >= sld.sy-5 and my <= sld.sy+sld.sh+5 then
                sliderDrag = sld
                return
            end
        end
    else
        if activeTool == cfg.TOOL_NONE then
            dragStart = {x = mx, y = my}
            dragging = true
        elseif activeTool == cfg.TOOL_BUILD or activeTool == cfg.TOOL_REMOVE then
            local wx, wy = camera.screenToWorld(mx, my)
            local tileX, tileY = map.worldToTile(wx, wy)
            if tileX and tileY and tileX >= 1 and tileX <= cfg.MAP_COLS and tileY >= 1 and tileY <= cfg.MAP_ROWS then
                dragBuildStart = {tileX, tileY}
                dragBuildCurrent = {tileX, tileY}
                isDraggingBuild = true
            end
        end
    end
end

function ui.mousereleased(mx, my, button)
    if button == 1 then
        if isDraggingBuild then
            local rect = ui.getDragRect()
            if rect then
                local fillType = (activeTool == cfg.TOOL_BUILD) and cfg.FLOOR or cfg.VOID

                -- Calculate drag direction for delay computation
                local startTX, startTY = dragBuildStart[1], dragBuildStart[2]
                local endTX, endTY = dragBuildCurrent[1], dragBuildCurrent[2]
                local dirX = endTX - startTX
                local dirY = endTY - startTY
                local maxDist = math.sqrt(dirX*dirX + dirY*dirY)
                if maxDist == 0 then maxDist = 1 end   -- single tile click

                local maxDelay = 0.4   -- total sweep time in seconds
                local tileList = {}
                for x = rect.x1, rect.x2 do
                    for y = rect.y1, rect.y2 do
                        if fillType == cfg.FLOOR then
                            if map.isBuildable(x, y) then
                                map.setTile(x, y, fillType)
                                -- compute delay based on projection along drag vector
                                local proj = ((x - startTX) * dirX + (y - startTY) * dirY) / maxDist
                                local delay = (proj + 0.5) * maxDelay   -- shift so center of rect starts at 0 delay
                                delay = math.max(0, math.min(delay, maxDelay))
                                effects.addTileFadeIn(x, y, delay)
                            end
                        else
                            if map.grid[y] and map.grid[y][x] == cfg.FLOOR then
                                -- capture light level before removal
                                local lightLevel = game.lightmap[y] and game.lightmap[y][x] or cfg.LIGHT_MIN_AMBIENT
                                map.setTile(x, y, fillType)
                                game.clearTile(x, y)
                                local proj = ((x - startTX) * dirX + (y - startTY) * dirY) / maxDist
                                local delay = (proj + 0.5) * maxDelay
                                delay = math.max(0, math.min(delay, maxDelay))
                                effects.addTileFadeOut(x, y, lightLevel, delay)
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
            if activeTool == cfg.TOOL_LAMP or activeTool == cfg.TOOL_ENTITY then
                local wx, wy = camera.screenToWorld(mx, my)
                local tileX, tileY = map.worldToTile(wx, wy)
                if tileX and tileY and map.isWalkable(tileX, tileY) then
                    local px, py = map.tileToWorld(tileX, tileY)
                    if activeTool == cfg.TOOL_LAMP then
                        game.addComfort(px, py)
                        audio.playLampPlaceSound()
                    elseif activeTool == cfg.TOOL_ENTITY then
                        game.addEntity(px, py)
                        audio.playEntityPlaceSound()
                    end
                end
            end
        end
        dragging = false
        sliderDrag = nil
    end
end

function ui.mousemoved(mx, my, dx, dy)
    if dragging and activeTool == cfg.TOOL_NONE and dragStart then
        camera.x = camera.x - dx / camera.zoom
        camera.y = camera.y - dy / camera.zoom
        dragStart.x = mx
        dragStart.y = my
    end
    if sliderDrag then
        local sld = sliderDrag
        local frac = (mx - sld.sx) / sld.sw
        frac = math.max(0, math.min(1, frac))
        local value = sld.min + frac * (sld.max - sld.min)
        sld.setter(value)
    end
    if isDraggingBuild then
        local wx, wy = camera.screenToWorld(mx, my)
        local tileX, tileY = map.worldToTile(wx, wy)
        if tileX and tileY and tileX >= 1 and tileX <= cfg.MAP_COLS and tileY >= 1 and tileY <= cfg.MAP_ROWS then
            dragBuildCurrent = {tileX, tileY}
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
    if y > 0 then
        camera.zoom = math.min(2, camera.zoom * zoomFactor)
    else
        camera.zoom = math.max(0.5, camera.zoom / zoomFactor)
    end
end

function ui.draw(efficiency, denizenCount)
    love.graphics.setColor(cfg.COL_UI_BG)
    love.graphics.rectangle("fill", cfg.GAME_WIDTH, 0, cfg.PANEL_WIDTH, cfg.WINDOW_HEIGHT)

    local x = cfg.GAME_WIDTH + 10
    local y = 10

    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Despair Efficiency: " .. efficiency .. "%", x, y)
    y = y + 25
    love.graphics.print("Denizens: " .. denizenCount, x, y)
    y = y + 40
    love.graphics.print("Tool:", x, y)
    y = y + 20

    buttons = {}
    sliders = {}

    local function addButton(text, tool, action)
        local bx, by = x, y
        local bw, bh = 100, 24
        local active = (activeTool == tool)
        love.graphics.setColor(active and {0.47, 0.47, 0.33} or {0.27, 0.27, 0.27})
        love.graphics.rectangle("fill", bx, by, bw, bh)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(text, bx+5, by+4)
        table.insert(buttons, {bx=bx, by=by, bw=bw, bh=bh, action = action or function() activeTool = tool end})
        y = y + 28
    end

    addButton("None", cfg.TOOL_NONE)
    addButton("Lamp", cfg.TOOL_LAMP)
    addButton("Entity", cfg.TOOL_ENTITY)
    addButton("Build", cfg.TOOL_BUILD)
    addButton("Remove", cfg.TOOL_REMOVE)

    y = y + 15
    addButton("Save", nil, function() game.save() end)
    addButton("Load", nil, function() game.load() end)

    y = y + 15
    love.graphics.print("Entity Editor", x, y)
    y = y + 35

    local function addSlider(label, min, max, getVal, setVal)
        local sx, sy = x, y
        local sw, sh = 200, 20
        local val = getVal() or 0
        love.graphics.setColor(0.5, 0.5, 0.5)
        love.graphics.rectangle("fill", sx, sy, sw, sh)
        local frac = (val - min) / (max - min)
        local handleX = sx + frac * sw
        love.graphics.setColor(0.8, 0.8, 0.8)
        love.graphics.circle("fill", handleX, sy + sh/2, 5)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(label .. ": " .. string.format("%.2f", val), sx, sy-15)
        table.insert(sliders, {sx=sx, sy=sy, sw=sw, sh=sh, min=min, max=max, setter=setVal})
        y = y + 30
    end

    addSlider("Speed", 20, 150,
        function() return game.entityTemplate.speed end,
        function(v) game.entityTemplate.speed = v end)
    addSlider("Radius", 40, 250,
        function() return game.entityTemplate.radius end,
        function(v) game.entityTemplate.radius = v end)
    addSlider("Despair/s", 0.01, 0.2,
        function() return game.entityTemplate.despairPerSec end,
        function(v) game.entityTemplate.despairPerSec = v end)
    addSlider("Aggression", 0, 1,
        function() return game.entityTemplate.aggression end,
        function(v) game.entityTemplate.aggression = v end)
    addSlider("Light Avoid", -1, 1,
        function() return game.entityTemplate.lightAvoidance end,
        function(v) game.entityTemplate.lightAvoidance = v end)
    addSlider("Hearing", 50, 600,
        function() return game.entityTemplate.hearingRange end,
        function(v) game.entityTemplate.hearingRange = v end)

    y = y + 5
    love.graphics.setColor(0.27, 0.27, 0.27)
    love.graphics.rectangle("fill", x, y, 120, 24)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("Save Template", x+5, y+4)

    y = y + 40
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.print("Drag map to explore.\nScroll to zoom.", x, y)

    -- Tooltip for hovered object
    local hovered = game.hoveredObject
    if hovered then
        y = y + 10
        love.graphics.setColor(1, 1, 1, 0.9)
        if hovered.type == "entity" then
            local e = hovered.data
            love.graphics.print("Entity", x, y)
            y = y + 16
            love.graphics.print("State: " .. (e.state or "unknown"), x, y)
            y = y + 16
            love.graphics.print(string.format("Speed: %.0f", e.speed), x, y)
            y = y + 16
            love.graphics.print(string.format("Radius: %.0f", e.radius), x, y)
            y = y + 16
            love.graphics.print(string.format("Despair/s: %.2f", e.despairPerSec), x, y)
            y = y + 16
            love.graphics.print(string.format("Aggression: %.2f", e.aggression), x, y)
            y = y + 16
            love.graphics.print(string.format("Light Avoid: %.2f", e.lightAvoidance), x, y)
            y = y + 16
            love.graphics.print(string.format("Hearing: %.0f", e.hearingRange), x, y)
            y = y + 16
        elseif hovered.type == "denizen" then
            local d = hovered.data
            love.graphics.print("Denizen", x, y)
            y = y + 16
            love.graphics.print(string.format("State: %s", d.state), x, y)
            y = y + 16
            love.graphics.print(string.format("Despair: %.2f", d.profile.despair), x, y)
            y = y + 16
            love.graphics.print(string.format("Anxiety: %.2f", d.profile.anxiety), x, y)
            y = y + 16
            love.graphics.print(string.format("Speed: %.0f", d.profile.speed), x, y)
            y = y + 16
        end
        y = y + 5
    end
end

return ui