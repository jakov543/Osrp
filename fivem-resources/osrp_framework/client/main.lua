-- OSRP framework V1 - client: join, character creator, spawn, HUD, admin helpers

OSRP = { Data = nil, Spawned = false }

local function notify(msg)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end
OSRP.Notify = notify

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

-- Spawns the local player at a position with the right freemode model
function OSRP.SpawnAt(x, y, z, h, sex)
    DoScreenFadeOut(300)
    while not IsScreenFadedOut() do Wait(0) end

    local model = loadModel(sex == 'f' and 'mp_f_freemode_01' or 'mp_m_freemode_01')
    if model and GetEntityModel(PlayerPedId()) ~= model then
        SetPlayerModel(PlayerId(), model)
        SetPedDefaultComponentVariation(PlayerPedId())
        SetModelAsNoLongerNeeded(model)
    end

    RequestCollisionAtCoord(x, y, z)
    NetworkResurrectLocalPlayer(x, y, z, h, true, true)
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, x, y, z, false, false, false)
    SetEntityHeading(ped, h)
    ClearPedTasksImmediately(ped)
    ClearPlayerWantedLevel(PlayerId())
    SetEntityHealth(ped, GetEntityMaxHealth(ped))

    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() - t < 5000 do Wait(0) end

    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetPlayerInvincible(PlayerId(), false)
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    DoScreenFadeIn(600)
    OSRP.Spawned = true
    TriggerEvent('osrp:playerSpawned')
end

-- ---------- join ----------
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    DoScreenFadeOut(0)
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    TriggerServerEvent('osrp:ready')
end)

RegisterNetEvent('osrp:spawn', function(data)
    OSRP.Data = data
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closeCreator' })
    local p = data.pos
    if p and p.x then
        OSRP.SpawnAt(p.x, p.y, p.z, p.h or 0.0, data.sex)
        notify(('Dobrodošao natrag, ~g~%s %s~s~!'):format(data.firstname, data.lastname))
    else
        local s = Config.Spawn
        OSRP.SpawnAt(s.x, s.y, s.z, s.w, data.sex)
        notify(('Dobrodošao na ~g~OSRP~s~, %s!'):format(data.firstname))
    end
end)

-- ---------- character creator ----------
RegisterNetEvent('osrp:createCharacter', function()
    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    -- nice camera over the city while creating
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', -1300.0, -1700.0, 120.0, -15.0, 0.0, -30.0, 60.0, false, 0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    OSRP.CreatorCam = cam
    DoScreenFadeIn(800)
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCreator' })
end)

RegisterNetEvent('osrp:characterError', function(msg)
    SendNUIMessage({ action = 'creatorError', message = msg })
end)

RegisterNUICallback('submitCharacter', function(data, cb)
    cb({ ok = true })
    TriggerServerEvent('osrp:submitCharacter', {
        firstname = tostring(data.firstname or ''),
        lastname = tostring(data.lastname or ''),
        dob = tostring(data.dob or ''),
        sex = data.sex == 'f' and 'f' or 'm'
    })
end)

AddEventHandler('osrp:playerSpawned', function()
    if OSRP.CreatorCam then
        RenderScriptCams(false, false, 0, true, true)
        DestroyCam(OSRP.CreatorCam, false)
        OSRP.CreatorCam = nil
    end
    SendNUIMessage({ action = 'showHud' })
end)

-- ---------- HUD + notify ----------
RegisterNetEvent('osrp:hud', function(h)
    SendNUIMessage({ action = 'hud', name = h.name, cash = h.cash, bank = h.bank, job = h.job })
end)

RegisterNetEvent('osrp:notify', function(msg) notify(msg) end)

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
