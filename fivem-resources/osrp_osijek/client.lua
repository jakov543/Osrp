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
