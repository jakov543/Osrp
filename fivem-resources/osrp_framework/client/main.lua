-- OSRP framework V1 - client: join, character creator, spawn, HUD, admin helpers

OSRP = { Data = nil, Spawned = false }

-- v1.0.16: custom notifications (NUI). GTA colour codes (~r~ ~g~ ~y~ ...) still work.
local function notify(msg, kind, time)
    msg = tostring(msg or '')
    if not kind then
        if msg:find('~r~') then kind = 'error' elseif msg:find('~g~') then kind = 'success'
        elseif msg:find('~y~') or msg:find('~o~') then kind = 'warning' else kind = 'info' end
    end
    SendNUIMessage({ action = 'notify', text = msg, kind = kind, time = time or 5500 })
end
OSRP.Notify = notify
exports('Notify', notify)

local function loadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - t > 10000 then return nil end
        Wait(0)
    end
    return hash
end

local function osijek() return GetResourceState('osrp_osijek') == 'started' end

-- wait (here, in this resource) until osrp_osijek has the city around x, y loaded
local function waitArea(x, y, radius, timeout)
    if not osijek() then return end
    local t = GetGameTimer()
    while GetGameTimer() - t < (timeout or 20000) do
        local ok, loaded, total = pcall(function() return exports.osrp_osijek:AreaProgress(x, y, radius) end)
        if not ok or not total then return end
        SendNUIMessage({ action = 'loading', show = true, text = 'Učitavanje Osijeka', progress = total > 0 and loaded / total or 1 })
        if loaded >= total then Wait(300) return end
        Wait(100)
    end
end

local function playArrival()
    if not osijek() then return end
    local done = false
    local h = AddEventHandler('osrp_osijek:arrivalDone', function() done = true end)
    TriggerEvent('osrp_osijek:playArrival')
    local t = GetGameTimer()
    while not done and GetGameTimer() - t < 60000 do Wait(100) end
    RemoveEventHandler(h)
end

local function groundZ(x, y, z)
    RequestCollisionAtCoord(x, y, z)
    for _ = 1, 40 do
        local ok, gz = GetGroundZFor_3dCoord(x, y, z + 3.0, false)
        if ok then return gz end
        Wait(50)
    end
    return z
end

-- freemode model + face, skin, hair, outfit from the character
function OSRP.ApplyLook(data)
    local sex = data and data.sex or 'm'
    local model = loadModel(sex == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    if model and GetEntityModel(PlayerPedId()) ~= model then
        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)
    end
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    local a = data and data.appearance or {}
    SetPedHeadBlendData(ped, a.face or 0, a.face or 0, 0, a.skin or 0, a.skin or 0, 0, 0.5, 0.5, 0.0, false)
    SetPedComponentVariation(ped, 2, a.hair or 0, 0, 0)
    SetPedHairColor(ped, a.hairColor or 0, a.hairColor or 0)
    local outfit = (Config.Outfits[sex] or {})[a.outfit or 1]
    for comp, v in pairs(outfit or {}) do SetPedComponentVariation(ped, comp, v[1], v[2] or 0, 0) end
end


-- Spawns the local player. opts.arrival = fly in with the plane first (osrp_osijek)
function OSRP.SpawnAt(x, y, z, h, data, opts)
    opts = opts or {}
    if type(data) ~= 'table' then data = { sex = data } end
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end
    SendNUIMessage({ action = 'loading', show = true, text = 'Učitavanje Osijeka', progress = 0 })
    OSRP.ApplyLook(data)

    local ped = PlayerPedId()
    RequestCollisionAtCoord(x, y, z)
    NetworkResurrectLocalPlayer(x, y, z, h, true, true)
    ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)
    ClearPedTasksImmediately(ped)
    ClearPlayerWantedLevel(PlayerId())
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)

    -- load the city around the spawn first (no falling through the map)
    waitArea(x, y, 420.0, 25000)
    local t = GetGameTimer()
    while GetGameTimer() - t < 15000 do
        local found = GetGroundZFor_3dCoord(x, y, z + 5.0, false)
        if found and HasCollisionLoadedAroundEntity(ped) then break end
        Wait(250)
    end
    SendNUIMessage({ action = 'loading', show = false })
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()

    if opts.arrival and osijek() then
        playArrival()
        SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
        SetEntityHeading(ped, h)
    end

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetPlayerInvincible(PlayerId(), false)
    DoScreenFadeIn(800)
    OSRP.Spawned = true
    TriggerEvent('osrp:playerSpawned')
end

-- ---------- join: character selection (multicharacter) ----------
local menuCam = nil
local PREVIEW = Config.MenuPreview        -- where your character stands in the character menu

