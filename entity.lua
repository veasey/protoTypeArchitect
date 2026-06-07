local cfg   = require("config")
local util  = require("util")
local audio = require("audio")

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
    self.hearingRange   = template.hearingRange or 300
    self.active         = true
    self.vx = 0
    self.vy = 0
    self.state = "lurking"      -- "lurking", "shambling", "chasing", "fleeing_light", "seeking_light", "investigating"
    self.previousState = "lurking"   -- track to detect state changes
    self.wanderTimer    = 0
    self.nextWander     = 2
    self.chaseTarget    = nil
    self.pathTimer      = 0
    self.investigateTarget = nil
    return self
end

function Entity:update(dt, map, denizens, lightmap)
    if not self.active then return end

    -- First, check hearing (all denizens within hearing range)
    local heardDenizen = nil
    for _, den in ipairs(denizens) do
        local d = util.distance(self.x, self.y, den.x, den.y)
        if d <= self.hearingRange then
            heardDenizen = den
            break
        end
    end

    -- Chase logic: find nearest denizen within chase radius (radius * aggression) and line-of-sight
    local chaseRadius = self.radius * self.aggression
    local target = nil
    local minDist = chaseRadius
    if self.aggression > 0 then
        for _, den in ipairs(denizens) do
            local d = util.distance(self.x, self.y, den.x, den.y)
            if d < minDist and util.hasLineOfSight(map, self.x, self.y, den.x, den.y) then
                minDist = d
                target = den
            end
        end
    end
    self.chaseTarget = target

    if target then
        self.state = "chasing"
        self.investigateTarget = nil
        
        -- Detect transition to chasing
        if self.state == "chasing" and self.previousState ~= "chasing" then
            audio.playEntityChaseSound()
        end
        self.previousState = self.state
        
        self.pathTimer = self.pathTimer + dt
        if self.pathTimer >= 0.5 then
            self.pathTimer = 0
            local dx, dy = util.getPathDirection(map, self.x, self.y, target.x, target.y, false)
            if dx then
                self.vx = dx * self.speed
                self.vy = dy * self.speed
            else
                self.vx = 0; self.vy = 0
            end
        end
    elseif heardDenizen and self.aggression > 0
           and not util.hasLineOfSight(map, self.x, self.y, heardDenizen.x, heardDenizen.y) then
        -- Investigate the sound
        self.state = "investigating"
        self.investigateTarget = heardDenizen
        self.chaseTarget = nil
        self.pathTimer = self.pathTimer + dt
        if self.pathTimer >= 0.5 then
            self.pathTimer = 0
            local dx, dy = util.getPathDirection(map, self.x, self.y, heardDenizen.x, heardDenizen.y, false)
            if dx then
                self.vx = dx * self.speed
                self.vy = dy * self.speed
            else
                self.vx = 0; self.vy = 0
            end
        end
    else
        -- Idle / Wander / Light bias
        self.investigateTarget = nil
        self.chaseTarget = nil
        if self.lightAvoidance ~= 0 and lightmap then
            local tileX, tileY = map.worldToTile(self.x, self.y)
            local curLight = lightmap[tileY] and lightmap[tileY][tileX] or 0
            if self.lightAvoidance > 0 then
                self.state = "seeking_light"
            else
                self.state = "fleeing_light"
            end
            self.wanderTimer = self.wanderTimer + dt
            if self.wanderTimer >= self.nextWander then
                self.wanderTimer = 0
                self.nextWander = 1.5 + love.math.random() * 1.5
                local bestDx, bestDy = 0, 0
                local bestLight = curLight
                local dirs = {{-1,0},{1,0},{0,-1},{0,1}}
                for _, d in ipairs(dirs) do
                    local nx, ny = tileX + d[1], tileY + d[2]
                    if map.isWalkable(nx, ny) then
                        local nlight = lightmap[ny] and lightmap[ny][nx] or 0
                        if self.lightAvoidance > 0 then
                            if nlight > bestLight then
                                bestLight = nlight
                                bestDx, bestDy = d[1], d[2]
                            end
                        else
                            if nlight < bestLight then
                                bestLight = nlight
                                bestDx, bestDy = d[1], d[2]
                            end
                        end
                    end
                end
                if bestDx ~= 0 or bestDy ~= 0 then
                    local len = math.sqrt(bestDx*bestDx + bestDy*bestDy)
                    self.vx = (bestDx / len) * self.speed
                    self.vy = (bestDy / len) * self.speed
                else
                    self.vx = 0; self.vy = 0
                end
            end
            -- Continuous movement: velocity persists between direction changes
        else
            -- No light bias: shambling
            self.state = "shambling"
            self.wanderTimer = self.wanderTimer + dt
            if self.wanderTimer >= self.nextWander then
                self.wanderTimer = 0
                self.nextWander = 1.5 + love.math.random() * 1.5
                local angle = love.math.random() * math.pi * 2
                self.vx = math.cos(angle) * self.speed
                self.vy = math.sin(angle) * self.speed
            end
        end
    end

    -- Detect transition from chasing
    if self.state ~= "chasing" and self.previousState == "chasing" then
        audio.stopEntityChaseSound()
    end

    -- Always apply movement every frame
    self:move(self.vx, self.vy, dt, map)
end

function Entity:move(vx, vy, dt, map)
    local newX = self.x + vx * dt
    local newY = self.y + vy * dt
    local tileX, tileY = map.worldToTile(newX, self.y)
    if map.isWalkable(tileX, tileY) then
        self.x = newX
    else
        self.vx = -self.vx * 0.5
    end
    tileX, tileY = map.worldToTile(self.x, newY)
    if map.isWalkable(tileX, tileY) then
        self.y = newY
    else
        self.vy = -self.vy * 0.5
    end
end

return Entity