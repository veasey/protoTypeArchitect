-- audio.lua
-- Data-driven sound manager. Add new sounds by editing the `sounds` table.

local audio = {}
local managedSources = {}
local lampLoops = {}
local lampHumSource  -- special: prototype for cloned lamp hums (mono)

-- ============================================================
--  Tiny helpers
-- ============================================================
local function generateTone(freq, duration, loop)
    local sampleRate = 44100
    local samples = math.floor(duration * sampleRate)
    local sd = love.sound.newSoundData(samples, sampleRate, 16, 1)
    for i = 0, samples - 1 do
        local t = i / sampleRate
        sd:setSample(i, math.sin(2 * math.pi * freq * t) * 0.3)
    end
    local src = love.audio.newSource(sd)
    if loop then src:setLooping(true) end
    return src
end

local function toMono(soundData)
    if soundData:getChannelCount() == 1 then return soundData end
    local mono = love.sound.newSoundData(soundData:getSampleCount(), soundData:getSampleRate(), 16, 1)
    for i = 0, soundData:getSampleCount() - 1 do
        local sum = 0
        for c = 1, soundData:getChannelCount() do
            sum = sum + soundData:getSample(i, c)
        end
        mono:setSample(i, sum / soundData:getChannelCount())
    end
    return mono
end

-- ============================================================
--  Sound registry – just add entries here to create a new sound
-- ============================================================
local sounds = {
    build = {
        file = "sounds/squelch.mp3",
        fallback = { freq = 220, duration = 0.4, loop = false },
        stopFunc = true,   -- creates stopBuildSound()
    },
    lampPlace = {
        file = "sounds/light_on.wav",
        fallback = { freq = 440, duration = 0.2 },
    },
    entityPlace = {
        file = "sounds/slime_monster_1.wav",
        fallback = { freq = 880, duration = 0.1 },
    },
    -- Chase sound – key "roar" → playRoarSound() & stopRoarSound()
    roar = {
        file = "sounds/roar.mp3",
        fallback = { freq = 980, duration = 0.3, loop = true },
        mono = true,
        stopFunc = true,
    },
    -- Denizen enter/leave – key "denizenEnterLeave" → playDenizenEnterLeaveSound()
    denizenEnterLeave = {
        file = "sounds/noclip.mp3",
        fallback = nil,   -- no fallback
        stopFunc = true,  -- creates stopDenizenEnterLeaveSound()
    },
    foodPlace = {
        file = "sounds/food_place.mp3",
        fallback = nil,
        stopFunc = false,
    },
    exitPlace = {
        file = "sounds/exit_place.mp3",
        fallback = nil,
        stopFunc = false,
    },
}

-- This will hold the loaded sources, keyed by sound name
audio.sources = {}

-- ============================================================
--  Load everything automatically
-- ============================================================
function audio.load()
    for name, snd in pairs(sounds) do
        local source = nil

        -- Try to load the file
        if snd.file and love.filesystem.getInfo(snd.file) then
            if snd.mono then
                local sd = love.sound.newSoundData(snd.file)
                local monoSD = toMono(sd)
                source = love.audio.newSource(monoSD)
                if snd.fallback and snd.fallback.loop then
                    source:setLooping(true)
                end
            else
                source = love.audio.newSource(snd.file, "static")
            end
            print("Loaded " .. name .. " sound: " .. snd.file)
        elseif snd.fallback then
            print(name .. " sound not found, using fallback tone.")
            source = generateTone(snd.fallback.freq, snd.fallback.duration, snd.fallback.loop)
        else
            print(name .. " sound not found – skipping.")
        end

        if source then
            audio.sources[name] = source
            table.insert(managedSources, source)

            -- Create play function: audio.play<Name>Sound()
            local playName = "play" .. name:sub(1,1):upper() .. name:sub(2) .. "Sound"
            audio[playName] = function()
                if audio.sources[name] then
                    print("Playing " .. name .. " sound")
                    audio.sources[name]:stop()
                    audio.sources[name]:play()
                end
            end

            -- Create stop function if requested: audio.stop<Name>Sound()
            if snd.stopFunc then
                local stopName = "stop" .. name:sub(1,1):upper() .. name:sub(2) .. "Sound"
                audio[stopName] = function()
                    if audio.sources[name] then
                        print("Stopping " .. name .. " sound")
                        audio.sources[name]:stop()
                    end
                end
            end
        end
    end

    -- ============================================================
    --  Lamp hum – special because it gets cloned for each lamp
    -- ============================================================
    local humFile = "sounds/light_hum.wav"
    if love.filesystem.getInfo(humFile) then
        local sd = love.sound.newSoundData(humFile)
        local monoSD = toMono(sd)
        lampHumSource = love.audio.newSource(monoSD)
        lampHumSource:setLooping(true)
        print("Loaded lamp hum: " .. humFile)
    else
        print("Lamp hum not found, using fallback low drone.")
        lampHumSource = generateTone(55, 2, true)
    end
