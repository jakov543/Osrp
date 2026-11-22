-- OSRP Osijek - spawns the Osijek city chunks (static, frozen) near the player

local spawned = {}
local missingWarned = false

local function chunkPos(c)
    return vector3(Config.Origin.x + c.x, Config.Origin.y + c.y, Config.Origin.z + c.z)
end

-- v1.0.16: nearest chunks first, all models requested in parallel (faster, no falling through the map)
local requested = {}

local function createChunk(c, hash)
    local p = chunkPos(c)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(obj, 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityLodDist(obj, 1000)
    SetModelAsNoLongerNeeded(hash)
    spawned[c.name] = obj
    requested[c.name] = nil
end

-- one streaming pass: request + create chunks within radius of (x, y), nearest first. returns loaded, total
local function streamPass(x, y, radius)
    local list = {}
    for _, c in ipairs(Layout) do
        local p = chunkPos(c)
        local d = #(vec2(p.x, p.y) - vec2(x, y))
        if d < radius then list[#list + 1] = { c = c, d = d } end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    local loaded = 0
    for _, e in ipairs(list) do
        local c = e.c
        local obj = spawned[c.name]
        if obj and DoesEntityExist(obj) then
            loaded = loaded + 1
        else
            local hash = joaat(c.name)
            if not IsModelInCdimage(hash) then
                if not missingWarned then
                    missingWarned = true
                    print('^3[OSRP Osijek]^7 Modeli nisu u stream/ mapi - pogledaj OSIJEK-MAPA-UPUTE.txt')
                end
            elseif HasModelLoaded(hash) then
                createChunk(c, hash)
                loaded = loaded + 1
            elseif not requested[c.name] or GetGameTimer() - requested[c.name] > 8000 then
                RequestModel(hash)
                requested[c.name] = GetGameTimer()
            end
        end
    end
    return loaded, #list
end

-- blocks until the city around (x, y) is loaded (used by osrp_framework while the screen is black)
function LoadArea(x, y, radius, timeout)
    local t = GetGameTimer()
    radius = radius or 350.0
    while GetGameTimer() - t < (timeout or 20000) do
        local loaded, total = streamPass(x, y, radius)
        TriggerEvent('osrp:mapLoading', loaded, total)
        if loaded >= total then
            RequestCollisionAtCoord(x, y, Config.Origin.z)
            Wait(300)
            return true
        end
        Wait(50)
    end
    return false
end
exports('LoadArea', LoadArea)

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        streamPass(pos.x, pos.y, Config.StreamDistance)
        for _, c in ipairs(Layout) do
            local obj = spawned[c.name]
            if obj and #(pos - chunkPos(c)) > Config.StreamDistance + 100.0 then
                if DoesEntityExist(obj) then DeleteObject(obj) end
                spawned[c.name] = nil
            end
        end
        Wait(250)
    end
end)

-- ---------- houses: GTA V doors, furniture, interior lights ----------
local doorObjs, furnObjs, firstValid = {}, {}, {}

local function firstModel(key, list)
    if firstValid[key] == nil then
        firstValid[key] = false
        for _, m in ipairs(list or {}) do
            if IsModelInCdimage(joaat(m)) then firstValid[key] = m break end
        end
    end
    return firstValid[key] or nil
end

local function loadModel(hash)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 5000 do Wait(0) end
    return HasModelLoaded(hash)
end

local function world(p) return vector3(Config.Origin.x + p.x, Config.Origin.y + p.y, Config.Origin.z + p.z) end

-- v1.0.15: doors are opened by the script (swing into the room when you walk up, close behind you).
-- GTA's door system often refuses to move doors that a script created, so we turn them ourselves.
local doorState = {}        -- i -> { closed, open, cur, away }

local function rightVec(h) local r = math.rad(h) return math.cos(r), math.sin(r) end

local function spawnDoor(i, d)
    local model = firstModel('door', Config.DoorModels)
    if not model then return end
    local hash = joaat(model)
    if not loadModel(hash) then return end
    local p = world(d)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    local mn, mx = GetModelDimensions(hash)
    local closed = d.h
    if math.abs(mn.x) > math.abs(mx.x) then closed = (closed + 180.0) % 360.0 end   -- model drawn along -X
    SetEntityHeading(obj, closed)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    -- open = turned 90 degrees into the room (away from the street)
    local sr = math.rad(d.h)
    local outX, outY = -math.sin(sr), math.cos(sr)            -- towards the street
    local open = closed + 90.0
    local ex, ey = rightVec(open)
    if ex * outX + ey * outY > 0 then open = closed - 90.0 end
    doorState[i] = { closed = closed, open = open, cur = closed, away = 0 }
    doorObjs[i] = obj
end

-- swing nearby doors
CreateThread(function()
    while true do
        local sleep = 400
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for i, st in pairs(doorState) do
            local obj = doorObjs[i]
            if obj and DoesEntityExist(obj) then
                local op = GetEntityCoords(obj)
                local cx, cy = rightVec(st.closed)
                local mid = vector3(op.x + cx * 0.7, op.y + cy * 0.7, op.z + 1.0)
                local dist = #(pos - mid)
                if dist < 12.0 then sleep = 0 end
                local want
                if Config.DoorsLocked then want = st.closed
                elseif dist < 2.2 then st.away = 0 want = st.open
                else
                    st.away = st.away + (sleep == 0 and GetFrameTime() or 0.4)
                    want = (st.away > 2.0 and dist > 3.0) and st.closed or nil
                end
                if want and math.abs(st.cur - want) > 0.5 then
                    local step = 160.0 * GetFrameTime()
                    if sleep ~= 0 then step = 90.0 end
                    if st.cur < want then st.cur = math.min(want, st.cur + step) else st.cur = math.max(want, st.cur - step) end
                    SetEntityHeading(obj, st.cur % 360.0)
                end
            else
                doorState[i] = nil
            end
        end
        Wait(sleep)
    end
end)

-- calm sea around Osijek (big ocean waves washed over the quays)
CreateThread(function()
    local calm = false
    while true do
        local p = GetEntityCoords(PlayerPedId())
        local near = #(vec2(p.x, p.y) - vec2(Config.Origin.x, Config.Origin.y)) < 1800.0
        if near then SetDeepOceanScaler(0.0) calm = true
        elseif calm then ResetDeepOceanScaler() calm = false end
        Wait(1000)
    end
end)

local function spawnFurniture(i, f)
    local model = firstModel('f_' .. f.kind, Config.FurnitureModels[f.kind])
    if not model then return end
    local hash = joaat(model)
    if not loadModel(hash) then return end
    local p = world(f)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(obj, f.h)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    furnObjs[i] = obj
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local R = Config.InteriorDistance
        for i, d in ipairs(Doors) do
            local dist = #(pos - world(d))
            if dist < R then
                if not doorObjs[i] or not DoesEntityExist(doorObjs[i]) then spawnDoor(i, d) end
            elseif doorObjs[i] and dist > R + 30.0 then
                DeleteObject(doorObjs[i]); doorObjs[i] = nil; doorState[i] = nil
            end
        end
        for i, f in ipairs(Furniture) do
            local dist = #(pos - world(f))
            if dist < R then
                if not furnObjs[i] or not DoesEntityExist(furnObjs[i]) then spawnFurniture(i, f) end
            elseif furnObjs[i] and dist > R + 30.0 then
                DeleteObject(furnObjs[i]); furnObjs[i] = nil
            end
        end
        Wait(1500)
    end
end)

