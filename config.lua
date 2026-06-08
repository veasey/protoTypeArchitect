

local config = {}

config.TILE_SIZE = 32
config.MAP_COLS   = 80
config.MAP_ROWS   = 60
config.WORLD_WIDTH  = config.MAP_COLS * config.TILE_SIZE
config.WORLD_HEIGHT = config.MAP_ROWS * config.TILE_SIZE

config.WINDOW_WIDTH  = 1200
config.WINDOW_HEIGHT = 800
config.PANEL_WIDTH   = 280
config.GAME_WIDTH    = config.WINDOW_WIDTH - config.PANEL_WIDTH

-- Tile types
config.VOID  = 0
config.FLOOR = 1

-- Tool modes
config.TOOL_NONE   = "none"
config.TOOL_LAMP   = "lamp"
config.TOOL_ENTITY = "entity"
config.TOOL_BUILD  = "build"
config.TOOL_REMOVE = "remove"

config.START_ROOM_RADIUS = 2

-- ===== DENIZEN BEHAVIOR CONFIG =====

-- Spawning / AI
config.SPAWN_INTERVAL   = 15
config.AI_INTERVAL      = 0.2

config.DENIZEN_SPAWN_MIN_LIGHT = 0.3    -- light level required for a spawn tile
config.HIDING_DURATION = 1.5            -- seconds before a denizen gives up hiding
config.HIDE_COOLDOWN_DURATION = 5       -- seconds before a denizen can hide again
config.HIDING_DESPAIR_MULT     = 0.3   -- despair multiplier while hiding

-- Denizen avoidance: they avoid entity despair zones when their despair is high
config.DENIZEN_SIGHT_RANGE = 100
config.AVOID_DESPAIR_THRESHOLD = 0.5   -- above this despair, start avoiding
config.AVOID_LOOK_AHEAD = 1.0          -- seconds of movement to check ahead
config.AVOID_STRENGTH = 2.0            -- rotation force per entity (radians)
config.FEAR_DURATION = 5   -- seconds denizen keeps fleeing after losing sight of chaser

config.BASE_DESPAIR_RATE   = 0.02
config.COMFORT_CLOSE       = 80
config.COMFORT_FAR         = 150
config.CLOSE_COMFORT_DELTA = -0.04
config.FAR_COMFORT_DELTA   = -0.01
config.DESPAIR_MIN         = 0.05
config.DESPAIR_MAX         = 0.95
config.SWEET_SPOT_LOW      = 0.3
config.SWEET_SPOT_HIGH     = 0.7

config.ENTITY_DEFAULTS = {
    speed          = 50,
    radius         = 100,
    despairPerSec  = 0.05,
    aggression     = 1,    -- 0 = never chase, 1 = always chase within radius
    lightAvoidance = -1,    -- -1 = flee light, 0 = neutral, +1 = seek light
    hearingRange   = 300,    -- per-entity hearing range (pixels)
}

-- Colours
config.COL_VOID    = {0.05, 0.05, 0.08}
config.COL_FLOOR   = {0.78, 0.71, 0.55}
config.COL_LAMP    = {0.91, 0.78, 0.38}
config.COL_ENTITY  = {0.4, 0.27, 0.53}
config.COL_ENTITY_RADIUS = {0.4, 0.27, 0.53, 0.2}
config.COL_UI_BG   = {0.17, 0.17, 0.17}

config.DENIZEN_COLOR_LOW  = {0.53, 0.67, 0.8}
config.DENIZEN_COLOR_HIGH = {0.8, 0.2, 0.2}

-- Lighting
config.LIGHT_DECAY_PER_TILE = 0.25
config.LIGHT_MIN_AMBIENT    = 0.03

return config