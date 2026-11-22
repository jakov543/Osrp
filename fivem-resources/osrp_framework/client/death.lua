-- OSRP framework V1 - death, ambulance call (G / 112) and respawn at KBC Osijek
-- When you are down: G calls the ambulance. EMS players get the call; if nobody is on duty (or nobody comes in time)
-- an AI ambulance from KBC Osijek drives to you, the paramedics do CPR and you are back on your feet (bill: Config.AmbulanceBill).
-- After Config.RespawnSeconds you can also press E to wake up in the hospital.

local deadSince = nil
local called = nil          -- 'ems' | 'ai' | nil
local calledAt = 0
local healCall = false      -- /hitna while alive (injured): the ambulance treats you

local function draw2D(text, y)
    SetTextFont(4)
    SetTextScale(0.0, 0.5)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, y or 0.82)
end

local function aiAvailable()
    return GetResourceState('osrp_osijek') == 'started'
end

local function sendAi(tag)
    if not aiAvailable() then
        OSRP.Notify('~r~Hitna nije dostupna~s~ (osrp_osijek nije pokrenut).')
        return false
    end
    local c = GetEntityCoords(PlayerPedId())
    local ok = pcall(function() exports.osrp_osijek:SendAmbulance(c.x, c.y, c.z, tag) end)
    if ok then OSRP.Notify('~r~Hitna pomoć~s~ je krenula iz ~b~KBC Osijek~s~. Prati sirenu na karti.') end
    return ok
end

local function callAmbulance(heal)
    healCall = heal or false
    called = 'pending'
    calledAt = GetGameTimer()
    local c = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('osrp:callEms', c.x, c.y, c.z, healCall)
end

RegisterNetEvent('osrp:emsCallResult', function(kind, count)
    if kind == 'ems' then
        called = 'ems'
        calledAt = GetGameTimer()
        OSRP.Notify(('~r~112:~s~ poziv poslan. Na dužnosti: ~g~%d~s~ djelatnik(a) hitne.'):format(count or 1))
    elseif kind == 'wait' then
        called = nil
        OSRP.Notify('~r~112:~s~ pričekaj malo prije novog poziva.')
    else
        called = 'ai'
        sendAi(healCall and 'player_heal' or 'player')
    end
end)

AddEventHandler('osrp:aiAmbulanceArrived', function(tag)
    if tag ~= 'player' and tag ~= 'player_heal' then return end
    local ped = PlayerPedId()
    called = nil
    if IsEntityDead(ped) then
        local c = GetEntityCoords(ped)
        deadSince = nil
        NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
        ped = PlayerPedId()
        SetEntityHealth(ped, math.floor(GetEntityMaxHealth(ped) * 0.75))
        ClearPedBloodDamage(ped)
        OSRP.Notify('~g~Hitna te vratila na noge.~s~')
    else
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        ClearPedBloodDamage(ped)
        OSRP.Notify('~g~Hitna te zbrinula.~s~')
    end
    TriggerServerEvent('osrp:emsBill')
end)

-- /hitna (112): also when you are alive but hurt (e.g. a car hit you)
RegisterCommand('hitna', function()
    if called then return OSRP.Notify('Hitna je već pozvana.') end
    local ped = PlayerPedId()
    if not IsEntityDead(ped) and GetEntityHealth(ped) >= GetEntityMaxHealth(ped) - 5 then
        return OSRP.Notify('Nisi ozlijeđen. Za liječenje idi u ~b~KBC Osijek~s~.')
    end
    callAmbulance(not IsEntityDead(ped))
end, false)
RegisterCommand('112', function() ExecuteCommand('hitna') end, false)

CreateThread(function()
    while true do
        local sleep = 500
        if OSRP.Spawned then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                sleep = 0
                deadSince = deadSince or GetGameTimer()
                local left = Config.RespawnSeconds - math.floor((GetGameTimer() - deadSince) / 1000)
                if not called then
                    draw2D('Onesviješten si. ~r~G~s~ - pozovi hitnu (112)', 0.78)
                    if IsControlJustReleased(0, 47) then callAmbulance(false) end
                elseif called == 'ems' then
                    local wait = Config.EmsWaitSeconds - math.floor((GetGameTimer() - calledAt) / 1000)
                    draw2D(('Hitna je pozvana. Ako nitko ne stigne za ~y~%d~s~ s, dolazi vozilo hitne.'):format(math.max(0, wait)), 0.78)
                    if wait <= 0 then
                        called = 'ai'
                        sendAi('player')
                    end
                else
                    draw2D('~r~Hitna je na putu...~s~', 0.78)
                end
                if left > 0 then
                    draw2D(('Buđenje u bolnici moguće za ~r~%d~s~ s'):format(left), 0.83)
                else
                    draw2D('~g~E~s~ - probudi se u bolnici (KBC Osijek)', 0.83)
                    if IsControlJustReleased(0, 38) then
                        local h = Config.Hospital
                        deadSince = nil
                        called = nil
                        OSRP.SpawnAt(h.x, h.y, h.z, h.w, OSRP.Data)
                        OSRP.Notify('Probudio si se u ~b~KBC Osijek~s~.')
                    end
                end
            else
                deadSince = nil
                if called == 'ems' then called = nil end
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('osrp:revive', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    deadSince = nil
    called = nil
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId()))
    ClearPedBloodDamage(PlayerPedId())
    OSRP.Notify('~g~Oživljen si.')
end)

RegisterNetEvent('osrp:healed', function()
    local ped = PlayerPedId()
    SetEntityHealth(ped, GetEntityMaxHealth(ped))
    ClearPedBloodDamage(ped)
    OSRP.Notify('~g~Liječnik te pregledao. Potpuno si zdrav.')
end)
