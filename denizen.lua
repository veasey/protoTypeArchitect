local cfg  = require("config")
local util = require("util")

local Denizen = {}
Denizen.__index = Denizen

function Denizen.create(x, y)
    local self = setmetatable({}, Denizen)
    self.x = x
    self.y = y
    self.vx = 0
    self.vy = 0
    self.state = "wandering"   -- "wandering", "hiding", "fleeing"
    self.profile = {
        anxiety = love.math.random() * 0.5 + 0.3,
        despair = 0.3 + love.math.random() * 0.3,
        speed   = love.math.random(40, 80),
    }
    self.wanderTimer = 0
    self.nextWander  = 1.5
    return self
end

function Denizen:update(dt, map, entities)
    -- Determine state based on visible entities
    local closestChaser = nil
    local closestChaseDist = math.huge
    local anyEntitySeen = false
    for _, ent in ipairs(entities) do
        if ent.active then
            local dist = util.distance(self.x, self.y, ent.x, ent.y)
            if dist <= cfg.DENIZEN_SIGHT_RANGE then
                anyEntitySeen = true
                -- Is this entity chasing? (aggression > 0 and within chase radius)
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

    -- State transition
    if closestChaser then
        self.state = "fleeing"
        -- Flee direction: away from chasing entity
        local dx = self.x - closestChaser.x
        local dy = self.y - closestChaser.y
        local len = math.sqrt(dx*dx + dy*dy)
        if len > 0 then
            dx, dy = dx / len, dy / len
        end
        self.vx = dx * self.profile.speed * 1.5   -- flee faster
        self.vy = dy * self.profile.speed * 1.5
    elseif anyEntitySeen then
        self.state = "hiding"
        self.vx = 0
        self.vy = 0
    else
        self.state = "wandering"
    end

    -- Movement
    if self.state == "wandering" then
        self.wanderTimer = self.wanderTimer + dt
        if self.wanderTimer >= self.nextWander then
            self.wanderTimer = 0
            self.nextWander = 1.0 + love.math.random() * 1.5
            local angle = love.math.random() * math.pi * 2
            self.vx = math.cos(angle) * self.profile.speed
            self.vy = math.sin(angle) * self.profile.speed
        end
    end

    local newX = self.x + self.vx * dt
    local newY = self.y + self.vy * dt
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

    -- Reduce entity despair if currently hiding
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