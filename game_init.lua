-- game_init.lua
local map = require("map")
local Comfort = require("comfort")
local audio = require("audio")

local function init(game)
    map.generate()
    local cx = math.floor(require("config").MAP_COLS / 2)
    local cy = math.floor(require("config").MAP_ROWS / 2)
    local wx, wy = map.tileToWorld(cx, cy)
    game.addComfort(wx, wy)
    game.computeLighting()
end

return init