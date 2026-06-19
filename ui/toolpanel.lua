-- ui/toolpanel.lua
local cfg = require("config")
local bevel = require("ui/bevel")

local toolpanel = {}

function toolpanel.draw(activeTool, entityTemplate, buttons, sliders)
    local panelX = cfg.GAME_WIDTH
    love.graphics.setColor(cfg.COL_UI_BG)
    love.graphics.rectangle("fill", panelX, cfg.MENUBAR_HEIGHT, cfg.TOOL_PANEL_WIDTH, cfg.GAME_HEIGHT)
    bevel.bevelBox(panelX, cfg.MENUBAR_HEIGHT, cfg.TOOL_PANEL_WIDTH, cfg.GAME_HEIGHT, true)

    local x = panelX + 10
    local y = cfg.MENUBAR_HEIGHT + 10
    love.graphics.setColor(cfg.COL_UI_TEXT)
    love.graphics.print("TOOLS", x, y)
    y = y + 20

    -- Clear the tables (passed by reference from ui.lua)
    for k in pairs(buttons) do buttons[k] = nil end
    for k in pairs(sliders) do sliders[k] = nil end

    local bw = cfg.TOOL_PANEL_WIDTH - 20
    local toolDefs = {
        { "None", cfg.TOOL_NONE },
        { "Lamp", cfg.TOOL_LAMP },
        { "Entity", cfg.TOOL_ENTITY },
        { "Build", cfg.TOOL_BUILD },
        { "Remove", cfg.TOOL_REMOVE },
        { "Food", cfg.TOOL_FOOD },
        { "Level Exit", cfg.TOOL_EXIT },
    }
    for _, def in ipairs(toolDefs) do
        local bh = 20
        bevel.bevelButton(x, y, bw, bh, def[1], activeTool == def[2])
        table.insert(buttons, {x = x, y = y, w = bw, h = bh, tool = def[2]})
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
            bevel.bevelBox(x, y + sh/2 - 2, sw, 4, true)
            local frac = (val - min) / (max - min)
            local hx = x + frac * sw - cfg.SLIDER_HANDLE_W/2
            love.graphics.setColor(cfg.SLIDER_HANDLE_COLOR)
            love.graphics.rectangle("fill", hx, y, cfg.SLIDER_HANDLE_W, sh)
            bevel.bevelBox(hx, y, cfg.SLIDER_HANDLE_W, sh, false)
            love.graphics.setColor(cfg.COL_UI_TEXT)
            love.graphics.print(label .. ": " .. string.format("%.2f", val), x, y - 10)
            table.insert(sliders, {x = x, y = y, w = sw, h = sh, min = min, max = max, setter = setter})
            y = y + sh + 10
        end

        addSlider("Speed", 20, 150,
            function() return entityTemplate.speed end,
            function(v) entityTemplate.speed = v end)
        addSlider("Radius", 40, 250,
            function() return entityTemplate.radius end,
            function(v) entityTemplate.radius = v end)
        addSlider("Despair/s", 0.01, 0.2,
            function() return entityTemplate.despairPerSec end,
            function(v) entityTemplate.despairPerSec = v end)
        addSlider("Aggression", 0, 1,
            function() return entityTemplate.aggression end,
            function(v) entityTemplate.aggression = v end)
        addSlider("Light Avoid", -1, 1,
            function() return entityTemplate.lightAvoidance end,
            function(v) entityTemplate.lightAvoidance = v end)
        addSlider("Hearing", 50, 600,
            function() return entityTemplate.hearingRange end,
            function(v) entityTemplate.hearingRange = v end)
    end
end

return toolpanel