local cfg  = require("config")
local util = require("util")

local Entity = {}
Entity.__index = Entity

function Entity.create(x, y, template)
    local self = setmetatable({}, Entity)
    self.x = x
    self.y = y
    self.speed          = template.speed
    self.radius         = template.radius
    self.despairPerSec  = template.despairPerSec
    self.aggression     = template.aggression or 0.5
    self.lightAvoidance = template.lightAvoidance or 0.0
    self.active         = true
    self.wanderTimer    = 0
    self.nextWander     = 2
    self.chaseTarget    = nil
    return self
end

function Entity:update(dt, map, denizens, lightmap)
    if not self.active then return end

    -- Chase logic: find nearest denizen within chase radius (radius * aggression)
    local chaseRadius = self.radius * self.aggression
    local target = nil
    local minDist = chaseRadius
    if self.aggression > 0 then
        for _, den in ipairs(denizens) do
            local d = util.distance(self.x, self.y, den.x, den.y)
            if d < minDist then
                minDist = d
                target = den
            end
        end
    end
    self.chaseTarget = target

    if target then
        -- Move towards target
        local dx = target.x - self.x
        local dy = target.y - self.y
        local len = math.sqrt(dx*dx + dy*dy)
        if len > 0 then
            dx, dy = dx / len, dy / len
        end
        local vx = dx * self.speed
        local vy = dy * self.speed
        self:move(vx, vy, dt, map)
    else
        -- Light-biased wander
        self.wanderTimer = self.wanderTimer + dt
        if self.wanderTimer >= self.nextWander then
            self.wanderTimer = 0
            self.nextWander = 1.5 + love.math.random() * 1.5
            -- Base direction
            local angle = love.math.random() * math.pi * 2
            local baseVx = math.cos(angle) * self.speed
            local baseVy = math.sin(angle) * self.speed

            -- Light bias
            if self.lightAvoidance ~= 0 and lightmap then
                local tileX, tileY = map.worldToTile(self.x, self.y)
                local curLight = lightmap[tileY] and lightmap[tileY][tileX] or 0
                -- Sample neighbours
                local bestDx, bestDy = 0, 0
                local bestLight = curLight
                local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
                for _, d in ipairs(dirs) do
                    local nx, ny = tileX + d[1], tileY + d[2]
                    if map.isWalkable(nx, ny) then
                        local nlight = lightmap[ny] and lightmap[ny][nx] or 0
                        local deltaLight = nlight - curLight
                        if self.lightAvoidance > 0 then
                            -- seek light: choose direction with highest light
                            if nlight > bestLight then
                                bestLight = nlight
                                bestDx, bestDy = d[1], d[2]
                            end
                        else
                            -- flee light: choose direction with lowest light
                            if nlight < bestLight then
                                bestLight = nlight
                                bestDx, bestDy = d[1], d[2]
                            end
                        end
                    end
                end
                if bestDx ~= 0 or bestDy ~= 0 then
                    local lenBias = math.sqrt(bestDx*bestDx + bestDy*bestDy)
                    baseVx = (bestDx / lenBias) * self.speed
                    baseVy = (bestDy / lenBias) * self.speed
                end
            end
            self:move(baseVx, baseVy, dt, map)
        end
    end
end

function Entity:move(vx, vy, dt, map)
    local newX = self.x + vx * dt
    local newY = self.y + vy * dt
    local tileX, tileY = map.worldToTile(newX, self.y)
    if map.isWalkable(tileX, tileY) then
        self.x = newX
    end
    tileX, tileY = map.worldToTile(self.x, newY)
    if map.isWalkable(tileX, tileY) then
        self.y = newY
    end
end

return Entity