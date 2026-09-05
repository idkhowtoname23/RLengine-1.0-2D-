local ffi = require("ffi")

ffi.cdef[[
    typedef struct {
        float x, y;
        uint8_t r, g, b, a;
    } Vertex;

    typedef struct {
        float vx, vy;
    } Velocity;
]]

RLengine = {
    _VERSION = "1.0",
    count = 0,
    maxCount = 10000000,
    autoSpawn = false,
    bounds = {w = 1280, h = 720},
    forceMode = 0,
    camera = {x = 0, y = 0, zoom = 1, shake = 0}
}

function RLengine.init(w, h)
    RLengine.bounds.w = w or love.graphics.getWidth()
    RLengine.bounds.h = h or love.graphics.getHeight()

    local vertexSize = ffi.sizeof("Vertex")
    local velSize = ffi.sizeof("Velocity")
    
    
    RLengine.data = love.data.newByteData(vertexSize * RLengine.maxCount)
    RLengine.velData = love.data.newByteData(velSize * RLengine.maxCount)
    
    RLengine.ptr = ffi.cast("Vertex*", RLengine.data:getFFIPointer())
    RLengine.velPtr = ffi.cast("Velocity*", RLengine.velData:getFFIPointer())

    local layout = {
        {"VertexPosition", "float", 2},
        {"VertexColor", "byte", 4}
    }

    RLengine.mesh = love.graphics.newMesh(layout, RLengine.maxCount, "points", "stream")
    RLengine.addEntities(1000000)
end

function RLengine.addEntities(amount)
    local target = math.min(RLengine.maxCount, RLengine.count + amount)
    local ptr = RLengine.ptr
    local velPtr = RLengine.velPtr
    local bw, bh = RLengine.bounds.w, RLengine.bounds.h

    for i = RLengine.count, target - 1 do
        local p = ptr[i]
        local v = velPtr[i]
        p.x = math.random(10, bw - 10)
        p.y = math.random(10, bh - 10)
        v.vx = math.random(-150, 150)
        v.vy = math.random(-150, 150)
        p.r = math.random(80, 255)
        p.g = math.random(80, 255)
        p.b = math.random(200, 255)
        p.a = 255
    end

    RLengine.count = target
end

function RLengine.removeEntities(amount)
    RLengine.count = math.max(0, RLengine.count - amount)
end

function RLengine.triggerShake(intensity)
    RLengine.camera.shake = intensity
end

function RLengine.update(dt)
    if RLengine.autoSpawn then
        RLengine.addEntities(100000)
    end

    local count = RLengine.count
    if count == 0 then return end

    local ptr = RLengine.ptr
    local velPtr = RLengine.velPtr
    local bw = RLengine.bounds.w - 2
    local bh = RLengine.bounds.h - 2

    local mx, my = love.mouse.getPosition()
    local cam = RLengine.camera
    local worldMx = (mx - RLengine.bounds.w * 0.5) / cam.zoom + RLengine.bounds.w * 0.5 - cam.x
    local worldMy = (my - RLengine.bounds.h * 0.5) / cam.zoom + RLengine.bounds.h * 0.5 - cam.y
    
    local isLmb = love.mouse.isDown(1)
    local isRmb = love.mouse.isDown(2)
    local forceMode = RLengine.forceMode

    if cam.shake > 0 then
        cam.shake = cam.shake - dt * 30
        if cam.shake < 0 then cam.shake = 0 end
    end

    local applyForce = isLmb or isRmb or forceMode ~= 0
    local baseForce = 5000000
    if isRmb or forceMode == -1 then
        baseForce = -5000000
    end

    local damp = 1 - dt * 0.25

    
    if applyForce then
        for i = 0, count - 1 do
            local p = ptr[i]
            local v = velPtr[i]

            local dx = worldMx - p.x
            local dy = worldMy - p.y
            local distSq = dx * dx + dy * dy + 100
            local force = (baseForce / distSq) * dt
            
            local vx = (v.vx + dx * force) * damp
            local vy = (v.vy + dy * force) * damp

            local px = p.x + vx * dt
            local py = p.y + vy * dt

            if px < 2 then px = 2; vx = -vx * 0.85 elseif px > bw then px = bw; vx = -vx * 0.85 end
            if py < 2 then py = 2; vy = -vy * 0.85 elseif py > bh then py = bh; vy = -vy * 0.85 end

            v.vx = vx; v.vy = vy
            p.x = px; p.y = py
        end
    else
        for i = 0, count - 1 do
            local p = ptr[i]
            local v = velPtr[i]

            local vx = v.vx * damp
            local vy = v.vy * damp

            local px = p.x + vx * dt
            local py = p.y + vy * dt

            if px < 2 then px = 2; vx = -vx * 0.85 elseif px > bw then px = bw; vx = -vx * 0.85 end
            if py < 2 then py = 2; vy = -vy * 0.85 elseif py > bh then py = bh; vy = -vy * 0.85 end

            v.vx = vx; v.vy = vy
            p.x = px; p.y = py
        end
    end

    RLengine.mesh:setVertices(RLengine.data, 1, count)
