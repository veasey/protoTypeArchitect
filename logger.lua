-- logger.lua
-- Writes structured event logs to a file.

local logger = {}

local LOG_FILE = "backrooms_log.txt"

function logger.logDenizen(name, personality, events, cause)
    local f = io.open(LOG_FILE, "a")
    if not f then return end
    f:write("===== DENIZEN: " .. name .. " (" .. personality .. ") =====\n")
    f:write("Cause: " .. cause .. "\n")
    for _, ev in ipairs(events) do
        f:write("  " .. ev .. "\n")
    end
    f:write("\n")
    f:close()
end

function logger.logEntity(state, events, cause)
    local f = io.open(LOG_FILE, "a")
    if not f then return end
    f:write("===== ENTITY (" .. state .. ") =====\n")
    f:write("Cause: " .. cause .. "\n")
    for _, ev in ipairs(events) do
        f:write("  " .. ev .. "\n")
    end
    f:write("\n")
    f:close()
end

return logger