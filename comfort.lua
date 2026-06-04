local cfg = require("config")

local Comfort = {}
Comfort.__index = Comfort

function Comfort.create(x, y)
    local self = setmetatable({}, Comfort)
    self.x = x
    self.y = y
    return self
end

-- Drawing is done externally in draw.lua for consistency
return Comfort