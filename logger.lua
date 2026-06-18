-- logger.lua
local logger = {}
logger.records = {}
logger.liveEntries = {}

local LOG_FILE = "backrooms_log.txt"
local LIVE_LOG_FILE = "backrooms_live.txt"

function logger.logLive(name, personality, event)
    local entry = {
        name = name,
        personality = personality,
        event = event,
        time = os.date("%H:%M:%S"),
    }
    table.insert(logger.liveEntries, entry)

    local f = io.open(LIVE_LOG_FILE, "a")
    if f then
        f:write(string.format("[%s] %s (%s): %s\n", entry.time, name, personality, event))
        f:close()
    end
end

function logger.logDenizen(name, personality, events, cause)
    local record = {
        type = "denizen",
        name = name,
        personality = personality,
        events = events,
        cause = cause,
    }
    table.insert(logger.records, record)

    local f = io.open(LOG_FILE, "a")
    if f then
        f:write("===== DENIZEN: " .. name .. " (" .. personality .. ") =====\n")
        f:write("Cause: " .. cause .. "\n")
        for _, ev in ipairs(events) do
            f:write("  " .. ev .. "\n")
        end
        f:write("\n")
        f:close()
    end
end

function logger.logEntity(state, events, cause)
    local record = {
        type = "entity",
        state = state,
        events = events,
        cause = cause,
    }
    table.insert(logger.records, record)

    local f = io.open(LOG_FILE, "a")
    if f then
        f:write("===== ENTITY (" .. state .. ") =====\n")
        f:write("Cause: " .. cause .. "\n")
        for _, ev in ipairs(events) do
            f:write("  " .. ev .. "\n")
        end
        f:write("\n")
        f:close()
    end
end

return logger