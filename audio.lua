-- audio.lua
-- Centralised sound manager with fallback tones if files missing.

local audio = {}

local buildSound         -- one-shot for build/remove
local lampPlaceSound     -- one-shot for placing a lamp
local lampHumSource      -- prototype source for looping lamp hum (mono)
local entityPlaceSound   -- one-shot for placing an entity

-- Active looping lamp sources: table of { source, lamp }
local lampLoops = {}

-- Helper: generate a simple sine-wave tone (mono, quiet)
local function generateTone(freq, duration, loop)
    local sampleRate = 44100
    local samples = math.floor(duration * sampleRate)
    local soundData = love.sound.newSoundData(samples, sampleRate, 16, 1)  -- mono
    for i = 0, samples - 1 do
        local t = i / sampleRate
        local sample = math.sin(2 * math.pi * freq * t) * 0.3
        soundData:setSample(i, sample)
    end
    local source = love.audio.newSource(soundData)
    if loop then source:setLooping(true) end
    return source
end

-- Helper: convert stereo SoundData to mono
local function toMono(soundData)
    if soundData:getChannelCount() == 1 then return soundData end
    local monoData = love.sound.newSoundData(
        soundData:getSampleCount(), soundData:getSampleRate(), 16, 1)
    for i = 0, soundData:getSampleCount() - 1 do
        local sum = 0
        for c = 1, soundData:getChannelCount() do
            sum = sum + soundData:getSample(i, c)
        end
        monoData:setSample(i, sum / soundData:getChannelCount())
    end
    return monoData
end

function audio.load()
    -- Build sound
    local file = "sounds/squelch.mp3"
    if love.filesystem.getInfo(file) then
        buildSound = love.audio.newSource(file, "static")
        print("Loaded build sound: " .. file)
    else
        print("Build sound not found, using fallback beep.")
        buildSound = generateTone(220, 0.4, false)
    end

    -- Lamp place sound
    file = "sounds/light_on.wav"
    if love.filesystem.getInfo(file) then
        lampPlaceSound = love.audio.newSource(file, "static")
        print("Loaded lamp place sound: " .. file)
    else
        print("Lamp place sound not found, using fallback ping.")
        lampPlaceSound = generateTone(440, 0.2, false)
    end

    -- Entity place sound
    file = "sounds/slime_monster_1.wav"
    if love.filesystem.getInfo(file) then
        entityPlaceSound = love.audio.newSource(file, "static")
        print("Loaded entity place sound: " .. file)
    else
        print("Entity place sound not found, using fallback click.")
        entityPlaceSound = generateTone(880, 0.1, false)
    end

    -- Lamp hum (must be mono for spatial audio)
    file = "sounds/light_hum.wav"
    if love.filesystem.getInfo(file) then
        local sd = love.sound.newSoundData(file)
        local monoSD = toMono(sd)
        lampHumSource = love.audio.newSource(monoSD)
        lampHumSource:setLooping(true)
        print("Loaded lamp hum: " .. file)
    else
        print("Lamp hum not found, using fallback low drone.")
        lampHumSource = generateTone(55, 2, true)  -- looping low hum
    end
end

-- Build / Remove sweep
function audio.playBuildSound()
    if buildSound then
        print("Playing build sound")
        buildSound:stop()
        buildSound:play()
    end
end

function audio.stopBuildSound()
    if buildSound then
        print("Stopping build sound")
        buildSound:stop()
    end
end

-- Lamp placement one-shot
function audio.playLampPlaceSound()
    if lampPlaceSound then
        print("Playing lamp place sound")
        lampPlaceSound:stop()
        lampPlaceSound:play()
    end
end

-- Entity placement one-shot
function audio.playEntityPlaceSound()
    if entityPlaceSound then
        print("Playing entity place sound")
        entityPlaceSound:stop()
        entityPlaceSound:play()
    end
end

-- Add a looping hum for a newly placed lamp
function audio.addLampLoop(lamp)
    if not lampHumSource then return end
    print("Adding lamp loop for lamp at " .. lamp.x .. "," .. lamp.y)
    local source = lampHumSource:clone()
    source:setLooping(true)
    source:setRelative(true)   -- safe because source is mono
    source:play()
    table.insert(lampLoops, { source = source, lamp = lamp })
end

-- Remove the hum associated with a specific lamp
function audio.removeLampLoop(lamp)
    for i, entry in ipairs(lampLoops) do
        if entry.lamp == lamp then
            print("Removing lamp loop for lamp at " .. lamp.x .. "," .. lamp.y)
            entry.source:stop()
            table.remove(lampLoops, i)
            break
        end
    end
end

-- Call this every frame to update positional audio for all lamp hums
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
        --source:setPosition(dx, dy, 0)
    end
end

return audio