-- OSRP Osijek - random events around the player (local, like GTA's own random events)
--   hit_and_run  a car hits you on the road and drives off
--   accident     traffic accident with an injured person -> AI ambulance + police come
--   breakdown    broken-down car with smoke, help the driver (E) for a reward
--   thief        a thief snatches your wallet - catch him to get it back + reward
--   fire         a dumpster is on fire -> fire truck comes
--   chase        police chase a car through the city with sirens
-- Settings: Config.Events in config.lua. Admins can test one with /dogadaj [name].

local active = 0
local lastRun = {}

local function notify(msg)
    if GetResourceState('osrp_framework') == 'started' then
        return TriggerEvent('osrp:notify', msg)        -- OSRP custom notification
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandThefeedPostTicker(false, true)
end

local function help(msg)
    BeginTextCommandDisplayHelp('STRING')
    AddTextComponentSubstringPlayerName(msg)
    EndTextCommandDisplayHelp(0, false, false, -1)
end

local function load(model)
    local h = joaat(model)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) and GetGameTimer() - t < 6000 do Wait(0) end
    return HasModelLoaded(h) and h or nil
end

local function loadDict(d)
    RequestAnimDict(d)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(d) and GetGameTimer() - t < 4000 do Wait(0) end
end

-- v1.0.24: wait a moment for the map collision there; the city is flat, so fall back to street level
local function ground(p)
    local t = GetGameTimer()
    repeat
        RequestCollisionAtCoord(p.x, p.y, p.z)
        local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 8.0, false)
        if ok and math.abs(gz - p.z) <= 4.0 then return vector3(p.x, p.y, gz) end
        Wait(100)
    until GetGameTimer() - t > 1500
    if OsijekInCityFlat and OsijekInCityFlat(p) then return vector3(p.x, p.y, Config.Origin.z + 0.12) end
    return nil
end

