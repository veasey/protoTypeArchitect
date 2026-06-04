-- config.lua
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

-- Tile types (now only two)
config.VOID  = 0
config.FLOOR = 1

-- Tool modes
config.TOOL_NONE   = "none"
config.TOOL_LAMP   = "lamp"
config.TOOL_ENTITY = "entity"
config.TOOL_BUILD  = "build"      -- place floor tiles (corridors/rooms)
config.TOOL_REMOVE = "remove"     -- return floor to void

-- Starting island size (centered in the void)
config.START_ROOM_RADIUS = 2    -- 5x5 floor area

-- Spawning / AI (unchanged)
config.SPAWN_INTERVAL   = 5
config.AI_INTERVAL      = 0.2
config.DENIZEN_COUNT    = 15

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
    speed    = 60,
    radius   = 100,
    despairPerSec = 0.05,
}

-- Colours
config.COL_VOID    = {0.05, 0.05, 0.08}   -- deep void
config.COL_FLOOR   = {0.78, 0.71, 0.55}   -- beige wallpaper
config.COL_LAMP    = {0.91, 0.78, 0.38}
config.COL_ENTITY  = {0.4, 0.27, 0.53}
config.COL_ENTITY_RADIUS = {0.4, 0.27, 0.53, 0.2}
config.COL_UI_BG   = {0.17, 0.17, 0.17}

config.DENIZEN_COLOR_LOW  = {0.53, 0.67, 0.8}
config.DENIZEN_COLOR_HIGH = {0.8, 0.2, 0.2}

return config