end

-- ============================================================
--  Manually written functions (lamp hum, pause, etc.)
-- ============================================================
function audio.addLampLoop(lamp)
    if not lampHumSource then return end
    print("Adding lamp loop for lamp at " .. lamp.x .. "," .. lamp.y)
    local source = lampHumSource:clone()
    source:setLooping(true)
    source:setRelative(true)
    source:play()
    table.insert(lampLoops, { source = source, lamp = lamp })
    table.insert(managedSources, source)
end

function audio.removeLampLoop(lamp)
    for i, entry in ipairs(lampLoops) do
        if entry.lamp == lamp then
            print("Removing lamp loop for lamp at " .. lamp.x .. "," .. lamp.y)
            entry.source:stop()
            for j, src in ipairs(managedSources) do
                if src == entry.source then
                    table.remove(managedSources, j)
                    break
                end
            end
            table.remove(lampLoops, i)
            break
        end
    end
end

function audio.updateLampLoops(cameraX, cameraY, zoom, gameWidth, gameHeight)
    local maxDist = gameWidth * 0.7
    for _, entry in ipairs(lampLoops) do
        local lamp = entry.lamp
        local source = entry.source
        local dx = (lamp.x - cameraX) * zoom
        local dy = (lamp.y - cameraY) * zoom
        local dist = math.sqrt(dx*dx + dy*dy)
        local vol = math.max(0, 1 - dist / maxDist)
        source:setVolume(vol)
        -- source:setPosition(dx, dy, 0)  -- re-enable if mono spatial works
    end
end

function audio.pauseAll()
    for _, src in ipairs(managedSources) do
        if src then
            if src.pause then src:pause()
            elseif love.audio.pause then love.audio.pause(src)
            else src:stop() end
        end
    end
end

function audio.resumeAll()
    for _, src in ipairs(managedSources) do
        if src then
            if src.resume then src:resume()
            elseif love.audio.resume then love.audio.resume(src)
            end
        end
    end
end

-- ============================================================
--  Safety net: ensure all expected sound functions exist
-- ============================================================
local requiredFunctions = {
    playBuildSound = "build",
    stopBuildSound = "build",
    playLampPlaceSound = "lampPlace",
    playEntityPlaceSound = "entityPlace",
    playEntityChaseSound = "roar",
    stopEntityChaseSound = "roar",
    playDenizenEnterLeaveSound = "denizenEnterLeave",
    stopDenizenEnterLeaveSound = "denizenEnterLeave",
    playFoodPlaceSound = "foodPlace",
    playExitPlaceSound = "exitPlace",
}

for funcName, sourceKey in pairs(requiredFunctions) do
    if not audio[funcName] then
        -- Create a dummy function that does nothing (or logs)
        audio[funcName] = function()
            print("Warning: sound '" .. funcName .. "' not loaded, doing nothing.")
        end
    end
end

return audio