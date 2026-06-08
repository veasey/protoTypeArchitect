local cfg  = require("config")
local util = require("util")
local map  = require("map")

local Denizen = {}
Denizen.__index = Denizen

function Denizen.create(x, y)
    local self = setmetatable({}, Denizen)
    self.x = x
    self.y = y
    self.vx = 0
    self.vy = 0
    self.state = "wandering"
    self.previousState = "wandering"
    self.profile = {
        anxiety = love.math.random() * 0.5 + 0.3,
        despair = 0.3 + love.math.random() * 0.3,
        speed   = love.math.random(40, 80),
    }
    self.wanderTimer = 0
    self.nextWander  = 1.5
    self.hidingTimer = 0
    self.hideCooldown = 0
    -- Fear memory
    self.lastChaserPos = nil   -- {x, y} of last seen chaser
    self.fearTimer = 0         -- seconds remaining to flee even after sight lost
    return self
end

function Denizen:update(dt, mapObj, entities, lightmap)
    -- Reduce timers
    self.hideCooldown = math.max(0, self.hideCooldown - dt)
    self.fearTimer = math.max(0, self.fearTimer - dt)

    -- Get light level at denizen's tile
    local tileX, tileY = mapObj.worldToTile(self.x, self.y)
    local lightLevel = lightmap[tileY] and lightmap[tileY][tileX] or 0
    lightLevel = math.max(lightLevel, cfg.LIGHT_MIN_AMBIENT)
    local effectiveSight = cfg.DENIZEN_SIGHT_RANGE * lightLevel

    -- Scan entities (line-of-sight)
    local closestChaser = nil
    local closestChaseDist = math.huge
    local anyEntitySeen = false

    for _, ent in ipairs(entities) do
        if ent.active then
            local dist = util.distance(self.x, self.y, ent.x, ent.y)
            if dist <= effectiveSight then
                if util.hasLineOfSight(mapObj, self.x, self.y, ent.x, ent.y) then
                    anyEntitySeen = true
                    local chaseRadius = ent.radius * ent.aggression
                    if ent.aggression > 0 and dist <= chaseRadius then
                        if dist < closestChaseDist then
                            closestChaser = ent
                            closestChaseDist = dist
                        end
                    end
                end
            end
        end
    end

    -- If we see a chaser, update fear memory and reset fear timer
    if closestChaser then
        self.lastChaserPos = {x = closestChaser.x, y = closestChaser.y}
        self.fearTimer = cfg.FEAR_DURATION
    end

    -- State determination
    self.previousState = self.state

    if closestChaser then
        self.state = "fleeing"
        self.hidingTimer = 0
    elseif self.fearTimer > 0 and self.lastChaserPos then
        -- No chaser currently visible, but still fleeing from last known position
        self.state = "fleeing"
    elseif anyEntitySeen and self.hideCooldown <= 0 then
        self.state = "hiding"
        self.vx = 0
        self.vy = 0
        self.hidingTimer = self.hidingTimer + dt
        if self.hidingTimer >= cfg.HIDING_DURATION then
            self.state = "wandering"
            self.hidingTimer = 0
            self.hideCooldown = cfg.HIDE_COOLDOWN_DURATION
        end
    else
        self.state = "wandering"
        self.hidingTimer = 0
        if self.previousState == "hiding" then
            self.hideCooldown = cfg.HIDE_COOLDOWN_DURATION
        end
    end

    -- Movement
    if self.state == "fleeing" then
        -- Determine flee target: current chaser or last known chaser
        local fleeFromX, fleeFromY
        if closestChaser then
            fleeFromX = closestChaser.x
            fleeFromY = closestChaser.y
        elseif self.lastChaserPos then
            fleeFromX = self.lastChaserPos.x
            fleeFromY = self.lastChaserPos.y
        end

        if fleeFromX then
            -- Use pathfinding to flee away (avoidTarget = true)
            local fleeDx, fleeDy = util.getPathDirection(mapObj, self.x, self.y, fleeFromX, fleeFromY, true)
            if fleeDx then
                self.vx = fleeDx * self.profile.speed * 1.5
                self.vy = fleeDy * self.profile.speed * 1.5
            else
                -- Fallback: direct away
                local dx = self.x - fleeFromX
                local dy = self.y - fleeFromY
                local len = math.sqrt(dx*dx + dy*dy)
                if len > 0 then
                    dx, dy = dx / len, dy / len
                end
                self.vx = dx * self.profile.speed * 1.5
                self.vy = dy * self.profile.speed * 1.5
            end
        end
    elseif self.state == "wandering" then
        self.wanderTimer = self.wanderTimer + dt
        if self.wanderTimer >= self.nextWander then
            self.wanderTimer = 0
            self.nextWander = 1.0 + love.math.random() * 1.5

            local angle = love.math.random() * math.pi * 2

            -- Avoidance: if recently feared, steer away from last chaser location
            if self.fearTimer > 0 and self.lastChaserPos then
                local dx = self.x - self.lastChaserPos.x
                local dy = self.y - self.lastChaserPos.y
                local len = math.sqrt(dx*dx + dy*dy)
                if len > 0 then
                    local awayAngle = math.atan2(dy, dx)
                    -- Blend wander angle towards away from fear
                    angle = awayAngle + (love.math.random() - 0.5) * 0.5  -- narrow random around away direction
                end
            end

            -- Despair-based avoidance (same as before)
            if self.profile.despair >= cfg.AVOID_DESPAIR_THRESHOLD then
                local lookDist = self.profile.speed * cfg.AVOID_LOOK_AHEAD
                local probeX = self.x + math.cos(angle) * lookDist
                local probeY = self.y + math.sin(angle) * lookDist

                local avoidanceAngle = 0
                local avoidanceWeight = 0

                for _, ent in ipairs(entities) do
                    if ent.active then
                        local distToProbe = util.distance(probeX, probeY, ent.x, ent.y)
                        if distToProbe <= ent.radius then
                            local intensity = ent.despairPerSec
                            local over = self.profile.despair - cfg.AVOID_DESPAIR_THRESHOLD
                            local weight = over * intensity * cfg.AVOID_STRENGTH
                            local ex = probeX - ent.x
                            local ey = probeY - ent.y
                            local elen = math.sqrt(ex*ex + ey*ey)
                            if elen > 0 then
                                ex, ey = ex / elen, ey / elen
                            end
                            avoidanceAngle = avoidanceAngle + math.atan2(ey, ex) * weight
                            avoidanceWeight = avoidanceWeight + weight
                        end
                    end
                end

                if avoidanceWeight > 0 then
                    local avoidDir = avoidanceAngle / avoidanceWeight
                    local targetAngle = avoidDir + math.pi
                    local mix = math.min(1, avoidanceWeight)
                    angle = angle + math.atan2(math.sin(targetAngle - angle), math.cos(targetAngle - angle)) * mix
                end
            end

            self.vx = math.cos(angle) * self.profile.speed
            self.vy = math.sin(angle) * self.profile.speed
        end
    elseif self.state == "hiding" then
        -- velocity zero (already set)
    end

    -- Move with collision
    local newX = self.x + self.vx * dt
    local newY = self.y + self.vy * dt
    local tx, ty = mapObj.worldToTile(newX, self.y)
    if mapObj.isWalkable(tx, ty) then
        self.x = newX
    else
        self.vx = -self.vx * 0.5
    end
    tx, ty = mapObj.worldToTile(self.x, newY)
    if mapObj.isWalkable(tx, ty) then
        self.y = newY
    else
        self.vy = -self.vy * 0.5
    end

    local half = cfg.TILE_SIZE / 2
    self.x = util.clamp(self.x, half, cfg.WORLD_WIDTH - half)
    self.y = util.clamp(self.y, half, cfg.WORLD_HEIGHT - half)
