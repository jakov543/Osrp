-- OSRP framework V1 - EMS job (Hitna) + KBC Osijek reception
--  * reception at KBC Osijek: E = treatment (Config.HealPrice)
--  * EMS players: get 112 calls (blip + GPS), revive downed players with E (CPR), take an ambulance at the EMS garage

local calls = {}            -- serverId -> blip

local function help(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function marker(p)
    DrawMarker(1, p.x, p.y, p.z - 1.0, 0, 0, 0, 0, 0, 0, 1.2, 1.2, 0.4, 200, 30, 30, 140, false, false, 2, false, nil, nil, false)
end

local function isEms() return OSRP.Job == 'ems' end

RegisterNetEvent('osrp:job', function(job) OSRP.Job = job end)

-- hospital blip
CreateThread(function()
    local d = Config.HospitalDoor
    local b = AddBlipForCoord(d.x, d.y, d.z)
    SetBlipSprite(b, 61)
    SetBlipColour(b, 1)
    SetBlipScale(b, 0.9)
    SetBlipAsShortRange(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('KBC Osijek - Bolnica')
    EndTextCommandSetBlipName(b)
end)

-- reception + EMS garage
CreateThread(function()
    while true do
        local sleep = 800
        if OSRP.Spawned then
            local ped = PlayerPedId()
            local pos = GetEntityCoords(ped)
            local door = Config.HospitalDoor
            if #(pos - door) < 25.0 and not IsEntityDead(ped) then
                sleep = 0
                marker(door)
                if #(pos - door) < 1.6 then
                    help(('~INPUT_CONTEXT~ Liječenje (~g~$%d~s~)'):format(Config.HealPrice))
                    if IsControlJustReleased(0, 38) then TriggerServerEvent('osrp:hospitalHeal') Wait(1000) end
                end
            end
            local g = Config.EmsGarage
            if isEms() and #(pos - vector3(g.x, g.y, g.z)) < 25.0 and not IsPedInAnyVehicle(ped, false) then
                sleep = 0
                marker(vector3(g.x, g.y, g.z))
                if #(pos - vector3(g.x, g.y, g.z)) < 2.0 then
                    help('~INPUT_CONTEXT~ Uzmi vozilo hitne pomoći')
                    if IsControlJustReleased(0, 38) then
                        local h = joaat(Config.AmbulanceModel)
                        RequestModel(h)
                        local t = GetGameTimer()
                        while not HasModelLoaded(h) and GetGameTimer() - t < 5000 do Wait(0) end
                        if HasModelLoaded(h) then
                            local v = CreateVehicle(h, g.x, g.y, g.z + 0.5, g.w, true, false)
                            SetVehicleNumberPlateText(v, 'HITNA')
                            SetVehicleOnGroundProperly(v)
                            SetPedIntoVehicle(ped, v, -1)
                            SetEntityAsNoLongerNeeded(v)
                            SetModelAsNoLongerNeeded(h)
                        end
                        Wait(2000)
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- incoming 112 calls (EMS only)
RegisterNetEvent('osrp:emsCall', function(caller, x, y, z, name, injuredOnly)
    if calls[caller] then RemoveBlip(calls[caller]) end
    local b = AddBlipForCoord(x, y, z)
    SetBlipSprite(b, 153)
    SetBlipColour(b, 1)
    SetBlipFlashes(b, true)
    SetBlipRoute(b, true)
    SetBlipRouteColour(b, 1)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('112: ' .. (name or 'poziv'))
    EndTextCommandSetBlipName(b)
    calls[caller] = b
    PlaySoundFrontend(-1, 'TIMER_STOP', 'HUD_MINI_GAME_SOUNDSET', true)
    OSRP.Notify(('~r~112 POZIV~s~ - %s %s. GPS je postavljen.'):format(name or 'netko', injuredOnly and 'je ozlijeđen' or 'je bez svijesti'))
    SetTimeout(240000, function()
        if calls[caller] == b then RemoveBlip(b) calls[caller] = nil end
    end)
end)

RegisterNetEvent('osrp:emsCallClosed', function(caller)
    if calls[caller] then RemoveBlip(calls[caller]) calls[caller] = nil end
end)

-- EMS: revive a downed player with CPR
CreateThread(function()
    while true do
        local sleep = 600
        if OSRP.Spawned and isEms() then
            local me = PlayerPedId()
            local pos = GetEntityCoords(me)
            for _, pl in ipairs(GetActivePlayers()) do
                if pl ~= PlayerId() then
                    local ped = GetPlayerPed(pl)
                    if IsEntityDead(ped) and #(GetEntityCoords(ped) - pos) < 2.5 and not IsPedInAnyVehicle(me, false) then
                        sleep = 0
                        help('~INPUT_CONTEXT~ Oživi (CPR)')
                        if IsControlJustReleased(0, 38) then
                            RequestAnimDict('mini@cpr@char_a@cpr_str')
                            local t = GetGameTimer()
                            while not HasAnimDictLoaded('mini@cpr@char_a@cpr_str') and GetGameTimer() - t < 3000 do Wait(0) end
                            TaskTurnPedToFaceEntity(me, ped, 600)
                            Wait(600)
                            TaskPlayAnim(me, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 8.0, -8.0, 8000, 1, 0, false, false, false)
                            Wait(8000)
                            ClearPedTasks(me)
                            TriggerServerEvent('osrp:emsRevive', GetPlayerServerId(pl))
                        end
                        break
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
