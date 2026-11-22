-- OSRP Osijek v1.0.33 - BULET e-scooters (rent at a station: E, ride with W/A/S/D, F = end the ride)
-- The scooter is our own Blender model (osrpprop_escooter) on a hidden small RC car that does the physics,
-- you stand on it. Money: osrp_framework server (osrp:buletStart / osrp:buletEnd).

local B = Config.Bulet
local stations = {}        -- [i] = { objs = { [k] = obj }, empty = { [k] = time } }
local ride = nil

local function W(x, y, z) return vector3(Config.Origin.x + x, Config.Origin.y + y, Config.Origin.z + (z or 0.0)) end

local function loadModel(m)
    local h = type(m) == 'number' and m or joaat(m)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) and GetGameTimer() - t < 5000 do Wait(0) end
    return HasModelLoaded(h) and h or nil
end

local function help(t)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(t)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function slotPos(st, k)
    local x, y = st[1] + (k - 1) * 0.75, st[2]
    local w = W(x, y, 1.0)
    local ok, gz = GetGroundZFor_3dCoord(w.x, w.y, w.z + 1.5, false)
    return vector3(w.x, w.y, ok and gz or (Config.Origin.z + 0.27)), ok
end

-- parked scooters at the stations (only near you)
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, st in ipairs(Life.BULET or {}) do
            local c = W(st[1], st[2], 0.0)
            local s = stations[i] or { objs = {}, empty = {} }
            stations[i] = s
            if #(pos - c) < 150.0 then
                for k = 1, B.PerStation do
                    local o = s.objs[k]
                    local waitOk = not s.empty[k] or GetGameTimer() - s.empty[k] > B.RefillSeconds * 1000
                    if (not o or not DoesEntityExist(o)) and waitOk then
                        local p, ok = slotPos(st, k)
                        local h = ok and loadModel('osrpprop_escooter')
                        if h then
                            o = CreateObjectNoOffset(h, p.x, p.y, p.z, false, false, false)
                            SetEntityHeading(o, st[3] - 90.0)
                            FreezeEntityPosition(o, true)
                            s.objs[k], s.empty[k] = o, nil
                        end
                    end
                end
            else
                for k, o in pairs(s.objs) do if DoesEntityExist(o) then DeleteObject(o) end s.objs[k] = nil end
            end
        end
        Wait(2000)
    end
end)

local function nearestScooter()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bi, bk, bd = nil, nil, nil, 1.6
    for i, s in pairs(stations) do
        for k, o in pairs(s.objs) do
            if DoesEntityExist(o) then
                local d = #(pos - GetEntityCoords(o))
                if d < bd then best, bi, bk, bd = o, i, k, d end
            end
        end
    end
    return best, bi, bk
end

-- ------------------------------------------------------------------ riding
local function stopRide(crash)
    if not ride then return end
    local r = ride
    ride = nil
    local ped = PlayerPedId()
    DetachEntity(ped, true, true)
    ClearPedTasks(ped)
    local c = GetEntityCoords(r.veh)
    SetEntityCoords(ped, c.x + 0.6, c.y, c.z + 0.2, false, false, false, false)
    if crash then SetPedToRagdoll(ped, 2500, 2500, 0, false, false, false) end
    if DoesEntityExist(r.prop) then DeleteObject(r.prop) end
    if DoesEntityExist(r.veh) then DeleteVehicle(r.veh) end
    SendNUIMessage({ t = 'bulet', show = false })
    TriggerServerEvent('osrp:buletEnd')
end

