local cfg  = require("config")
local util = require("util")
local map  = require("map")
local logger = require("logger")

local Denizen = {}
Denizen.__index = Denizen

-- Helper: add event and write to live log
local function addEvent(denizen, event)
    table.insert(denizen.events, event)
    logger.logLive(denizen.name, denizen.personality, event)
end

function Denizen.create(x, y)
    local self = setmetatable({}, Denizen)
    self.x = x
    self.y = y
    self.vx = 0
    self.vy = 0
    self.state = "wandering"
    self.previousState = "wandering"
    self.name = cfg.DENIZEN_NAMES[love.math.random(#cfg.DENIZEN_NAMES)]
    local keys = {}
    for k,_ in pairs(cfg.PERSONALITIES) do table.insert(keys, k) end
    self.personality = keys[love.math.random(#keys)]
    self.persData = cfg.PERSONALITIES[self.personality]

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
    self.frozenTimer = 0
    self.psychoticTimer = 0
    self.nearbyDenizenCount = 0
    self.events = {}
    addEvent(self, "Spawned in the Backrooms")

    -- Social bonding
    self.friends = {}               -- list of denizen references we've bonded with
    self.meetingCooldown = 0        -- timer after meeting a stranger
    self.currentMeetingTarget = nil -- denizen we're currently interacting with
    self.bondTimer = 0              -- how long we've been near the same stranger
    self.bondFormed = nil           -- flag set when a bond is completed

    -- Resource drop flags
    self.justStartedHiding = nil
    self.justGotScared = nil
    return self
end

function Denizen:update(dt, mapObj, entities, lightmap, unease, foods, exits, allDenizens, familiarity)
    self.hideCooldown = math.max(0, self.hideCooldown - dt)
    self.fearTimer = math.max(0, self.fearTimer - dt)
    self.meetingCooldown = math.max(0, self.meetingCooldown - dt)

    local tileX, tileY = mapObj.worldToTile(self.x, self.y)
    local lightLevel = lightmap[tileY] and lightmap[tileY][tileX] or 0
    lightLevel = math.max(lightLevel, cfg.LIGHT_MIN_AMBIENT)
    local effectiveSight = cfg.DENIZEN_SIGHT_RANGE * lightLevel

    local anxietyMult = self.persData.anxietyMult or 1.0
    local despairResist = self.persData.despairResist or 1.0

    -- Dynamic anxiety
    self.profile.anxiety = self.profile.anxiety + dt * anxietyMult * (
        (1 - lightLevel) * cfg.ANXIETY_DARK_GAIN - lightLevel * cfg.ANXIETY_LIGHT_RECOVERY
    )
    self.profile.anxiety = util.clamp(self.profile.anxiety, 0, 1)

    -- Base despair from darkness
    self.profile.despair = self.profile.despair + cfg.BASE_DESPAIR_RATE * (1 - lightLevel) * despairResist * dt

    -- Social grouping (nearby count)
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

    local effectiveSpeed = self.profile.speed * (1 + (unease or 0) * cfg.UNEASE_SPEED_BOOST)

    -- Despair peak outcomes (psychotic, frozen, noclip)
    if self.state ~= "frozen" and self.state ~= "psychotic" and self.profile.despair >= 0.95 then
        if self.profile.anxiety < 0.4 and familiarity < 0.5 then
            self.state = "frozen"
            self.vx = 0; self.vy = 0
            self.frozenTimer = 0
            addEvent(self, "Gave up hope, frozen in despair")
            self.justGotScared = true   -- dread drop
        elseif self.profile.anxiety >= 0.6 then
            self.state = "psychotic"
            self.psychoticTimer = 0
            addEvent(self, "Anxiety snapped, became psychotic")
            self.justGotScared = true   -- dread drop
        elseif familiarity > 0.6 then
            self.toRemove = true
            addEvent(self, "Noclipped out (high familiarity)")
        end
    end

    if self.state ~= "frozen" and self.state ~= "psychotic" then
        -- Scan entities (with LOS)
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

        if closestChaser then
            self.lastChaserPos = {x = closestChaser.x, y = closestChaser.y}
            self.fearTimer = cfg.FEAR_DURATION
        end

        -- Exit detection (with reluctance)
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

        -- State transitions (priority: fleeing > escaping > bonding > hiding > wandering)
        self.previousState = self.state

        if closestChaser then
            if self.state ~= "fleeing" then
                addEvent(self, "Spotted a chaser, fleeing!")
                self.justGotScared = true   -- dread drop
            end
            self.state = "fleeing"
            self.hidingTimer = 0
        elseif closestExit then
            -- Only use exit if desperate (high despair or anxiety)
            if self.profile.despair >= cfg.EXIT_RELUCTANCE_DESPAIR or
               self.profile.anxiety >= cfg.EXIT_RELUCTANCE_ANXIETY then
                if self.state ~= "escaping" then
                    addEvent(self, "Desperate, bolting for exit")
                end
                self.state = "escaping"
                if closestExitDist <= cfg.EXIT_ESCAPE_DISTANCE then
                    self.escaped = true
                end
            else
                -- Comfortable – ignore exit, just wander
                if self.state ~= "wandering" then
                    addEvent(self, "Saw exit but felt safe, ignored it")
                end
                self.state = "wandering"
            end
        elseif self.meetingCooldown <= 0 then
            -- Social bonding: look for an unfamiliar denizen nearby
            local stranger = nil
            local strangerDist = math.huge
            for _, other in ipairs(allDenizens) do
                if other ~= self and not self:isFriend(other) then
                    local d = util.distance(self.x, self.y, other.x, other.y)
                    if d <= cfg.BOND_RADIUS then
                        if d < strangerDist then
                            strangerDist = d
                            stranger = other
                        end
                    end
                end
            end

            if stranger then
                if self.currentMeetingTarget ~= stranger then
                    -- First encounter with this stranger
                    self.currentMeetingTarget = stranger
                    self.bondTimer = 0
                    self.state = "meeting"
                    self.vx = 0; self.vy = 0
                    if self.state ~= self.previousState then
                        addEvent(self, "Met " .. stranger.name .. ", cautious")
                    end
                else
                    -- Still near the same stranger, progress bonding
                    self.bondTimer = self.bondTimer + dt
                    self.state = "meeting"
                    self.vx = 0; self.vy = 0
                    if self.bondTimer >= cfg.BOND_TIME then
                        -- Bond formed!
                        self:addFriend(stranger)
                        stranger:addFriend(self)
                        addEvent(self, "Became friends with " .. stranger.name)
                        stranger.meetingCooldown = cfg.BOND_TIME
                        self.meetingCooldown = cfg.BOND_TIME
                        self.currentMeetingTarget = nil
                        self.bondTimer = 0
                        self.bondFormed = true
                    end
                end
            else
                -- No stranger nearby; resume normal hiding/wandering
                self.currentMeetingTarget = nil
                self.bondTimer = 0
                if anyEntitySeen and self.hideCooldown <= 0 then
                    if self.state ~= "hiding" then
                        addEvent(self, "Hiding from entity")
                        self.justStartedHiding = true   -- unease drop
                    end
                    self.state = "hiding"
                    self.vx = 0; self.vy = 0
                    self.hidingTimer = self.hidingTimer + dt
                    if self.hidingTimer >= cfg.HIDING_DURATION then
                        self.state = "wandering"
                        self.hidingTimer = 0
                        self.hideCooldown = cfg.HIDE_COOLDOWN_DURATION
                        addEvent(self, "Gave up hiding, wandering again")
                    end
                else
                    self.state = "wandering"
                    self.hidingTimer = 0
                    if self.previousState == "hiding" then
                        self.hideCooldown = cfg.HIDE_COOLDOWN_DURATION
                    end
                end
            end
        else
            -- Meeting cooldown active, just hide/wander normally
            if anyEntitySeen and self.hideCooldown <= 0 then
                if self.state ~= "hiding" then
                    addEvent(self, "Hiding from entity")
                    self.justStartedHiding = true   -- unease drop
                end
                self.state = "hiding"
                self.vx = 0; self.vy = 0
                self.hidingTimer = self.hidingTimer + dt
                if self.hidingTimer >= cfg.HIDING_DURATION then
                    self.state = "wandering"
                    self.hidingTimer = 0
                    self.hideCooldown = cfg.HIDE_COOLDOWN_DURATION
                    addEvent(self, "Gave up hiding, wandering again")
                end
            else
                self.state = "wandering"
                self.hidingTimer = 0
                if self.previousState == "hiding" then
                    self.hideCooldown = cfg.HIDE_COOLDOWN_DURATION
                end
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
                -- Despair avoidance unchanged
                self.vx = math.cos(angle) * effectiveSpeed
                self.vy = math.sin(angle) * effectiveSpeed
            end
        elseif self.state == "hiding" or self.state == "meeting" then
            -- stay still
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
        -- Frozen / psychotic states
        if self.state == "frozen" then
            self.vx = 0; self.vy = 0
            self.frozenTimer = self.frozenTimer + dt
            if self.frozenTimer >= cfg.FREEZE_DURATION then
                self.becomeCorpse = true
                addEvent(self, "Froze to death, became a corpse")
            end
        elseif self.state == "psychotic" then
            self.wanderTimer = self.wanderTimer + dt
            if self.wanderTimer >= 0.2 then
                self.wanderTimer = 0
                local angle = love.math.random() * math.pi * 2
                self.vx = math.cos(angle) * effectiveSpeed * cfg.PSYCHOTIC_SPEED_MULT
                self.vy = math.sin(angle) * effectiveSpeed * cfg.PSYCHOTIC_SPEED_MULT
            end
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
                self.becomeEntity = true
                addEvent(self, "Psychotic break complete, became an entity")
            end
        end
    end
end

function Denizen:updateDespair(dt, comforts, entities, foods, corpses)
    local minDist = math.huge
    for _, lamp in ipairs(comforts) do
        local d = util.distance(self.x, self.y, lamp.x, lamp.y)
        if d < minDist then minDist = d end
    end
    local comfortDelta = 0
    if minDist < cfg.COMFORT_CLOSE then
        comfortDelta = cfg.CLOSE_COMFORT_DELTA * dt
    elseif minDist < cfg.COMFORT_FAR then
        comfortDelta = cfg.FAR_COMFORT_DELTA * dt
    end
    self.profile.despair = self.profile.despair + comfortDelta

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

    for _, corpse in ipairs(corpses) do
        local d = util.distance(self.x, self.y, corpse.x, corpse.y)
        if d <= cfg.CORPSE_DESPAIR_RADIUS then
            self.profile.despair = self.profile.despair + cfg.CORPSE_DESPAIR_PER_SEC * dt
        end
    end

    self.profile.despair = util.clamp(self.profile.despair, 0, 1)
    return self.profile.despair >= cfg.DESPAIR_MAX or self.profile.despair <= cfg.DESPAIR_MIN
end

function Denizen:getColor()
    return util.lerpColor(cfg.DENIZEN_COLOR_LOW, cfg.DENIZEN_COLOR_HIGH, self.profile.despair)
end

-- Friendship helpers
function Denizen:isFriend(other)
    for _, f in ipairs(self.friends) do
        if f == other then return true end
    end
    return false
end

function Denizen:addFriend(other)
    if not self:isFriend(other) then
        table.insert(self.friends, other)
    end
end

return Denizen