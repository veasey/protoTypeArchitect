-- postfx.lua
-- CRT/VHS effect with safe uniform checking and fallback.

local postfx = {}
local shader
local canvas
local noiseTex
local enabled = true

function postfx.load()
    local w, h = love.graphics.getDimensions()
    canvas = love.graphics.newCanvas(w, h)

    -- Generate noise texture
    local noiseData = love.image.newImageData(128, 128)
    for y = 0, 127 do
        for x = 0, 127 do
            local v = love.math.random()
            noiseData:setPixel(x, y, v, v, v, 1)
        end
    end
    noiseTex = love.graphics.newImage(noiseData)
    noiseTex:setWrap("repeat", "repeat")
    noiseTex:setFilter("linear", "linear")

    -- Shader code
    local pixelcode = [[
        extern number time;
        extern vec2 resolution;
        extern Image noise;

        float hash(vec2 p) {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
        }

        vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 screen_coord) {
            vec2 uv = texcoord;

            float chromaStrength = 0.002;
            float r = Texel(texture, uv + vec2(chromaStrength, 0.0)).r;
            float g = Texel(texture, uv).g;
            float b = Texel(texture, uv - vec2(chromaStrength, 0.0)).b;
            vec3 col = vec3(r, g, b);

            float scanline = sin(uv.y * resolution.y * 1.5) * 0.05 + 0.95;
            col *= scanline;

            float vignette = smoothstep(0.8, 0.2, length(uv - 0.5) * 1.5);
            col *= mix(0.3, 1.0, vignette);

            float noiseVal = Texel(noise, uv * 5.0 + fract(time * 0.1)).r;
            col += (noiseVal - 0.5) * 0.08;

            float glitch = 0.0;
            if (hash(vec2(floor(uv.y * 20.0), floor(time * 2.0))) < 0.1) {
                glitch = (hash(vec2(uv.y, time)) - 0.5) * 0.03;
            }
            col = vec3(
                Texel(texture, uv + vec2(glitch, 0.0)).r,
                Texel(texture, uv).g,
                Texel(texture, uv - vec2(glitch, 0.0)).b
            );

            col = mix(col, vec3(col.r, col.g * 0.9, col.b * 0.8), 0.1);

            return vec4(col, 1.0) * color;
        }
    ]]

    -- Try to create the shader; if it fails, disable CRT completely
    local ok, result = pcall(love.graphics.newShader, pixelcode)
    if ok then
        shader = result
        -- Quick test: if any of the required uniforms are missing, disable the effect
        if not shader:hasUniform("time") or not shader:hasUniform("resolution") or not shader:hasUniform("noise") then
            enabled = false
            print("CRT shader missing uniforms – disabling post‑fx.")
        end
    else
        enabled = false
        print("CRT shader failed to compile – disabling post‑fx. Error: " .. tostring(result))
    end
end

function postfx.beginCapture()
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
end

function postfx.endCapture()
    love.graphics.setCanvas()
end

function postfx.apply(dt)
    if not enabled then
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(canvas)
        return
    end

    -- Only send uniforms that exist (extra safety)
    if shader:hasUniform("time") then
        shader:send("time", love.timer.getTime())
    end
    local w, h = love.graphics.getDimensions()
    if shader:hasUniform("resolution") then
        shader:send("resolution", {w, h})
    end
    if shader:hasUniform("noise") then
        shader:send("noise", noiseTex)
    end

    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas)
    love.graphics.setShader()
end

return postfx