local function startJoin()
    OSRP.Spawned = false
    DoScreenFadeOut(0)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SendNUIMessage({ action = 'hideHud' })
    TriggerServerEvent('osrp:ready')
end

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    startJoin()
end)

RegisterNetEvent('osrp:backToMenu', function()
    DoScreenFadeOut(500)
    while not IsScreenFadedOut() do Wait(0) end
    startJoin()
end)

local function menuScene()
    SendNUIMessage({ action = 'loading', show = true, text = 'Učitavanje Osijeka', progress = 0 })
    waitArea(PREVIEW.x, PREVIEW.y, 300.0, 20000)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, PREVIEW.x, PREVIEW.y, PREVIEW.z + 2.0, false, false, false)
    local gz = groundZ(PREVIEW.x, PREVIEW.y, PREVIEW.z)
    OSRP.PreviewZ = gz + 1.0                     -- ped position is ~1 m above the feet
    SendNUIMessage({ action = 'loading', show = false })
    SetEntityCoordsNoOffset(ped, PREVIEW.x, PREVIEW.y, OSRP.PreviewZ, false, false, false)
    SetEntityHeading(ped, PREVIEW.w)
    FreezeEntityPosition(ped, true)
    if not menuCam then
        -- camera in front of the character, a bit to the left so the menu does not cover them
        local r = math.rad(PREVIEW.w)
        local fx, fy = -math.sin(r), math.cos(r)          -- where the character looks
        local rx, ry = fy, -fx                             -- character's right
        local cx, cy = PREVIEW.x + fx * 3.6 + rx * 0.9, PREVIEW.y + fy * 3.6 + ry * 0.9
        menuCam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', cx, cy, gz + 1.55, 0.0, 0.0, 0.0, 42.0, false, 0)
        PointCamAtCoord(menuCam, PREVIEW.x + rx * 0.9, PREVIEW.y + ry * 0.9, gz + 1.0)
    end
    SetCamActive(menuCam, true)
    RenderScriptCams(true, false, 0, true, true)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(800)
end

local function endMenu()
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeMenu' })
    if menuCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(menuCam, false)
        menuCam = nil
    end
end

RegisterNetEvent('osrp:chars', function(list, max)
    if not menuCam then menuScene() end
    SetEntityVisible(PlayerPedId(), false, false)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openMenu', chars = list, max = max, nations = Config.Nationalities })
end)

RegisterNUICallback('preview', function(d, cb)
    cb({})
    if type(d) ~= 'table' or not d.sex then
        SetEntityVisible(PlayerPedId(), false, false)
        return
    end
    OSRP.ApplyLook({ sex = d.sex == 'f' and 'f' or 'm', appearance = d.appearance })
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, PREVIEW.x, PREVIEW.y, OSRP.PreviewZ or (PREVIEW.z + 1.0), false, false, false)
    SetEntityHeading(ped, (PREVIEW.w + (d.rot or 0)) % 360.0)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, true, false)
end)

RegisterNUICallback('selectChar', function(d, cb) cb({}) TriggerServerEvent('osrp:selectChar', tonumber(d.cid)) end)
RegisterNUICallback('deleteChar', function(d, cb) cb({}) TriggerServerEvent('osrp:deleteChar', tonumber(d.cid)) end)
RegisterNUICallback('createChar', function(d, cb)
    cb({})
    TriggerServerEvent('osrp:createChar', {
        firstname = tostring(d.firstname or ''), lastname = tostring(d.lastname or ''), dob = tostring(d.dob or ''),
        sex = d.sex == 'f' and 'f' or 'm', height = tonumber(d.height), nationality = tostring(d.nationality or ''),
        appearance = d.appearance,
    })
end)

RegisterNetEvent('osrp:characterError', function(msg)
    SendNUIMessage({ action = 'creatorError', message = msg })
end)

