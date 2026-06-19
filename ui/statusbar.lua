-- ui/statusbar.lua
local cfg = require("config")
local bevel = require("ui/bevel")

local statusbar = {}

function statusbar.draw(game, denizenCount, efficiency, getDragRect)
    local sbY = cfg.WINDOW_HEIGHT - cfg.STATUSBAR_HEIGHT
    love.graphics.setColor(cfg.COL_UI_BG)
    love.graphics.rectangle("fill", 0, sbY, cfg.WINDOW_WIDTH, cfg.STATUSBAR_HEIGHT)
    bevel.bevelBox(0, sbY, cfg.WINDOW_WIDTH, cfg.STATUSBAR_HEIGHT, true)

    local barX = 10
    local barW = (cfg.WINDOW_WIDTH - 30) / 3
    local barH = cfg.STATUSBAR_HEIGHT - 20
    local barY = sbY + 4

    local function drawStatusBar(label, barX, barY, barW, barH, value, color)
        love.graphics.setColor(0.1, 0.1, 0.1)
        love.graphics.rectangle("fill", barX, barY, barW, barH)
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.rectangle("fill", barX, barY, barW * value, barH)
        bevel.bevelBox(barX, barY, barW, barH, true)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print(label .. ": " .. string.format("%.2f", value), barX + 4, barY + barH/2 - 7)
    end

    drawStatusBar("Familiarity", barX, barY, barW, barH, game.familiarity, {0.2, 0.6, 0.2})
    barX = barX + barW + 5
    drawStatusBar("Unease", barX, barY, barW, barH, game.unease, {0.6, 0.6, 0.2})
    barX = barX + barW + 5
    drawStatusBar("Dread", barX, barY, barW, barH, game.dread, {0.6, 0.2, 0.2})

    -- Resource pips
    local pipY = barY + barH + 2
    local pipSize = 4
    local pipSpacing = 6

    -- Familiarity pips (buildable tiles)
    local famMax = 20
    local famAvailable = math.floor(game.familiarityResource / cfg.BUILD_COST_PER_TILE)
    local famBarX = 10

    -- Determine drag‑preview tiles if a build rectangle is active
    local dragTiles = 0
    if getDragRect then
        local rect = getDragRect()
        if rect then
            -- only count if build tool is active? We could check, but we just pass nil when not building.
            for x = rect.x1, rect.x2 do
                for y = rect.y1, rect.y2 do
                    if require("map").isBuildable(x, y) then dragTiles = dragTiles + 1 end
                end
            end
        end
    end

    for i = 1, famMax do
        local px = famBarX + (i-1) * pipSpacing
        if i <= dragTiles then
            love.graphics.setColor(1, 1, 1, 0.8)   -- white for preview
        elseif i <= famAvailable then
            love.graphics.setColor(0.2, 0.8, 0.2)
        else
            love.graphics.setColor(0.2, 0.2, 0.2)
        end
        love.graphics.rectangle("fill", px, pipY, pipSize, pipSize)
    end

    -- Unease pips (entity placements)
    local uneMax = 5
    local uneAvailable = math.floor(game.uneaseResource / cfg.ENTITY_COST)
    local uneBarX = 10 + barW + 5
    for i = 1, uneMax do
        local px = uneBarX + (i-1) * pipSpacing
        local filled = i <= uneAvailable
        love.graphics.setColor(filled and {0.8, 0.8, 0.2} or {0.2, 0.2, 0.2})
        love.graphics.rectangle("fill", px, pipY, pipSize, pipSize)
    end

    local sx = cfg.WINDOW_WIDTH - 200
    love.graphics.setColor(cfg.COL_UI_TEXT)
    love.graphics.print("Denizens: " .. denizenCount .. "  Eff: " .. efficiency .. "%", sx, sbY + barH/2 - 7)

    local pauseW, pauseH = 60, 16
    local pauseX = cfg.WINDOW_WIDTH - pauseW - 10
    local pauseY = sbY + cfg.STATUSBAR_HEIGHT - pauseH - 2
    bevel.bevelButton(pauseX, pauseY, pauseW, pauseH, game.paused and "Resume" or "Pause", false)

    return { x = pauseX, y = pauseY, w = pauseW, h = pauseH }
end

return statusbar