end

function Denizen:updateDespair(dt, comforts, entities)
    local minDist = math.huge
    for _, lamp in ipairs(comforts) do
        local d = util.distance(self.x, self.y, lamp.x, lamp.y)
        if d < minDist then minDist = d end
    end

    local entityDespairAdd = 0
    for _, ent in ipairs(entities) do
        if ent.active then
            local d = util.distance(self.x, self.y, ent.x, ent.y)
            if d <= ent.radius then
                entityDespairAdd = entityDespairAdd + ent.despairPerSec * dt
            end
        end
    end

    if self.state == "hiding" then
        entityDespairAdd = entityDespairAdd * cfg.HIDING_DESPAIR_MULT
    end

    local delta = cfg.BASE_DESPAIR_RATE * dt
    if minDist < cfg.COMFORT_CLOSE then
        delta = delta + cfg.CLOSE_COMFORT_DELTA * dt
    elseif minDist < cfg.COMFORT_FAR then
        delta = delta + cfg.FAR_COMFORT_DELTA * dt
    end
    delta = delta + entityDespairAdd

    self.profile.despair = util.clamp(self.profile.despair + delta, 0, 1)
    return self.profile.despair >= cfg.DESPAIR_MAX or self.profile.despair <= cfg.DESPAIR_MIN
end

function Denizen:getColor()
    return util.lerpColor(cfg.DENIZEN_COLOR_LOW, cfg.DENIZEN_COLOR_HIGH, self.profile.despair)
end

return Denizen