end

function RLengine.draw()
    local cam = RLengine.camera
    love.graphics.push()
    
    local rx = (math.random() - 0.5) * cam.shake
    local ry = (math.random() - 0.5) * cam.shake
    
    love.graphics.translate(RLengine.bounds.w * 0.5 + rx, RLengine.bounds.h * 0.5 + ry)
    love.graphics.scale(cam.zoom)
    love.graphics.translate(-RLengine.bounds.w * 0.5 + cam.x, -RLengine.bounds.h * 0.5 + cam.y)

    if RLengine.count > 0 then
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.setPointSize(1)
        RLengine.mesh:setDrawRange(1, RLengine.count)
        love.graphics.draw(RLengine.mesh)
    end

    love.graphics.pop()

    local memMB = collectgarbage("count") / 1024

    love.graphics.setColor(0, 0, 0, 0.85)
    love.graphics.rectangle("fill", 10, 10, 440, 190)

    love.graphics.setColor(0, 1, 0.5)
    love.graphics.print("RLengine 1.0 | COMPLETE 10M ENGINE", 20, 20)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print("FPS: " .. love.timer.getFPS() .. " (" .. string.format("%.2f", 1000 / math.max(1, love.timer.getFPS())) .. " ms)", 20, 45)
    love.graphics.print("Active Entities: " .. RLengine.count .. " / 10000000", 20, 65)
    love.graphics.print("Lua Memory: " .. string.format("%.2f MB", memMB), 20, 85)
    love.graphics.print("Camera Zoom: " .. string.format("%.2fx", cam.zoom), 20, 105)
    love.graphics.print("[LMB / RMB] Attract / Repel", 20, 130)
    love.graphics.print("[UP / DOWN] +500k / -500k objects", 20, 150)
    love.graphics.print("[Wheel] Zoom | [WASD] Cam | [E] Shake | [F] Force", 20, 170)
end

function love.load()
    love.window.setMode(1280, 720, {resizable = false, vsync = false})
    love.window.setTitle("RLengine 1.0 - Full Featured 10M Build")
    RLengine.init()
end

function love.update(dt)
    local cam = RLengine.camera
    local speed = 400 * dt / cam.zoom
    if love.keyboard.isDown("w") then cam.y = cam.y + speed end
    if love.keyboard.isDown("s") then cam.y = cam.y - speed end
    if love.keyboard.isDown("a") then cam.x = cam.x + speed end
    if love.keyboard.isDown("d") then cam.x = cam.x - speed end

    RLengine.update(dt)
end

function love.draw()
    RLengine.draw()
end

function love.wheelmoved(x, y)
    local cam = RLengine.camera
    if y > 0 then
        cam.zoom = math.min(5.0, cam.zoom * 1.1)
    elseif y < 0 then
        cam.zoom = math.max(0.2, cam.zoom / 1.1)
    end
end

function love.keypressed(key)
    if key == "up" then
        RLengine.addEntities(500000)
    elseif key == "down" then
        RLengine.removeEntities(500000)
    elseif key == "space" then
        RLengine.autoSpawn = not RLengine.autoSpawn
    elseif key == "e" then
        RLengine.triggerShake(15)
    elseif key == "f" then
        RLengine.triggerShake(25)
        RLengine.forceMode = (RLengine.forceMode == 0) and 1 or 0
    elseif key == "r" then
        RLengine.camera.x = 0
        RLengine.camera.y = 0
        RLengine.camera.zoom = 1
        RLengine.forceMode = 0
    end
end
