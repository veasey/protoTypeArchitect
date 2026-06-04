local cfg  = require("config")
local util = require("util")

local Entity = {}
Entity.__index = Entity

function Entity.create(x, y, template)
    local self = setmetatable({}, Entity)
    self.x = x
    self.y = y
    self.speed         = template.speed
    self.radius        = template.radius
    self.despairPerSec = template.despairPerSec
    self.active        = true
    self.angle         = 0
    self.wanderTimer   = 0
    self.nextWander    = 2
    return self
end

function Entity:update(dt, map)
    if self.speed <= 0 then return end
    self.wanderTimer = self.wanderTimer + dt
    if self.wanderTimer >= self.nextWander then
        self.wanderTimer = 0
        self.nextWander = 1.5 + love.math.random() * 1.5
        self.angle = love.math.random() * math.pi * 2
    end
    local vx = math.cos(self.angle) * self.speed
    local vy = math.sin(self.angle) * self.speed
    local newX = self.x + vx * dt
    local newY = self.y + vy * dt
    local tileX, tileY = map.worldToTile(newX, self.y)
    if map.isWalkable(tileX, tileY) then self.x = newX end
    tileX, tileY = map.worldToTile(self.x, newY)
    if map.isWalkable(tileX, tileY) then self.y = newY end
end

return Entity