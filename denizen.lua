local cfg  = require("config")
local util = require("util")
local map  = require("map")

local Denizen = {}
Denizen.__index = Denizen

function Denizen.create(x, y)
    local self = setmetatable({}, Denizen)
    self.events = {}   -- list of strings
    self.x = x
    self.y = y
    self.vx = 0
    self.vy = 0
    self.state = "wandering"   -- "wandering", "hiding", "fleeing", "escaping", "frozen", "psychotic"
    self.previousState = "wandering"
    self.name = cfg.DENIZEN_NAMES[love.math.random(#cfg.DENIZEN_NAMES)]
    local persKey = nil
    local persData = nil
    -- pick a random personality
    local keys = {}
    for k,_ in pairs(cfg.PERSONALITIES) do table.insert(keys, k) end
    persKey = keys[love.math.random(#keys)]
    persData = cfg.PERSONALITIES[persKey]
    self.personality = persKey
    self.persData = persData

    self.profile = {
        anxiety = love.math.random() * 0.5 + 0.3,
        despair = 0.3 + love.math.random() * 0.3,
        speed   = love.math.random(40, 80),
    }
    self.wanderTimer = 0
    self.nextWander  = 1.5
    self.hidingTimer = 0
    self.hideCooldown = 0
    self.lastChaserPos = nil
    self.fearTimer = 0
    self.escaped = false
    self.toRemove = false

    -- Outcome timers
    self.frozenTimer = 0
    self.psychoticTimer = 0

    -- Social grouping: computed externally
    self.nearbyDenizenCount = 0
    return self
end

function Denizen:update(dt, mapObj, entities, lightmap, unease, foods, exits, allDenizens)
    self.hideCooldown = math.max(0, self.hideCooldown - dt)
    self.fearTimer = math.max(0, self.fearTimer - dt)

    local tileX, tileY = mapObj.worldToTile(self.x, self.y)
    local lightLevel = lightmap[tileY] and lightmap[tileY][tileX] or 0
    lightLevel = math.max(lightLevel, cfg.LIGHT_MIN_AMBIENT)
    local effectiveSight = cfg.DENIZEN_SIGHT_RANGE * lightLevel

    -- Personality modifiers
    local anxietyMult = self.persData.anxietyMult or 1.0
    local despairResist = self.persData.despairResist or 1.0

    -- Dynamic anxiety (darkness increases, light decreases)
    self.profile.anxiety = self.profile.anxiety + dt * anxietyMult * (
        (1 - lightLevel) * cfg.ANXIETY_DARK_GAIN - lightLevel * cfg.ANXIETY_LIGHT_RECOVERY
    )
    self.profile.anxiety = util.clamp(self.profile.anxiety, 0, 1)

    -- Despair from darkness / isolation (light counteracts, comfort food later)
    local baseDespairDelta = cfg.BASE_DESPAIR_RATE * (1 - lightLevel) * despairResist * dt
    self.profile.despair = self.profile.despair + baseDespairDelta

    -- Social grouping: count nearby denizens (passed from game.update)
    self.nearbyDenizenCount = 0
    for _, other in ipairs(allDenizens) do
        if other ~= self then
            local d = util.distance(self.x, self.y, other.x, other.y)
            if d <= cfg.SOCIAL_RADIUS then
                self.nearbyDenizenCount = self.nearbyDenizenCount + 1
            end
        end
    end

    -- Food buff
    for _, food in ipairs(foods) do
        local dist = util.distance(self.x, self.y, food.x, food.y)
        if dist <= cfg.FOOD_RADIUS then
            self.profile.despair = math.max(0, self.profile.despair - cfg.FOOD_DESPAIR_REDUCTION * dt)
            self.profile.anxiety = math.max(0, self.profile.anxiety - cfg.FOOD_ANXIETY_REDUCTION * dt)
        end
    end

    -- Speed modulation by unease
    local effectiveSpeed = self.profile.speed * (1 + (unease or 0) * cfg.UNEASE_SPEED_BOOST)

    -- Check for despair peak outcomes (priority over normal states)
    if self.state ~= "frozen" and self.state ~= "psychotic" and self.profile.despair >= 0.95 then
        -- Determine outcome based on anxiety and familiarity (global)
        local familiarity = game.familiarity  -- we'll assume global game is accessible; otherwise pass it
        if self.profile.anxiety < 0.4 and familiarity < 0.5 then
            self.state = "frozen"
            self.vx = 0; self.vy = 0
            self.frozenTimer = 0
        elseif self.profile.anxiety >= 0.6 then
            self.state = "psychotic"
            self.psychoticTimer = 0
        elseif familiarity > 0.6 then
            -- Noclip out
            self.toRemove = true
            game.familiarity = math.min(1, game.familiarity + 0.05)   -- slight boost
            audio.playDenizenEnterLeaveSound()
        end
    end

    -- Standard behavior states
    if self.state ~= "frozen" and self.state ~= "psychotic" then
        -- Scan entities (line-of-sight)
        local closestChaser = nil
        local closestChaseDist = math.huge
        local anyEntitySeen = false
        for _, ent in ipairs(entities) do
            if ent.active then
                local dist = util.distance(self.x, self.y, ent.x, ent.y)
                if dist <= effectiveSight and util.hasLineOfSight(mapObj, self.x, self.y, ent.x, ent.y) then
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

        -- Fear memory
        if closestChaser then
            self.lastChaserPos = {x = closestChaser.x, y = closestChaser.y}
            self.fearTimer = cfg.FEAR_DURATION
        end

        -- Exit detection
        local closestExit = nil
        local closestExitDist = math.huge
        for _, exitObj in ipairs(exits) do
            local dist = util.distance(self.x, self.y, exitObj.x, exitObj.y)
            if dist <= cfg.EXIT_DETECTION_RANGE and util.hasLineOfSight(mapObj, self.x, self.y, exitObj.x, exitObj.y) then
                if dist < closestExitDist then
                    closestExitDist = dist
                    closestExit = exitObj
                end
            end
        end

        -- State transitions
        self.previousState = self.state
        if closestChaser then
            self.state = "fleeing"
            self.hidingTimer = 0
        elseif closestExit then
            self.state = "escaping"
            if closestExitDist <= cfg.EXIT_ESCAPE_DISTANCE then
                self.escaped = true
            end
        elseif anyEntitySeen and self.hideCooldown <= 0 then
            self.state = "hiding"
            self.vx = 0; self.vy = 0
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
            local fleeFromX, fleeFromY = nil, nil
            if closestChaser then
                fleeFromX = closestChaser.x; fleeFromY = closestChaser.y
            elseif self.lastChaserPos then
                fleeFromX = self.lastChaserPos.x; fleeFromY = self.lastChaserPos.y
            end
            if fleeFromX then
                local dx, dy = util.getPathDirection(mapObj, self.x, self.y, fleeFromX, fleeFromY, true)
                if dx then
                    self.vx = dx * effectiveSpeed * 1.5; self.vy = dy * effectiveSpeed * 1.5
                else
                    local dx2 = self.x - fleeFromX; local dy2 = self.y - fleeFromY
                    local len = math.sqrt(dx2*dx2+dy2*dy2)
                    if len>0 then dx2=dx2/len; dy2=dy2/len end
                    self.vx = dx2 * effectiveSpeed * 1.5; self.vy = dy2 * effectiveSpeed * 1.5
                end
            end
        elseif self.state == "escaping" and closestExit then
            local dx, dy = util.getPathDirection(mapObj, self.x, self.y, closestExit.x, closestExit.y, false)
            if dx then
                self.vx = dx * effectiveSpeed * 1.5; self.vy = dy * effectiveSpeed * 1.5
            end
        elseif self.state == "wandering" then
            self.wanderTimer = self.wanderTimer + dt
            if self.wanderTimer >= self.nextWander then
                self.wanderTimer = 0; self.nextWander = 1.0 + love.math.random() * 1.5
                local angle = love.math.random() * math.pi * 2
                if self.fearTimer > 0 and self.lastChaserPos then
                    local dx = self.x - self.lastChaserPos.x; local dy = self.y - self.lastChaserPos.y
                    local len = math.sqrt(dx*dx+dy*dy)
                    if len > 0 then angle = math.atan2(dy, dx) + (love.math.random()-0.5)*0.5 end
                end
                -- Despair avoidance
                if self.profile.despair >= cfg.AVOID_DESPAIR_THRESHOLD then
                    local lookDist = effectiveSpeed * cfg.AVOID_LOOK_AHEAD
                    local probeX = self.x + math.cos(angle) * lookDist
                    local probeY = self.y + math.sin(angle) * lookDist
                    local avoidAngle = 0; local avoidWeight = 0
                    for _, ent in ipairs(entities) do
                        if ent.active then
                            local d = util.distance(probeX, probeY, ent.x, ent.y)
                            if d <= ent.radius then
                                local over = self.profile.despair - cfg.AVOID_DESPAIR_THRESHOLD
                                local weight = over * ent.despairPerSec * cfg.AVOID_STRENGTH
                                local ex = probeX - ent.x; local ey = probeY - ent.y
                                local elen = math.sqrt(ex*ex+ey*ey)
                                if elen>0 then ex=ex/elen; ey=ey/elen end
                                avoidAngle = avoidAngle + math.atan2(ey, ex) * weight
                                avoidWeight = avoidWeight + weight
                            end
                        end
                    end
                    if avoidWeight > 0 then
                        local dir = avoidAngle / avoidWeight + math.pi
                        local mix = math.min(1, avoidWeight)
                        angle = angle + math.atan2(math.sin(dir - angle), math.cos(dir - angle)) * mix
                    end
                end
                self.vx = math.cos(angle) * effectiveSpeed
                self.vy = math.sin(angle) * effectiveSpeed
            end
        elseif self.state == "hiding" then
            -- velocity already zero
        end

        -- Collision
        local newX = self.x + self.vx * dt; local newY = self.y + self.vy * dt
        local tx, ty = mapObj.worldToTile(newX, self.y)
        if mapObj.isWalkable(tx, ty) then self.x = newX else self.vx = -self.vx * 0.5 end
        tx, ty = mapObj.worldToTile(self.x, newY)
        if mapObj.isWalkable(tx, ty) then self.y = newY else self.vy = -self.vy * 0.5 end

        local half = cfg.TILE_SIZE/2
        self.x = util.clamp(self.x, half, cfg.WORLD_WIDTH - half)
        self.y = util.clamp(self.y, half, cfg.WORLD_HEIGHT - half)
    else
        -- Frozen or psychotic states
        if self.state == "frozen" then
            self.vx = 0; self.vy = 0
            self.frozenTimer = self.frozenTimer + dt
            if self.frozenTimer >= cfg.FREEZE_DURATION then
                -- Become corpse
                self.toRemove = true
                -- Add corpse at this position (done in game.update after)
                -- We'll set a flag and handle it in game.update
                self.becomeCorpse = true
            end
        elseif self.state == "psychotic" then
            -- Wander erratically, fast
            self.wanderTimer = self.wanderTimer + dt
            if self.wanderTimer >= 0.2 then  -- very frequent direction changes
                self.wanderTimer = 0
                local angle = love.math.random() * math.pi * 2
                self.vx = math.cos(angle) * effectiveSpeed * cfg.PSYCHOTIC_SPEED_MULT
                self.vy = math.sin(angle) * effectiveSpeed * cfg.PSYCHOTIC_SPEED_MULT
            end
            -- move with collision
            local newX = self.x + self.vx * dt; local newY = self.y + self.vy * dt
            local tx, ty = mapObj.worldToTile(newX, self.y)
            if mapObj.isWalkable(tx, ty) then self.x = newX else self.vx = -self.vx * 0.5 end
            tx, ty = mapObj.worldToTile(self.x, newY)
            if mapObj.isWalkable(tx, ty) then self.y = newY else self.vy = -self.vy * 0.5 end
            local half = cfg.TILE_SIZE/2
            self.x = util.clamp(self.x, half, cfg.WORLD_WIDTH - half)
            self.y = util.clamp(self.y, half, cfg.WORLD_HEIGHT - half)

            self.psychoticTimer = self.psychoticTimer + dt
            if self.psychoticTimer >= cfg.PSYCHOTIC_DURATION then
                -- Become an entity
                self.toRemove = true
                self.becomeEntity = true
            end
            -- recovery condition: if in a safe place (light > 0.7) for a while, recover? Not implemented for brevity, but could be added.
        end
    end
end

function Denizen:updateDespair(dt, comforts, entities, foods, corpses)
    local minDist = math.huge
    for _, lamp in ipairs(comforts) do
        local d = util.distance(self.x, self.y, lamp.x, lamp.y)
        if d < minDist then minDist = d end
    end
    -- Comfort effect
    local comfortDelta = 0
    if minDist < cfg.COMFORT_CLOSE then
        comfortDelta = cfg.CLOSE_COMFORT_DELTA * dt
    elseif minDist < cfg.COMFORT_FAR then
        comfortDelta = cfg.FAR_COMFORT_DELTA * dt
    end
    self.profile.despair = self.profile.despair + comfortDelta

    -- Entity despair addition
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
    self.profile.despair = self.profile.despair + entityDespairAdd

    -- Corpse despair
    for _, corpse in ipairs(corpses) do
        local d = util.distance(self.x, self.y, corpse.x, corpse.y)
        if d <= cfg.CORPSE_DESPAIR_RADIUS then
            self.profile.despair = self.profile.despair + cfg.CORPSE_DESPAIR_PER_SEC * dt
        end
    end

    -- Food reduction already applied in update
    self.profile.despair = util.clamp(self.profile.despair, 0, 1)
    return self.profile.despair >= cfg.DESPAIR_MAX or self.profile.despair <= cfg.DESPAIR_MIN
end

function Denizen:getColor()
    return util.lerpColor(cfg.DENIZEN_COLOR_LOW, cfg.DENIZEN_COLOR_HIGH, self.profile.despair)
end

return Denizen