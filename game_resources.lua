-- game_resources.lua
local map = require("map")
local util = require("util")
local cfg = require("config")

local resources = {}

function resources.compute(game, dt)
    local totalFamiliarityScore = 0
    local totalAnxiety = 0
    local totalDespair = 0
    local denCount = #game.denizens
    if denCount > 0 then
        for _, den in ipairs(game.denizens) do
            local tileX, tileY = map.worldToTile(den.x, den.y)
            local light = math.max(game.lightmap[tileY] and game.lightmap[tileY][tileX] or 0, cfg.LIGHT_MIN_AMBIENT)
            local social = (den.nearbyDenizenCount > 0) and 1 or 0
            local score = 0.6 * light + 0.4 * social
            totalFamiliarityScore = totalFamiliarityScore + score
            totalAnxiety = totalAnxiety + den.profile.anxiety
            totalDespair = totalDespair + den.profile.despair

            if den.bondFormed then
                game.familiarity = math.min(1, game.familiarity + cfg.BOND_FAMILIARITY_BOOST)
                den.bondFormed = nil
            end
        end

        local targetFamiliarity = math.max(0, math.min(1, totalFamiliarityScore / denCount))
        local targetUnease = math.max(0, math.min(1, totalAnxiety / denCount))
        local targetDread = math.max(0, math.min(1, totalDespair / denCount))

        local maxChange = 0.05 * dt
        game.familiarity = game.familiarity + util.clamp(targetFamiliarity - game.familiarity, -maxChange, maxChange)
        game.unease = game.unease + util.clamp(targetUnease - game.unease, -maxChange, maxChange)
        game.dread = game.dread + util.clamp(targetDread - game.dread, -maxChange, maxChange)
    else
        game.familiarity = 0
        game.unease = 0
        game.dread = 0
    end

    -- Perfect equilibrium
    if game.familiarity >= 0.4 and game.familiarity <= 0.6
       and game.unease >= 0.4 and game.unease <= 0.6
       and game.dread >= 0.4 and game.dread <= 0.6 then
        game.perfectEquilibriumTimer = (game.perfectEquilibriumTimer or 0) + dt
    else
        game.perfectEquilibriumTimer = 0
    end

    -- Spendable resource regeneration
    local rechargeRate = 0.025 * dt
    if game.familiarityResource < game.familiarity then
        game.familiarityResource = math.min(game.familiarity, game.familiarityResource + rechargeRate)
    end
    if game.uneaseResource < game.unease then
        game.uneaseResource = math.min(game.unease, game.uneaseResource + rechargeRate)
    end
end

return resources