local function pick(list) return list[math.random(#list)] end

local function where(p)
    local street = OsijekLocation and OsijekLocation(p.x, p.y)
    return street or 'Osijek'
end

local function inCity(p)
    return #(vec2(p.x, p.y) - vec2(Config.Origin.x, Config.Origin.y)) < Config.CityRadius
end
-- a point on a street of the city (road level is Config.Origin.z)
function OsijekInCityFlat(p)
    return inCity(p) and math.abs(p.z - Config.Origin.z) < 3.0
end

-- a street point some distance from the player (on a real street), with ground loaded
local function streetPointNear(minD, maxD)
    local me = GetEntityCoords(PlayerPedId())
    for _ = 1, 12 do
        local a = math.random() * math.pi * 2
        local d = minD + math.random() * (maxD - minD)
        local p, horiz = OsijekNearestStreet(me.x + math.cos(a) * d, me.y + math.sin(a) * d)
        local dist = #(vec2(p.x, p.y) - vec2(me.x, me.y))
        if dist >= minD * 0.7 and dist <= maxD * 1.3 then
            local g = ground(p)
            if g then return g, horiz end
        end
    end
    return nil
end

local function blipAt(p, sprite, colour, label, route)
    local b = AddBlipForCoord(p.x, p.y, p.z)
    SetBlipSprite(b, sprite)
    SetBlipColour(b, colour)
    SetBlipScale(b, 0.9)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(label)
    EndTextCommandSetBlipName(b)
    if route then SetBlipRoute(b, true) end
    return b
end

local function delete(list)
    for _, e in pairs(list) do
        if type(e) == 'number' and e ~= 0 and DoesEntityExist(e) then
            SetEntityAsMissionEntity(e, true, true)
            if IsEntityAVehicle(e) then DeleteVehicle(e)
            elseif IsEntityAPed(e) then DeletePed(e)
            else DeleteObject(e) end
        end
    end
end

local function car(model, p, heading)
    local h = load(model or pick(Config.TrafficModels))
    if not h then return nil end
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local v = CreateVehicle(h, p.x, p.y, p.z + 0.4, heading or 0.0, false, false)
    SetEntityAsMissionEntity(v, true, true)
    local t = GetGameTimer()        -- v1.0.24: do not let the car drop through a map part that is still loading
    FreezeEntityPosition(v, true)
    while not HasCollisionLoadedAroundEntity(v) and GetGameTimer() - t < 3000 do Wait(50) end
    FreezeEntityPosition(v, false)
    SetVehicleOnGroundProperly(v)
    SetModelAsNoLongerNeeded(h)
    return v
end

local function npc(model, p, heading)
    local h = load(model or pick(Config.PedModels))
    if not h then return nil end
    local ped = CreatePed(4, h, p.x, p.y, p.z, heading or 0.0, false, true)
    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetModelAsNoLongerNeeded(h)
    return ped
end

-- ===================================================================== events
local EVENTS = {}

EVENTS.hit_and_run = function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return false end
    local me = GetEntityCoords(ped)
    local road, horiz = OsijekNearestStreet(me.x, me.y)
    if #(vec2(road.x, road.y) - vec2(me.x, me.y)) > 9.0 then return false end     -- only when you are on/at the road
    local dir = math.random() < 0.5 and -1 or 1
    local from = horiz and vector3(me.x - dir * 75.0, road.y, road.z) or vector3(road.x, me.y - dir * 75.0, road.z)
    from = ground(from)
    if not from then return false end
    local heading = horiz and (dir == 1 and 270.0 or 90.0) or (dir == 1 and 0.0 or 180.0)
    local v = car(nil, from, heading)
    local d = v and npc(nil, from)
    if not v or not d then delete({ v, d }) return false end
    SetPedIntoVehicle(d, v, -1)
    SetVehicleEngineOn(v, true, true, false)
    TaskVehicleDriveToCoord(d, v, me.x, me.y, me.z, 24.0, 0, GetEntityModel(v), 787004, 1.0, true)
    local t, hit, honked = GetGameTimer(), false, false
    while GetGameTimer() - t < 14000 and DoesEntityExist(v) do
        Wait(0)
        ped = PlayerPedId()
        SetEntityNoCollisionEntity(v, ped, true)                     -- the hit is scripted: hurts, does not kill
        local dist = #(GetEntityCoords(v) - GetEntityCoords(ped))
        if not honked and dist < 25.0 then StartVehicleHorn(v, 1200, joaat('HELDDOWN'), false) honked = true end
        if dist < 3.5 and not hit then
            hit = true
            SetPedToRagdoll(ped, 3500, 3500, 0, false, false, false)
            ApplyDamageToPed(ped, Config.Events.HitDamage or 35, false)
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE', 0.25)
            notify('~r~Udario te auto!~s~ Vozač je pobjegao.~n~Ako si ozlijeđen: ~y~/hitna')
            local away = horiz and vector3(me.x + dir * 250.0, road.y, road.z) or vector3(road.x, me.y + dir * 250.0, road.z)
            TaskVehicleDriveToCoord(d, v, away.x, away.y, away.z, 26.0, 0, GetEntityModel(v), 787004, 5.0, true)
            break
        end
    end
    SetTimeout(15000, function() delete({ d, v }) end)
    return true
end

EVENTS.accident = function()
    local p, horiz = streetPointNear(70.0, 200.0)
    if not p then return false end
    local h1 = horiz and 90.0 or 0.0
    local c1 = car(nil, p, h1 + 25.0)
    local c2 = car(nil, p + (horiz and vector3(4.2, 1.0, 0.0) or vector3(1.0, 4.2, 0.0)), h1 + 120.0)
    if not c1 or not c2 then delete({ c1, c2 }) return false end
    for _, c in ipairs({ c1, c2 }) do
        SetVehicleDamage(c, 0.0, 1.2, 0.1, 900.0, 250.0, true)
        SmashVehicleWindow(c, 0)
        SmashVehicleWindow(c, 1)
        SetVehicleEngineHealth(c, 120.0)
        SetVehicleIndicatorLights(c, 0, true)
        SetVehicleIndicatorLights(c, 1, true)
        SetVehicleDoorOpen(c, 0, false, false)
    end
    local hurtPos = ground(p + (horiz and vector3(1.8, -3.0, 0.0) or vector3(-3.0, 1.8, 0.0))) or p
    local hurt = npc(nil, hurtPos)
    local wit = npc(nil, hurtPos + vector3(2.5, 1.5, 0.0))
    if hurt then
        SetEntityInvincible(hurt, true)
        loadDict('combat@damage@writhe')
        TaskPlayAnim(hurt, 'combat@damage@writhe', 'writhe_loop', 8.0, -8.0, -1, 1, 0, false, false, false)
    end
    if wit then TaskStartScenarioInPlace(wit, 'WORLD_HUMAN_STAND_MOBILE', 0, true) end
    local b = blipAt(p, 380, 1, 'Prometna nesreća', false)
    notify(('~o~Dojava:~s~ prometna nesreća - ~y~%s~s~. Ozlijeđena osoba, hitna je na putu.'):format(where(p)))
    local tag = 'acc' .. GetGameTimer()
    local finished = false
    local handler = AddEventHandler('osrp:aiAmbulanceArrived', function(t) if t == tag then finished = true end end)
    SetTimeout(20000, function()
        if hurt and DoesEntityExist(hurt) then SendAmbulance(hurtPos.x, hurtPos.y, hurtPos.z, tag, hurt) end
        SendEmergencyVehicle('police', 's_m_y_cop_01', p.x + 10.0, p.y + 10.0, p.z, 120000)
    end)
    local t = GetGameTimer()
    while not finished and GetGameTimer() - t < 240000 do Wait(1000) end
    Wait(45000)
    RemoveEventHandler(handler)
    RemoveBlip(b)
    delete({ c1, c2, hurt, wit })
    return true
end

EVENTS.breakdown = function()
    local p, horiz = streetPointNear(50.0, 160.0)
    if not p then return false end
    local side = math.random() < 0.5 and -1 or 1
    local pos = ground(p + (horiz and vector3(0.0, side * 3.2, 0.0) or vector3(side * 3.2, 0.0, 0.0))) or p
    local v = car(nil, pos, horiz and 90.0 or 0.0)
    if not v then return false end
    SetVehicleEngineHealth(v, 90.0)
    SetVehicleDoorOpen(v, 4, false, false)
    SetVehicleIndicatorLights(v, 0, true)
    SetVehicleIndicatorLights(v, 1, true)
    local hood = GetOffsetFromEntityInWorldCoords(v, 0.0, 3.0, 0.0)
    local d = npc(nil, GetOffsetFromEntityInWorldCoords(v, 1.8, 2.0, 0.0))
    if d then TaskStartScenarioInPlace(d, 'WORLD_HUMAN_STAND_IMPATIENT', 0, true) end
    local b = blipAt(pos, 446, 5, 'Pokvaren auto', false)
    notify(('~y~Pokvaren auto~s~ kod ~y~%s~s~. Vozač treba pomoć.'):format(where(pos)))
    local t, helped = GetGameTimer(), false
    while GetGameTimer() - t < 240000 and DoesEntityExist(v) do
        local ped = PlayerPedId()
        local wait = 500
        if not IsPedInAnyVehicle(ped, false) and #(GetEntityCoords(ped) - hood) < 2.5 then
            wait = 0
            help('~INPUT_CONTEXT~ Pomozi vozaču popraviti auto')
            if IsControlJustReleased(0, 38) then
                TaskTurnPedToFaceEntity(ped, v, 800)
                Wait(800)
                TaskStartScenarioInPlace(ped, 'PROP_HUMAN_BUM_BIN', 0, true)
                Wait(6500)
                ClearPedTasks(ped)
                SetVehicleEngineHealth(v, 1000.0)
                SetVehicleDoorShut(v, 4, false)
                SetVehicleIndicatorLights(v, 0, false)
                SetVehicleIndicatorLights(v, 1, false)
                notify('~g~Vozač:~s~ Hvala ti puno, evo ti nešto za trud!')
                TriggerServerEvent('osrp:eventReward', 'breakdown')
                helped = true
                break
            end
        end
        Wait(wait)
    end
    RemoveBlip(b)
    if helped and d and DoesEntityExist(d) then
        ClearPedTasks(d)
        TaskEnterVehicle(d, v, 8000, -1, 1.0, 1, 0)
        Wait(6000)
        local away = OsijekNearestStreet(pos.x + 300.0, pos.y)
        TaskVehicleDriveToCoord(d, v, away.x, away.y, away.z, 12.0, 0, GetEntityModel(v), Config.DrivingStyle, 8.0, true)
        Wait(30000)
    end
    delete({ d, v })
    return true
end

EVENTS.thief = function()
    local ped = PlayerPedId()
    if IsPedInAnyVehicle(ped, false) then return false end
    local from = ground(GetOffsetFromEntityInWorldCoords(ped, 0.0, -14.0, 0.0))
    if not from then return false end
    local th = npc(pick({ 'a_m_y_stbla_01', 'a_m_y_skater_01', 'g_m_y_famca_01', 'a_m_y_hippy_01' }), from)
    if not th then return false end
    SetPedFleeAttributes(th, 0, false)
    TaskGoToEntity(th, ped, -1, 1.0, 3.0, 0, 0)
    local t = GetGameTimer()
    while GetGameTimer() - t < 15000 and #(GetEntityCoords(th) - GetEntityCoords(PlayerPedId())) > 1.6 do Wait(100) end
    if #(GetEntityCoords(th) - GetEntityCoords(PlayerPedId())) > 1.6 then delete({ th }) return false end
    TriggerServerEvent('osrp:eventThief')
    notify('~r~Lopov ti je ukrao novčanik!~s~ Uhvati ga!')
    PlaySoundFrontend(-1, 'Bed', 'WastedSounds', true)
    TaskSmartFleePed(th, PlayerPedId(), 400.0, -1, false, false)
    local b = AddBlipForEntity(th)
    SetBlipColour(b, 1)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Lopov')
    EndTextCommandSetBlipName(b)
    t = GetGameTimer()
    local caught = false
    while GetGameTimer() - t < 75000 and DoesEntityExist(th) do
        Wait(0)
        SetPedMoveRateOverride(th, 0.88)                             -- a bit slower than you when you sprint
        local d = #(GetEntityCoords(th) - GetEntityCoords(PlayerPedId()))
        if d < 2.0 or IsPedRagdoll(th) or IsPedBeingStunned(th, 0) then caught = true break end
        if d > 180.0 then break end
    end
    RemoveBlip(b)
    if caught then
        ClearPedTasksImmediately(th)
        TaskHandsUp(th, 6000, PlayerPedId(), -1, false)
        notify('~g~Uhvatio si lopova!~s~ Novčanik je vraćen + nagrada.')
        TriggerServerEvent('osrp:eventThiefCaught')
        Wait(6000)
        TaskSmartFleePed(th, PlayerPedId(), 300.0, -1, false, false)
        Wait(8000)
    else
        notify('~r~Lopov je pobjegao~s~ s tvojim novcem.')
    end
    delete({ th })
    return true
end

EVENTS.fire = function()
    local p, horiz = streetPointNear(50.0, 160.0)
    if not p then return false end
    local side = math.random() < 0.5 and -1 or 1
    local spot = ground(p + (horiz and vector3(0.0, side * 7.5, 0.0) or vector3(side * 7.5, 0.0, 0.0))) or p
    local h = load('prop_dumpster_01a')
    local bin = h and CreateObject(h, spot.x, spot.y, spot.z, false, false, false)
    if bin then PlaceObjectOnGroundProperly(bin) FreezeEntityPosition(bin, true) end
    local fires = {}
    for k = 1, 3 do
        fires[k] = StartScriptFire(spot.x + (k - 2) * 0.6, spot.y, spot.z + 0.6, 10, false)
    end
    local b = blipAt(spot, 436, 1, 'Požar', false)
    notify(('~r~Požar~s~ kod ~y~%s~s~! Vatrogasci su na putu.'):format(where(spot)))
    Wait(20000)
    SendEmergencyVehicle('firetruk', 's_m_y_fireman_01', spot.x, spot.y, spot.z, 90000)
    Wait(45000)
    for _, f in ipairs(fires) do RemoveScriptFire(f) end
    StopFireInRange(spot.x, spot.y, spot.z, 12.0)
    notify('~g~Vatrogasci su ugasili požar.')
    RemoveBlip(b)
    Wait(40000)
    delete({ bin })
    return true
end

EVENTS.chase = function()
    local routes = Life and Life.ROUTES
    if not routes or #routes == 0 then return false end
    local r = pick(routes)
    local o = Config.Origin
    local wps = {}
    for lap = 1, 2 do
        for _, w in ipairs(r) do wps[#wps + 1] = vector3(o.x + w[1], o.y + w[2], o.z + 0.5) end
    end
    local start = ground(wps[1])
    if not start then return false end
    local sv = car(pick({ 'sultan', 'buffalo', 'futo', 'blista' }), start)
    local dir = wps[2] - wps[1]
    dir = dir / math.max(0.1, #dir)
    local hd = GetHeadingFromVector_2d(dir.x, dir.y)
    local pstart = ground(start - dir * 25.0) or start
    local pv = car('police', pstart, hd)
    if sv then SetEntityHeading(sv, hd) end
    if not sv or not pv then delete({ sv, pv }) return false end
    local sd, pd = npc(nil, start), npc('s_m_y_cop_01', start)
    if not sd or not pd then delete({ sv, pv, sd, pd }) return false end
    SetPedIntoVehicle(sd, sv, -1)
    SetPedIntoVehicle(pd, pv, -1)
    SetVehicleSiren(pv, true)
    SetDriverAbility(sd, 1.0)
    SetDriverAggressiveness(sd, 1.0)
    local b = AddBlipForEntity(sv)
    SetBlipColour(b, 1)
    SetBlipFlashes(b, true)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('Potjera')
    EndTextCommandSetBlipName(b)
    notify('~b~Policija~s~ juri vozilo kroz Osijek! Makni se s ceste.')
    CreateThread(function() OsijekDriveRoute(sv, sd, wps, 30.0, 10.0) end)
    Wait(2500)
    CreateThread(function() OsijekDriveRoute(pv, pd, wps, 32.0, 10.0) end)
    Wait(90000)
    RemoveBlip(b)
    delete({ sd, pd, sv, pv })
    return true
end

-- ===================================================================== scheduler
local function run(name)
    local fn = EVENTS[name]
    if not fn then return end
    active = active + 1
    lastRun[name] = GetGameTimer()
    local ok, res = pcall(fn)
    if not ok then print(('[osrp_osijek] event %s failed: %s'):format(name, tostring(res))) end
    active = active - 1
    return ok and res
end

CreateThread(function()
    Wait(90000)
    while true do
        local cfg = Config.Events or {}
        Wait((cfg.Interval or 120) * 1000)
        local ped = PlayerPedId()
        if cfg.Enabled and active < (cfg.MaxActive or 2) and inCity(GetEntityCoords(ped)) and not IsEntityDead(ped)
            and math.random() < (cfg.Chance or 0.4) then
            local pool, total = {}, 0
            for name, w in pairs(cfg.Weights or {}) do
                local cd = (cfg.Cooldown or 600) * 1000
                if EVENTS[name] and w > 0 and (not lastRun[name] or GetGameTimer() - lastRun[name] > cd) then
                    pool[#pool + 1] = { name, w }
                    total = total + w
                end
            end
            if total > 0 then
                local r = math.random() * total
                for _, e in ipairs(pool) do
                    r = r - e[2]
                    if r <= 0 then CreateThread(function() run(e[1]) end) break end
                end
            end
        end
    end
end)

RegisterNetEvent('osrp_osijek:testEvent', function(name)
    if not EVENTS[name] then
        local names = {}
        for k in pairs(EVENTS) do names[#names + 1] = k end
        return notify('Događaji: ~y~' .. table.concat(names, ', '))
    end
    CreateThread(function()
        -- v1.0.24: tell the admin when an event could not start here (and why)
        if not run(name) then
            local why = ({ hit_and_run = 'stani na cestu (pješke) i probaj opet', thief = 'izađi iz vozila' })[name] or 'nema slobodne ulice u blizini, pomakni se malo'
            notify(('~o~Događaj %s se ne može pokrenuti:~s~ %s.'):format(name, why))
        end
    end)
end)
