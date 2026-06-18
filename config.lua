local config = {}

-- ============================================================
--  WINDOW & TILE DIMENSIONS
-- ============================================================
config.TILE_SIZE       = 32
config.MAP_COLS        = 80
config.MAP_ROWS        = 60
config.WORLD_WIDTH     = config.MAP_COLS * config.TILE_SIZE
config.WORLD_HEIGHT    = config.MAP_ROWS * config.TILE_SIZE

config.WINDOW_WIDTH    = 1200
config.WINDOW_HEIGHT   = 800

-- ============================================================
--  UI LAYOUT (menu bar, tool panel, status bar)
-- ============================================================
config.MENUBAR_HEIGHT  = 36
config.TOOL_PANEL_WIDTH = 240
config.STATUSBAR_HEIGHT = 28

config.GAME_WIDTH      = config.WINDOW_WIDTH - config.TOOL_PANEL_WIDTH
config.GAME_HEIGHT     = config.WINDOW_HEIGHT - config.STATUSBAR_HEIGHT - config.MENUBAR_HEIGHT

-- ============================================================
--  TILE TYPES
-- ============================================================
config.VOID   = 0
config.FLOOR  = 1

-- ============================================================
--  TOOL MODES
-- ============================================================
config.TOOL_NONE   = "none"
config.TOOL_LAMP   = "lamp"
config.TOOL_ENTITY = "entity"
config.TOOL_BUILD  = "build"
config.TOOL_REMOVE = "remove"
config.TOOL_FOOD   = "food"
config.TOOL_EXIT   = "exit"

-- ============================================================
--  RESOURCE COSTS
-- ============================================================
config.BUILD_COST_PER_TILE = 0.05   -- Familiarity spent per floor tile built
config.ENTITY_COST         = 0.2    -- Unease spent per entity placed
config.REMOVE_REFUND       = 0.03   -- Familiarity regained per tile removed

-- ============================================================
--  STARTING ROOM
-- ============================================================
config.START_ROOM_RADIUS = 2

-- ============================================================
--  SPAWNING & AI INTERVALS
-- ============================================================
config.SPAWN_INTERVAL        = 15
config.AI_INTERVAL           = 0.2
config.DENIZEN_SPAWN_MIN_LIGHT = 0.3

-- ============================================================
--  DENIZEN BEHAVIOUR
-- ============================================================
config.HIDING_DURATION         = 1.5
config.HIDE_COOLDOWN_DURATION  = 5
config.HIDING_DESPAIR_MULT     = 0.3

config.DENIZEN_SIGHT_RANGE     = 100
config.AVOID_DESPAIR_THRESHOLD = 0.5
config.AVOID_LOOK_AHEAD        = 1.0
config.AVOID_STRENGTH          = 2.0
config.FEAR_DURATION           = 5

-- Corpse
config.CORPSE_DESPAIR_RADIUS = 80
config.CORPSE_DESPAIR_PER_SEC = 0.1

-- Social
config.SOCIAL_RADIUS = 50          -- denizens within this distance count as "grouped"

-- Psychosis
config.PSYCHOTIC_DURATION = 15     -- seconds before a psychotic denizen becomes an entity
config.PSYCHOTIC_SPEED_MULT = 2.0  -- how fast they move

-- Freeze to corpse
config.FREEZE_DURATION = 10        -- seconds before a frozen denizen dies

-- Denizen names (just a small list)
config.DENIZEN_NAMES = {
    "Alan", "Brenda", "Charlie", "Dana", "Eli",
    "Frankie", "Gary", "Heather", "Ian", "Jasper",
    "Kael", "Lumen", "Mara", "Nick", "Oscar",
    "Piper", "Quinn", "Rowan", "Sage", "Thomas",
    "Andy", "Tim", "Kev", "Jags"
}

-- Personalities (affect behavior slightly)
config.PERSONALITIES = {
    brave   = { anxietyMult = 0.7, fleeSpeed = 1.2 },
    nervous = { anxietyMult = 1.3, hideCooldown = 0.5 },
    curious = { exploreRange = 1.5 },
    stoic   = { despairResist = 0.5 },   -- despair rises slower
    fragile = { despairMult = 1.5 }
}