-- warm light in the middle of each nearby house (rooms would be dark otherwise)
CreateThread(function()
    local rooms = {}
    for i, d in ipairs(Doors) do
        local r = math.rad(d.h)
        local fx, fy = -math.sin(r), math.cos(r)            -- towards the street
        local rx, ry = fy, -fx                              -- along the wall, away from the hinge
        rooms[i] = vector3(Config.Origin.x + d.x + rx * 0.7 - fx * 4.5,
                           Config.Origin.y + d.y + ry * 0.7 - fy * 4.5,
                           Config.Origin.z + 2.9)
    end
    while true do
        local sleep = 1000
        if Config.InteriorLight then
            local pos = GetEntityCoords(PlayerPedId())
            for _, c in ipairs(rooms) do
                if #(pos - c) < 40.0 then
                    sleep = 0
                    DrawLightWithRange(c.x, c.y, c.z, 255, 214, 160, 9.0, 1.6)
                end
            end
        end
        Wait(sleep)
    end
end)

-- ---------- real GTA V trees ----------
local treeObjs = {}
local validCache = {}

local function pickTree(kind, i)
    local list = Config.TreeModels[kind] or Config.TreeModels.park
    local valid = validCache[kind]
    if not valid then
        valid = {}
        for _, m in ipairs(list) do
            if IsModelInCdimage(joaat(m)) then valid[#valid + 1] = m end
        end
        validCache[kind] = valid
    end
    if #valid == 0 then return nil end
    return valid[(i % #valid) + 1]   -- same tree every time, mixed along the street
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, t in ipairs(Trees) do
            local p = vector3(Config.Origin.x + t.x, Config.Origin.y + t.y, Config.Origin.z + t.z)
            local d = #(pos - p)
            local obj = treeObjs[i]
            if d < 400.0 then
                if not obj or not DoesEntityExist(obj) then
                    local model = pickTree(t.kind, i)
                    if model then
                        local hash = joaat(model)
                        RequestModel(hash)
                        local tm = GetGameTimer()
                        while not HasModelLoaded(hash) and GetGameTimer() - tm < 5000 do Wait(0) end
                        if HasModelLoaded(hash) then
                            local o = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
                            SetEntityHeading(o, (i * 47) % 360 + 0.0)
                            PlaceObjectOnGroundProperly(o)     -- v1.0.16: sit on the real ground (sidewalk / grass)
                            FreezeEntityPosition(o, true)
                            SetModelAsNoLongerNeeded(hash)
                            treeObjs[i] = o
                        end
                    end
                end
            elseif obj and d > 450.0 then
                DeleteObject(obj)
                treeObjs[i] = nil
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        for _, o in pairs(treeObjs) do if DoesEntityExist(o) then DeleteObject(o) end end
        for _, o in pairs(furnObjs) do if DoesEntityExist(o) then DeleteObject(o) end end
        for i, o in pairs(doorObjs) do
            local doorHash = joaat('osrp_osijek_door_' .. i)
            if IsDoorRegisteredWithSystem(doorHash) then RemoveDoorFromSystem(doorHash) end
            if DoesEntityExist(o) then DeleteObject(o) end
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, obj in pairs(spawned) do
        if DoesEntityExist(obj) then DeleteObject(obj) end
    end
end)

-- /osijek - teleport to the Osijek centre (server checks admin)
RegisterNetEvent('osrp_osijek:tp', function()
    local s = Config.SpawnOffset
    local x, y, z = Config.Origin.x + s.x, Config.Origin.y + s.y, Config.Origin.z + s.z
    local ped = PlayerPedId()
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    RequestCollisionAtCoord(x, y, z)
    SetEntityCoordsNoOffset(ped, x, y, z + 1.0, false, false, false)
    SetEntityHeading(ped, s.w)
    FreezeEntityPosition(ped, true)
    local t = GetGameTimer()
    while GetGameTimer() - t < 4000 do Wait(100) end   -- give the city time to stream in
    FreezeEntityPosition(ped, false)
    DoScreenFadeIn(600)
end)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/osijek', 'Teleport u Osijek (admin)')
end)
