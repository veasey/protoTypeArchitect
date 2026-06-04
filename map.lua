local cfg = require("config")
local map = {}

map.grid = {}

function map.generate()
    -- Entire world is void
    for r = 1, cfg.MAP_ROWS do
        map.grid[r] = {}
        for c = 1, cfg.MAP_COLS do
            map.grid[r][c] = cfg.VOID
        end
    end

    -- Create a small starting room (centered)
    local cx = math.floor(cfg.MAP_COLS / 2)
    local cy = math.floor(cfg.MAP_ROWS / 2)
    for r = cy - cfg.START_ROOM_RADIUS, cy + cfg.START_ROOM_RADIUS do
        for c = cx - cfg.START_ROOM_RADIUS, cx + cfg.START_ROOM_RADIUS do
            if r >= 1 and r <= cfg.MAP_ROWS and c >= 1 and c <= cfg.MAP_COLS then
                map.grid[r][c] = cfg.FLOOR
            end
        end
    end
end

function map.isWalkable(tileX, tileY)
    if tileX < 1 or tileX > cfg.MAP_COLS or tileY < 1 or tileY > cfg.MAP_ROWS then
        return false
    end
    return map.grid[tileY][tileX] == cfg.FLOOR
end

function map.isBuildable(tileX, tileY)
    -- Must be in bounds and currently void
    if tileX < 1 or tileX > cfg.MAP_COLS or tileY < 1 or tileY > cfg.MAP_ROWS then
        return false
    end
    return map.grid[tileY][tileX] == cfg.VOID
end

function map.setTile(tileX, tileY, type)
    if tileX < 1 or tileX > cfg.MAP_COLS or tileY < 1 or tileY > cfg.MAP_ROWS then
        return false
    end
    map.grid[tileY][tileX] = type
    return true
end

function map.tileToWorld(tileX, tileY)
    return (tileX - 1) * cfg.TILE_SIZE + cfg.TILE_SIZE/2,
           (tileY - 1) * cfg.TILE_SIZE + cfg.TILE_SIZE/2
end

function map.worldToTile(wx, wy)
    return math.floor(wx / cfg.TILE_SIZE) + 1,
           math.floor(wy / cfg.TILE_SIZE) + 1
end

-- Returns a list of all floor tile coordinates
function map.getAllFloorTiles()
    local tiles = {}
    for r = 1, cfg.MAP_ROWS do
        for c = 1, cfg.MAP_COLS do
            if map.grid[r][c] == cfg.FLOOR then
                table.insert(tiles, {x = c, y = r})
            end
        end
    end
    return tiles
end

return map