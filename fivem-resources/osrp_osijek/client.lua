-- OSRP Osijek - spawns the Osijek city chunks (static, frozen) near the player

local spawned = {}
local missingWarned = false

local function chunkPos(c)
    return vector3(Config.Origin.x + c.x, Config.Origin.y + c.y, Config.Origin.z + c.z)
end

local function spawnChunk(c)
    local hash = joaat(c.name)
    if not IsModelInCdimage(hash) then
        if not missingWarned then
            missingWarned = true
            print('^3[OSRP Osijek]^7 Modeli nisu u stream/ mapi - pogledaj OSIJEK-MAPA-UPUTE.txt')
        end
        return
    end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - t > 10000 then return end
        Wait(0)
    end
    local p = chunkPos(c)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(obj, 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityLodDist(obj, 1000)
    SetModelAsNoLongerNeeded(hash)
    spawned[c.name] = obj
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for _, c in ipairs(Layout) do
            local d = #(pos - chunkPos(c))
            local obj = spawned[c.name]
            if d < Config.StreamDistance then
                if not obj or not DoesEntityExist(obj) then spawnChunk(c) end
            elseif obj and d > Config.StreamDistance + 100.0 then
                DeleteObject(obj)
                spawned[c.name] = nil
            end
        end
        Wait(1500)
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

local function spawnDoor(i, d)
    local model = firstModel('door', Config.DoorModels)
    if not model then return end
    local hash = joaat(model)
    if not loadModel(hash) then return end
    local p = world(d)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, true)
    SetEntityHeading(obj, d.h)
    SetModelAsNoLongerNeeded(hash)
    local doorHash = joaat('osrp_osijek_door_' .. i)
    if not IsDoorRegisteredWithSystem(doorHash) then
        AddDoorToSystem(doorHash, hash, p.x, p.y, p.z, false, false, false)
    end
    DoorSystemSetDoorState(doorHash, Config.DoorsLocked and 1 or 0, false, true)
    doorObjs[i] = obj
end

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
                local doorHash = joaat('osrp_osijek_door_' .. i)
                if IsDoorRegisteredWithSystem(doorHash) then RemoveDoorFromSystem(doorHash) end
                DeleteObject(doorObjs[i]); doorObjs[i] = nil
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
