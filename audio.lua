-- audio.lua
-- Hard-coded sound manager for absolute reliability.

local audio = {}
local managedSources = {}
local lampLoops = {}
local lampHumSource  -- prototype for cloned lamp hums (mono)

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
--  Load all sound files
-- ============================================================
function audio.load()
    local function safeLoad(filename)
        if love.filesystem.getInfo(filename) then
            local src = love.audio.newSource(filename, "static")
            table.insert(managedSources, src)
            return src
        end
        return nil
    end

    audio.buildSound = safeLoad("sounds/squelch.mp3") or generateTone(220, 0.4, false)
    audio.lampPlaceSound = safeLoad("sounds/light_on.wav") or generateTone(440, 0.2, false)
    audio.entityPlaceSound = safeLoad("sounds/slime_monster_1.wav") or generateTone(880, 0.1, false)

    -- Chase sound (roar)
    local roarFile = "sounds/roar.mp3"
    if love.filesystem.getInfo(roarFile) then
        local sd = love.sound.newSoundData(roarFile)
        local monoSD = toMono(sd)
        audio.roarSound = love.audio.newSource(monoSD)
        table.insert(managedSources, audio.roarSound)
    else
        audio.roarSound = generateTone(980, 0.3, true)
    end

    -- Denizen enter/leave sound (noclip)
    local noclipFile = "sounds/noclip.mp3"
    if love.filesystem.getInfo(noclipFile) then
        audio.noclipSound = safeLoad(noclipFile)
    else
        audio.noclipSound = nil
    end

    -- Food place sound
    audio.foodPlaceSound = safeLoad("sounds/food_place.mp3")
    -- Exit place sound
    audio.exitPlaceSound = safeLoad("sounds/exit_place.mp3")

    -- Lamp hum (mono for spatial cloning)
    local humFile = "sounds/light_hum.wav"
    if love.filesystem.getInfo(humFile) then
        local sd = love.sound.newSoundData(humFile)
        local monoSD = toMono(sd)
        lampHumSource = love.audio.newSource(monoSD)
        lampHumSource:setLooping(true)
    else
        lampHumSource = generateTone(55, 2, true)
    end
end

-- ============================================================
--  Explicit sound functions
-- ============================================================
function audio.playBuildSound()
    if audio.buildSound then audio.buildSound:stop(); audio.buildSound:play() end
end
function audio.stopBuildSound()
    if audio.buildSound then audio.buildSound:stop() end
end

function audio.playLampPlaceSound()
    if audio.lampPlaceSound then audio.lampPlaceSound:stop(); audio.lampPlaceSound:play() end
end

function audio.playEntityPlaceSound()
    if audio.entityPlaceSound then audio.entityPlaceSound:stop(); audio.entityPlaceSound:play() end
end

function audio.playRoarSound()
    if audio.roarSound then audio.roarSound:stop(); audio.roarSound:play() end
end
function audio.stopRoarSound()
    if audio.roarSound then audio.roarSound:stop() end
end

function audio.playDenizenEnterLeaveSound()
    if audio.noclipSound then audio.noclipSound:stop(); audio.noclipSound:play() end
end
function audio.stopDenizenEnterLeaveSound()
    if audio.noclipSound then audio.noclipSound:stop() end
end

function audio.playFoodPlaceSound()
    if audio.foodPlaceSound then audio.foodPlaceSound:stop(); audio.foodPlaceSound:play() end
end
function audio.playExitPlaceSound()
    if audio.exitPlaceSound then audio.exitPlaceSound:stop(); audio.exitPlaceSound:play() end
end

-- ============================================================
--  Lamp hum (cloned per lamp)
-- ============================================================
function audio.addLampLoop(lamp)
    if not lampHumSource then return end
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
    end
end

-- ============================================================
--  Pause / Resume
-- ============================================================
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

-- wrapper (cannot remember what was the original name of this function)
function audio.playEntityChaseSound()
    audio.playRoarSound()
end

function audio.stopEntityChaseSound()
    audio.stopRoarSound()
end


return audio