-- ============================================================
--  DESPAIR & COMFORT
-- ============================================================
config.BASE_DESPAIR_RATE   = 0.02
config.COMFORT_CLOSE       = 80
config.COMFORT_FAR         = 150
config.CLOSE_COMFORT_DELTA = -0.04
config.FAR_COMFORT_DELTA   = -0.01
config.DESPAIR_MIN         = 0.05
config.DESPAIR_MAX         = 0.95
config.SWEET_SPOT_LOW      = 0.3
config.SWEET_SPOT_HIGH     = 0.7

-- ============================================================
--  ENTITY DEFAULTS (placed entities start with these)
-- ============================================================
config.ENTITY_DEFAULTS = {
    speed          = 50,
    radius         = 100,
    despairPerSec  = 0.05,
    aggression     = 1,           -- 0 = never chase, 1 = always chase within radius
    lightAvoidance = -1,          -- -1 = flee light, 0 = neutral, +1 = seek light
    hearingRange   = 300,         -- per‑entity hearing range (pixels)
}

-- ============================================================
--  WITNESS REACTIONS (denizens seeing tile changes)
-- ============================================================
config.WITNESS_ANXIETY_SPIKE = 0.4
config.WITNESS_DESPAIR_SPIKE = 0.3
config.WITNESS_SIGHT_RANGE   = 200

-- ============================================================
--  RESOURCE LOOP (Familiarity, Unease, Dread)
-- ============================================================
config.FAMILIARITY_SPAWN_MULT = 2.0
config.UNEASE_SPEED_BOOST     = 0.5
config.ANXIETY_LIGHT_RECOVERY = 0.1
config.ANXIETY_DARK_GAIN      = 0.2
config.DREAD_SPAWN_THRESHOLD  = 0.6
config.DREAD_SPAWN_INTERVAL   = 10
config.DREAD_SPAWN_CHANCE     = 0.5
config.DREAD_SPAWN_MIN_LIGHT  = 0.1

-- ============================================================
--  FOOD (reduces despair & anxiety)
-- ============================================================
config.FOOD_RADIUS            = 60
config.FOOD_DESPAIR_REDUCTION = 0.05
config.FOOD_ANXIETY_REDUCTION = 0.05

-- ============================================================
--  EXITS (denizens escape here)
-- ============================================================
config.EXIT_DETECTION_RANGE   = 250
config.EXIT_ESCAPE_DISTANCE   = 20
config.EXIT_FAMILIARITY_BOOST = 0.1

-- ============================================================
--  LIGHTING
-- ============================================================
config.LIGHT_DECAY_PER_TILE = 0.15
config.LIGHT_MIN_AMBIENT    = 0.03

-- ============================================================
--  COLOURS
-- ============================================================
config.COL_VOID    = {0.05, 0.05, 0.08}
config.COL_FLOOR   = {0.78, 0.71, 0.55}
config.COL_LAMP    = {0.91, 0.78, 0.38}
config.COL_ENTITY  = {0.4, 0.27, 0.53}
config.COL_ENTITY_RADIUS = {0.4, 0.27, 0.53, 0.2}

config.DENIZEN_COLOR_LOW  = {0.53, 0.67, 0.8}
config.DENIZEN_COLOR_HIGH = {0.8, 0.2, 0.2}

-- UI colours
config.COL_UI_BG         = {0.17, 0.17, 0.17}
config.COL_UI_TEXT       = {0.8, 0.8, 0.8}
config.COL_UI_BUTTON     = {0.3, 0.3, 0.3}
config.COL_UI_BUTTON_HI  = {0.45, 0.45, 0.3}   -- selected / hover
config.COL_UI_BEVEL_HI   = {0.6, 0.6, 0.6}     -- bevel light edge
config.COL_UI_BEVEL_LO   = {0.1, 0.1, 0.1}     -- bevel dark edge

-- Slider style
config.SLIDER_TRACK_COLOR = {0.4, 0.4, 0.4}
config.SLIDER_HANDLE_W    = 12
config.SLIDER_HANDLE_COLOR = {0.6, 0.6, 0.6}

return config