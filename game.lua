local cfg     = require("config")
local map     = require("map")
local Denizen = require("denizen")
local Comfort = require("comfort")
local Entity  = require("entity")
local effects = require("effects")
local audio   = require("audio")
local util    = require("util")
local logger  = require("logger")

local game_init = require("game_init")
local spawning  = require("game_spawning")
local tiles     = require("game_tiles")
local update    = require("game_update")
local resources = require("game_resources")
local lighting  = require("game_lighting")
local persistence = require("game_persistence")
local hover     = require("game_hover")

local game = {}

-- data
game.denizens  = {}
game.comforts  = {}
game.entities  = {}
game.foods     = {}
game.exits     = {}
game.corpses   = {}
game.escapedCount = 0

game.entityTemplate = {
    speed          = cfg.ENTITY_DEFAULTS.speed,
    radius         = cfg.ENTITY_DEFAULTS.radius,
    despairPerSec  = cfg.ENTITY_DEFAULTS.despairPerSec,
    aggression     = cfg.ENTITY_DEFAULTS.aggression,
    lightAvoidance = cfg.ENTITY_DEFAULTS.lightAvoidance,
    hearingRange   = cfg.ENTITY_DEFAULTS.hearingRange,
}

game.spawnTimer = 0
game.aiTimer    = 0
game.lightmap = {}

game.familiarity = 0
game.unease = 0
game.dread = 0
game.dreadSpawnTimer = 0
game.paused = false
game.familiarityResource = 1.0
game.uneaseResource      = 1.0

-- wire functions
game.init = function() game_init(game) end
game.spawnDenizen = function() spawning.spawnDenizen(game) end
game.addComfort = function(wx, wy) spawning.addComfort(game, wx, wy) end
game.addEntity = function(wx, wy) spawning.addEntity(game, wx, wy) end
game.addFood = function(wx, wy) spawning.addFood(game, wx, wy) end
game.addExit = function(wx, wy) spawning.addExit(game, wx, wy) end

game.clearTile = function(tx, ty) tiles.clearTile(game, tx, ty) end
game.witnessTileChange = function(tx, ty) tiles.witnessTileChange(game, tx, ty) end

game.update = function(dt) update.run(game, dt) end
game.computeResources = function(dt) resources.compute(game, dt) end
game.computeLighting = function() lighting.compute(game) end

game.save = function() persistence.save(game) end
game.load = function() persistence.load(game) end

game.getHoveredObject = function(mx, my, cam) return hover.getHoveredObject(game, mx, my, cam) end

-- metrics / pause remain directly on game
game.getEfficiency = function()
    if #game.denizens == 0 then return 0 end
    local count = 0
    for _, den in ipairs(game.denizens) do
        local d = den.profile.despair
        if d >= cfg.SWEET_SPOT_LOW and d <= cfg.SWEET_SPOT_HIGH then count = count + 1 end
    end
    return math.floor((count / #game.denizens) * 100)
end

game.togglePauseState = function()
    game.paused = not game.paused
    if game.paused then audio.pauseAll() else audio.resumeAll() end
end

-- removal helper (used by sub-modules)
game.removeDenizen = function(index, cause)
    local den = game.denizens[index]
    if den.events and #den.events > 0 then
        logger.logDenizen(den.name, den.personality, den.events, cause)
    end
    table.remove(game.denizens, index)
end

return game