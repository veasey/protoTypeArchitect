local util = {}

function util.clamp(val, low, high)
    return math.max(low, math.min(high, val))
end

function util.distance(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx*dx + dy*dy)
end

-- Linear interpolation between two colour tables (r,g,b)
function util.lerpColor(c1, c2, t)
    t = util.clamp(t, 0, 1)
    return {
        c1[1] + (c2[1] - c1[1]) * t,
        c1[2] + (c2[2] - c1[2]) * t,
        c1[3] + (c2[3] - c1[3]) * t,
    }
end

-- Bresenham line-of-sight through walkable tiles
function util.hasLineOfSight(map, x1, y1, x2, y2)
    local tileX1, tileY1 = map.worldToTile(x1, y1)
    local tileX2, tileY2 = map.worldToTile(x2, y2)

    -- Quick check: if start or end not walkable, no LOS
    if not map.isWalkable(tileX1, tileY1) or not map.isWalkable(tileX2, tileY2) then
        return false
    end

    local dx = math.abs(tileX2 - tileX1)
    local dy = math.abs(tileY2 - tileY1)
    local sx = tileX1 < tileX2 and 1 or -1
    local sy = tileY1 < tileY2 and 1 or -1
    local err = dx - dy

    local x, y = tileX1, tileY1
    while x ~= tileX2 or y ~= tileY2 do
        if not map.isWalkable(x, y) then
            return false
        end
        local e2 = 2 * err
        if e2 > -dy then
            err = err - dy
            x = x + sx
        end
        if e2 < dx then
            err = err + dx
            y = y + sy
        end
        if not map.isWalkable(x, y) then
            return false
        end
    end
    return true
end

function util.getPathDirection(map, x1, y1, x2, y2, avoidTarget)
    local startTX, startTY = map.worldToTile(x1, y1)
    local goalTX, goalTY = map.worldToTile(x2, y2)

    if not map.isWalkable(startTX, startTY) then return nil end

    local visited = {}
    local parent = {}
    local queue = {}
    local distToGoal = {}    -- Euclidean distance squared for avoidTarget
    local head = 1
    visited[startTY * 1000 + startTX] = true
    queue[1] = {x = startTX, y = startTY}
    distToGoal[startTY * 1000 + startTX] = (startTX - goalTX)^2 + (startTY - goalTY)^2

    local bestKey = startTY * 1000 + startTX
    local foundGoal = false

    while head <= #queue do
        local node = queue[head]
        head = head + 1

        if not avoidTarget and node.x == goalTX and node.y == goalTY then
            foundGoal = true
            break
        end

        local neighbors = {
            {x = node.x - 1, y = node.y},
            {x = node.x + 1, y = node.y},
            {x = node.x, y = node.y - 1},
            {x = node.x, y = node.y + 1},
        }

        for _, nb in ipairs(neighbors) do
            if map.isWalkable(nb.x, nb.y) then
                local key = nb.y * 1000 + nb.x
                if not visited[key] then
                    visited[key] = true
                    parent[key] = {x = node.x, y = node.y}
                    table.insert(queue, {x = nb.x, y = nb.y})
                    local d = (nb.x - goalTX)^2 + (nb.y - goalTY)^2
                    distToGoal[key] = d

                    -- For flee mode, track the farthest tile from goal
                    if avoidTarget then
                        if d > distToGoal[bestKey] then
                            bestKey = key
                        end
                    end
                end
            end
        end
    end

    local targetTX, targetTY
    if avoidTarget then
        -- Use the farthest reachable tile from the goal
        targetTX = math.floor(bestKey % 1000)
        targetTY = math.floor(bestKey / 1000)
        -- If the best tile is the start, no escape possible
        if targetTX == startTX and targetTY == startTY then
            return nil
        end
    else
        if not foundGoal then return nil end
        targetTX, targetTY = goalTX, goalTY
    end

    -- Backtrack to find the next step from start
    local curX, curY = targetTX, targetTY
    while true do
        local key = curY * 1000 + curX
        local p = parent[key]
        if not p then break end
        if p.x == startTX and p.y == startTY then
            local dx = curX - startTX
            local dy = curY - startTY
            local len = math.sqrt(dx*dx + dy*dy)
            if len > 0 then
                return dx / len, dy / len
            end
            break
        end
        curX, curY = p.x, p.y
    end
    return nil
end

function util.tableShow(t, name, indent)
    indent = indent or ""
    local str = "{\n"
    local isArray = true
    for k, v in pairs(t) do
        if type(k) ~= "number" then isArray = false break end
    end
    for k, v in pairs(t) do
        local keyStr = isArray and "" or "[" .. (type(k) == "string" and string.format("%q", k) or tostring(k)) .. "] = "
        if type(v) == "table" then
            str = str .. indent .. "  " .. keyStr .. util.tableShow(v, name, indent .. "  ") .. ",\n"
        elseif type(v) == "string" then
            str = str .. indent .. "  " .. keyStr .. string.format("%q", v) .. ",\n"
        elseif type(v) == "number" or type(v) == "boolean" then
            str = str .. indent .. "  " .. keyStr .. tostring(v) .. ",\n"
        end
    end
    str = str .. indent .. "}"
    return str
end

-- Helper to get the centre of the Familiarity bar on screen
function getFamiliarityBarCenter()
    local cfg = require("config")
    local barW = (cfg.WINDOW_WIDTH - 30) / 3
    local barX = 10
    local barY = cfg.WINDOW_HEIGHT - cfg.STATUSBAR_HEIGHT + 4
    local barH = cfg.STATUSBAR_HEIGHT - 20
    return barX + barW / 2, barY + barH / 2
end

function util.getUneaseBarCenter()
    local cfg = require("config")
    local barW = (cfg.WINDOW_WIDTH - 30) / 3
    local barX = 10 + barW + 5
    local barY = cfg.WINDOW_HEIGHT - cfg.STATUSBAR_HEIGHT + 4
    local barH = cfg.STATUSBAR_HEIGHT - 20
    return barX + barW / 2, barY + barH / 2
end

function util.getDreadBarCenter()
    local cfg = require("config")
    local barW = (cfg.WINDOW_WIDTH - 30) / 3
    local barX = 10 + (barW + 5) * 2
    local barY = cfg.WINDOW_HEIGHT - cfg.STATUSBAR_HEIGHT + 4
    local barH = cfg.STATUSBAR_HEIGHT - 20
    return barX + barW / 2, barY + barH / 2
end

return util