-- spawn selection after picking a character
RegisterNetEvent('osrp:spawnSelect', function(data)
    OSRP.Data = data
    OSRP.Job = data.job
    local points = {}
    for _, p in ipairs(Config.SpawnPoints) do
        points[#points + 1] = { id = p.id, label = p.label, icon = p.icon, desc = p.desc, disabled = (p.id == 'last' and not data.pos) }
    end
    SendNUIMessage({ action = 'openSpawn', points = points, name = data.firstname .. ' ' .. data.lastname })
end)

RegisterNUICallback('previewSpawn', function(d, cb)
    cb({})
    local c
    for _, p in ipairs(Config.SpawnPoints) do if p.id == d.id then c = p.coords end end
    if d.id == 'last' and OSRP.Data and OSRP.Data.pos then c = vector4(OSRP.Data.pos.x, OSRP.Data.pos.y, OSRP.Data.pos.z, 0.0) end
    if c and menuCam then
        local cam2 = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', c.x - 70.0, c.y - 70.0, c.z + 55.0, 0.0, 0.0, 0.0, 50.0, false, 0)
        PointCamAtCoord(cam2, c.x, c.y, c.z)
        SetCamActiveWithInterp(cam2, menuCam, 1400, 1, 1)
        Wait(1500)
        DestroyCam(menuCam, false)
        menuCam = cam2
        SetEntityVisible(PlayerPedId(), false, false)
    end
end)

local function welcome(data, back)
    if back then notify(('Dobrodošao natrag, ~g~%s %s~s~!'):format(data.firstname, data.lastname), 'success')
    else notify(('Dobrodošao u ~g~Osijek~s~, %s!'):format(data.firstname), 'success') end
end

RegisterNUICallback('chooseSpawn', function(d, cb)
    cb({})
    local data = OSRP.Data
    if not data then return end
    endMenu()
    if d.id == 'last' and data.pos then
        local p, s = data.pos, Config.Spawn
        if #(vector3(p.x, p.y, p.z) - vector3(s.x, s.y, s.z)) <= (Config.CityRadius or 1100.0) then
            OSRP.SpawnAt(p.x, p.y, p.z, p.h or 0.0, data)
            return welcome(data, true)
        end
    end
    for _, p in ipairs(Config.SpawnPoints) do
        if p.id == d.id and p.coords then
            OSRP.SpawnAt(p.coords.x, p.coords.y, p.coords.z, p.coords.w, data, { arrival = p.id == 'arrival' })
            return welcome(data, true)
        end
    end
    local s = Config.Spawn
    OSRP.SpawnAt(s.x, s.y, s.z, s.w, data)
end)

-- new character: straight into the plane
RegisterNetEvent('osrp:spawn', function(data, opts)
    OSRP.Data = data
    OSRP.Job = data.job
    endMenu()
    local a
    for _, p in ipairs(Config.SpawnPoints) do if p.id == 'arrival' then a = p.coords end end
    a = a or Config.Spawn
    OSRP.SpawnAt(a.x, a.y, a.z, a.w, data, { arrival = opts and opts.arrival })
    welcome(data, false)
end)

AddEventHandler('osrp:playerSpawned', function()
    SendNUIMessage({ action = 'showHud' })
end)

-- ---------- HUD + notify ----------
RegisterNetEvent('osrp:hud', function(h)
    SendNUIMessage({ action = 'hud', name = h.name, cash = h.cash, bank = h.bank, job = h.job })
end)

RegisterNetEvent('osrp:notify', function(msg, kind, time) notify(msg, kind, time) end)

-- ---------- save position every 60 s ----------
CreateThread(function()
    while true do
        Wait(60000)
        if OSRP.Spawned and not IsEntityDead(PlayerPedId()) then
            local c = GetEntityCoords(PlayerPedId())
            TriggerServerEvent('osrp:savePos', c.x, c.y, c.z, GetEntityHeading(PlayerPedId()))
        end
    end
end)

-- ---------- world settings: roleplay, no GTA wanted level ----------
CreateThread(function()
    while true do
        if Config.DisableWanted then
            SetMaxWantedLevel(0)
            for i = 1, 15 do EnableDispatchService(i, false) end
        end
        Wait(5000)
    end
end)

-- ---------- admin helpers (server checks permission) ----------
RegisterNetEvent('osrp:spawnCar', function(model)
    local hash = loadModel(model)
    if not hash or not IsModelAVehicle(hash) then return notify('~r~Vozilo ne postoji: ' .. tostring(model)) end
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local veh = CreateVehicle(hash, c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    SetPedIntoVehicle(ped, veh, -1)
    SetVehicleNumberPlateText(veh, 'OSRP')
    SetEntityAsNoLongerNeeded(veh)
    SetModelAsNoLongerNeeded(hash)
end)

RegisterNetEvent('osrp:deleteCar', function()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if veh == 0 then veh = GetVehiclePedIsIn(ped, true) end
    if veh ~= 0 then
        SetEntityAsMissionEntity(veh, true, true)
        DeleteVehicle(veh)
    end
end)

RegisterNetEvent('osrp:tpm', function()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return notify('~r~Postavi waypoint na karti.') end
    local c = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    for z = 1000, 0, -25 do
        SetEntityCoordsNoOffset(ped, c.x, c.y, z + 0.0, false, false, false)
        Wait(20)
        local found, groundZ = GetGroundZFor_3dCoord(c.x, c.y, z + 0.0, false)
        if found then
            SetEntityCoordsNoOffset(ped, c.x, c.y, groundZ + 1.0, false, false, false)
            return
        end
    end
end)