local function startRide(pos, heading)
    local vh = loadModel(B.BaseVehicle)
    local ph = loadModel('osrpprop_escooter')
    if not vh or not ph then return TriggerEvent('osrp:notify', '~r~BULET:~s~ romobil trenutno nije dostupan.') end
    local ped = PlayerPedId()
    local veh = CreateVehicle(vh, pos.x, pos.y, pos.z + 0.3, heading, true, false)
    SetEntityVisible(veh, false, false)
    SetEntityAlpha(veh, 0, false)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleDoorsLocked(veh, 2)
    SetVehicleHasBeenOwnedByPlayer(veh, true)
    SetEntityMaxSpeed(veh, B.MaxSpeed / 3.6)
    local prop = CreateObject(ph, pos.x, pos.y, pos.z, true, true, false)
    SetEntityCollision(prop, false, false)
    AttachEntityToEntity(prop, veh, 0, 0.0, 0.0, B.PropZ, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    AttachEntityToEntity(ped, veh, 0, 0.0, -0.1, B.PedZ, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
    RequestAnimDict(B.AnimDict)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(B.AnimDict) and GetGameTimer() - t < 3000 do Wait(0) end
    TaskPlayAnim(ped, B.AnimDict, B.AnimName, 8.0, -8.0, -1, 1, 0, false, false, false)
    SetModelAsNoLongerNeeded(vh) SetModelAsNoLongerNeeded(ph)
    ride = { veh = veh, prop = prop, start = GetGameTimer(), speed = 0.0, battery = 100.0, lastSpeed = 0.0 }
    TriggerEvent('osrp:notify', ('~g~BULET~s~ - vožnja je počela. ~y~W/A/S/D~s~ vožnja, ~y~F~s~ kraj. Cijena: $%d/min.'):format(B.PerMinute))
end

RegisterNetEvent('osrp_osijek:buletOk', function(i, k)
    local s = stations[i]
    local o = s and s.objs[k]
    if not o or not DoesEntityExist(o) then return end
    local pos, heading = GetEntityCoords(o), GetEntityHeading(o)
    DeleteObject(o)
    s.objs[k], s.empty[k] = nil, GetGameTimer()
    startRide(pos, heading)
end)

CreateThread(function()
    while true do
        local sleep = 300
        local ped = PlayerPedId()
        if ride then
            sleep = 0
            local r = ride
            local dt = GetFrameTime()
            DisableControlAction(0, 23, true)       -- F: our own "end ride"
            DisableControlAction(0, 24, true) DisableControlAction(0, 25, true) DisableControlAction(0, 22, true)
            if not DoesEntityExist(r.veh) or IsEntityDead(ped) then
                stopRide(false)
            else
                local fwd = IsControlPressed(0, 32)
                local back = IsControlPressed(0, 33)
                local left, right = IsControlPressed(0, 34), IsControlPressed(0, 35)
                local maxS = (r.battery > 0 and B.MaxSpeed or 6.0) / 3.6
                local real = GetEntitySpeed(r.veh)
                if r.speed - real > 4.0 and r.speed > 5.0 then      -- hit something hard
                    stopRide(true)
                    goto continue
                end
                r.speed = math.min(r.speed, real + 1.0)
                if fwd then r.speed = math.min(maxS, r.speed + B.Accel * dt)
                elseif back then r.speed = math.max(0.0, r.speed - B.Brake * dt)
                else r.speed = math.max(0.0, r.speed - 0.8 * dt) end
                if left or right then
                    local turn = (left and 1 or -1) * B.TurnRate * dt * math.min(1.0, 0.35 + r.speed / 4.0)
                    SetEntityHeading(r.veh, GetEntityHeading(r.veh) + turn)
                end
                if not IsEntityInAir(r.veh) then SetVehicleForwardSpeed(r.veh, r.speed) end
                if not IsEntityPlayingAnim(ped, B.AnimDict, B.AnimName, 3) then
                    TaskPlayAnim(ped, B.AnimDict, B.AnimName, 8.0, -8.0, -1, 1, 0, false, false, false)
                end
                r.battery = math.max(0.0, r.battery - dt * (r.speed > 0.5 and B.BatteryDrain or 0.0))
                local secs = math.floor((GetGameTimer() - r.start) / 1000)
                local mins = math.max(1, math.ceil(secs / 60))
                if GetGameTimer() % 250 < 20 then
                    SendNUIMessage({ t = 'bulet', show = true, time = ('%02d:%02d'):format(secs // 60, secs % 60),
                                     cost = B.Unlock + mins * B.PerMinute, speed = math.floor(real * 3.6 + 0.5), battery = math.floor(r.battery) })
                end
                if IsDisabledControlJustReleased(0, 23) then stopRide(false) end
            end
            ::continue::
        elseif not IsPedInAnyVehicle(ped, false) then
            local o, i, k = nearestScooter()
            if o then
                sleep = 0
                help(('~INPUT_CONTEXT~ Najam ~g~BULET~s~ romobila ($%d + $%d/min)'):format(B.Unlock, B.PerMinute))
                if IsControlJustReleased(0, 38) then TriggerServerEvent('osrp:buletStart', i, k) end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if ride then stopRide(false) end
    for _, s in pairs(stations) do for _, o in pairs(s.objs) do if DoesEntityExist(o) then DeleteObject(o) end end end
end)
