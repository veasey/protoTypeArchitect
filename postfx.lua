-- postfx.lua
-- Applies CRT/VHS effects to the final render.

local postfx = {}

local shader
local canvas
local noiseTex
local glitchTimer = 0
local glitchActive = true
local glitchStrength = 0

function postfx.load()
    -- Create a canvas matching the window
    local w, h = love.graphics.getDimensions()
    canvas = love.graphics.newCanvas(w, h)

    -- Generate a small noise texture
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

    -- The GLSL fragment shader
    local pixelcode = [[
        extern number time;
        extern vec2 resolution;
        extern Image noise;

        // Pseudo-random hash
        float hash(vec2 p) {
            return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
        }

        vec4 effect(vec4 color, Image texture, vec2 texcoord, vec2 screen_coord) {
            vec2 uv = texcoord;

            // Chromatic aberration
            float chromaStrength = 0.002;
            float r = Texel(texture, uv + vec2(chromaStrength, 0.0)).r;
            float g = Texel(texture, uv).g;
            float b = Texel(texture, uv - vec2(chromaStrength, 0.0)).b;
            vec3 col = vec3(r, g, b);

            // Scanlines
            float scanline = sin(uv.y * resolution.y * 1.5) * 0.05 + 0.95;
            col *= scanline;

            // Vignette (dark border)
            float vignette = smoothstep(0.8, 0.2, length(uv - 0.5) * 1.5);
            col *= mix(0.3, 1.0, vignette);

            // Noise from texture
            float noiseVal = Texel(noise, uv * 5.0 + fract(time * 0.1)).r;
            col += (noiseVal - 0.5) * 0.08;

            // Occasional glitch: random horizontal displacement
            float glitch = 0.0;
            if (hash(vec2(floor(uv.y * 20.0), floor(time * 2.0))) < 0.1) {
                glitch = (hash(vec2(uv.y, time)) - 0.5) * 0.03;
            }
            col = vec3(
                Texel(texture, uv + vec2(glitch, 0.0)).r,
                Texel(texture, uv).g,
                Texel(texture, uv - vec2(glitch, 0.0)).b
            );

            // Slight colour bleeding
            col = mix(col, vec3(col.r, col.g * 0.9, col.b * 0.8), 0.1);

            return vec4(col, 1.0) * color;
        }
    ]]

    shader = love.graphics.newShader(pixelcode)
    shader:send("noise", noiseTex)
end

function postfx.beginCapture()
    love.graphics.setCanvas(canvas)
    love.graphics.clear()
end

function postfx.endCapture()
    love.graphics.setCanvas()
end

function postfx.apply(dt)
    local w, h = love.graphics.getDimensions()
    shader:send("time", love.timer.getTime())
    shader:send("resolution", {w, h})
    love.graphics.setShader(shader)
    love.graphics.setColor(1, 1, 1)
    love.graphics.draw(canvas)
    love.graphics.setShader()
end

return postfx