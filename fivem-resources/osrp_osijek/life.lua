-- OSRP Osijek - city life: map on the minimap/pause map, parked cars, road signs, pedestrians, traffic
-- Everything here is local to each player (like GTA's own ambient traffic), so it costs the server nothing.

local function W(x, y, z) return vector3(Config.Origin.x + x, Config.Origin.y + y, Config.Origin.z + (z or 0.0)) end

local function firstModel(list)
    for _, m in ipairs(list or {}) do
        local h = joaat(m)
        if IsModelInCdimage(h) and IsModelValid(h) then return h end
    end
    return nil
end

local function load(hash)
    if not hash then return false end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 5000 do Wait(0) end
    return HasModelLoaded(hash)
end

-- v1.0.12: real ground height under (x, y) in city coords, or nil while the map collision there is not loaded yet.
-- Spawning only on loaded ground is what stops cars/peds from falling or hanging in the air.
local function groundAt(x, y, extraZ)
    local w = W(x, y, 0.0)
    RequestCollisionAtCoord(w.x, w.y, w.z)
    local ok, gz = GetGroundZFor_3dCoord(w.x, w.y, w.z + 8.0, false)
    if not ok or math.abs(gz - w.z) > 3.0 then return nil end      -- no ground yet, or hit a roof/bridge
    return vector3(w.x, w.y, gz + (extraZ or 0.0))
end

local function settleVehicle(v)
    SetEntityCollision(v, true, true)
    SetVehicleOnGroundProperly(v)
    local t = GetGameTimer()
    while not HasCollisionLoadedAroundEntity(v) and GetGameTimer() - t < 3000 do Wait(0) end
    SetVehicleOnGroundProperly(v)
end

local function inCity(pos, extra)
    return #(vec2(pos.x, pos.y) - vec2(Config.Origin.x, Config.Origin.y)) < (Config.CityRadius + (extra or 0.0))
end

-- ===================================================================== map / minimap
local MAP_COLOURS = {        -- blip colour, alpha
    -- v1.0.12: GTA radar style - dark land, light roads, grey buildings, green parks, blue river
    land   = { 40, 255 },    -- dark grey ground
    water  = { 38, 255 },    -- Drava (dark blue like the GTA sea)
    walk   = { 39, 200 },    -- sidewalks
    park   = { 25, 230 },    -- parks
    square = { 39, 220 },    -- squares
    road   = { 4, 255 },     -- light roads
    bld    = { 62, 255 },    -- buildings
}

CreateThread(function()
    if not Config.DrawMap then return end
    -- v1.0.15: with MapMode 'nui' the city is drawn as a real map (minimap.lua), no blip rectangles
    for _, r in ipairs((Config.MapMode or 'nui') == 'blips' and Life.MAPRECTS or {}) do
        local kind, cx, cy, w, h = r[1], r[2], r[3], r[4], r[5]
        local c = MAP_COLOURS[kind] or { 4, 120 }
        local b = AddBlipForArea(Config.Origin.x + cx, Config.Origin.y + cy, Config.Origin.z, w, h)
        SetBlipColour(b, c[1])
        SetBlipAlpha(b, c[2])
        SetBlipRotation(b, 0)
        SetBlipDisplay(b, 2)          -- minimap + big map
        SetBlipAsShortRange(b, false)
        SetBlipHiddenOnLegend(b, true)
    end
    for _, l in ipairs(Life.LANDMARKS) do
        local b = AddBlipForCoord(Config.Origin.x + l[2], Config.Origin.y + l[3], Config.Origin.z)
        SetBlipSprite(b, 162)         -- point of interest
        SetBlipColour(b, 5)
        SetBlipScale(b, 0.75)
        SetBlipAsShortRange(b, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(l[1])
        EndTextCommandSetBlipName(b)
    end
    local city = AddBlipForCoord(Config.Origin.x, Config.Origin.y, Config.Origin.z)
    SetBlipSprite(city, 304)
    SetBlipColour(city, 2)
    SetBlipScale(city, 1.0)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('OSIJEK')
    EndTextCommandSetBlipName(city)
end)

-- ===================================================================== parked cars + road signs (streamed)
local parked, signs = {}, {}

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        if Config.ParkedCars then
            for i, p in ipairs(Life.PARKING) do
                local wp = W(p[1], p[2], 0.4)
                local d = #(pos - wp)
                local ground = (d < 150.0 and not (parked[i] and DoesEntityExist(parked[i]))) and groundAt(p[1], p[2], 0.6) or nil
                if ground then
                    local list = Config.ParkedModels
                    local hash = firstModel({ list[(i % #list) + 1], list[1] })
                    if load(hash) then
                        local v = CreateVehicle(hash, ground.x, ground.y, ground.z, p[3], false, false)
                        settleVehicle(v)
                        SetVehicleDoorsLocked(v, 2)
                        SetVehicleColours(v, (i * 7) % 160, (i * 11) % 160)
                        SetVehicleNumberPlateText(v, ('OS %03d'):format(i))
                        SetEntityAsMissionEntity(v, true, true)
                        SetVehicleHasBeenOwnedByPlayer(v, false)
                        SetModelAsNoLongerNeeded(hash)
                        parked[i] = v
                    end
                elseif d > 210.0 and parked[i] then
                    if DoesEntityExist(parked[i]) then DeleteVehicle(parked[i]) end
                    parked[i] = nil
                end
            end
        end
        -- v1.0.14: ambulances at KBC Osijek, air ambulance on the hospital roof, planes at the airport (locked, decoration)
        if Config.SpecialVehicles and Life.SPECIAL then
            for i, sv in ipairs(Life.SPECIAL) do
                local key = 'sp' .. i
                if OsijekTaken and OsijekTaken[key] and GetGameTimer() - OsijekTaken[key] < (Config.TakenRespawnMinutes or 15) * 60000 then
                    goto continue
                end
                local roofZ = sv[3]
                local wp = W(sv[1], sv[2], roofZ or 0.4)
                local d = #(pos - wp)
                if d < 250.0 and not (parked[key] and DoesEntityExist(parked[key])) then
                    local ground
                    if roofZ then
                        RequestCollisionAtCoord(wp.x, wp.y, wp.z)
                        local ok, gz = GetGroundZFor_3dCoord(wp.x, wp.y, wp.z + 5.0, false)
                        if ok and math.abs(gz - wp.z) < 2.0 then ground = vector3(wp.x, wp.y, gz + 0.3) end
                    else
                        ground = groundAt(sv[1], sv[2], 0.6)
                    end
                    local hash = ground and firstModel({ sv[5] })
                    if hash and load(hash) then
                        local v = CreateVehicle(hash, ground.x, ground.y, ground.z, sv[4], false, false)
                        settleVehicle(v)
                        if sv[6] and sv[6] > 0 then SetVehicleLivery(v, sv[6]) end
                        SetVehicleDoorsLocked(v, 2)
                        SetEntityAsMissionEntity(v, true, true)
                        SetVehicleNumberPlateText(v, sv[5] == 'ambulance' and 'HITNA' or 'OSIJEK')
                        SetModelAsNoLongerNeeded(hash)
                        parked[key] = v
                    end
                elseif d > 290.0 and parked[key] then
                    if DoesEntityExist(parked[key]) then DeleteVehicle(parked[key]) end
                    parked[key] = nil
                end
                ::continue::
            end
        end
        for i, s in ipairs(Life.SIGNS) do
            local wp = W(s[2], s[3], 0.26)
            local d = #(pos - wp)
            local ground = (d < 200.0 and not (signs[i] and DoesEntityExist(signs[i]))) and groundAt(s[2], s[3]) or nil
            if ground then
                local hash = firstModel(Config.SignModels[s[1]])
                if load(hash) then
                    local o = CreateObjectNoOffset(hash, ground.x, ground.y, ground.z, false, false, false)
                    SetEntityHeading(o, s[4])
                    FreezeEntityPosition(o, true)
                    SetModelAsNoLongerNeeded(hash)
                    signs[i] = o
                end
            elseif d > 230.0 and signs[i] then
                if DoesEntityExist(signs[i]) then DeleteObject(signs[i]) end
                signs[i] = nil
            end
        end
        Wait(1500)
    end
end)

-- ===================================================================== pedestrians
local peds = {}

local function pedModel(i)
    local list = Config.PedModels
    return firstModel({ list[math.random(#list)], list[(i % #list) + 1], list[1] })
end

local function newWalker(i)
    local w = Life.WALKS[math.random(#Life.WALKS)]
    local t = math.random()
    local x, y = w[1] + (w[3] - w[1]) * t, w[2] + (w[4] - w[2]) * t
    local wp = groundAt(x, y, 0.05)
    if not wp then return end
    local hash = pedModel(i)
    if not load(hash) then return end
    local p = CreatePed(4, hash, wp.x, wp.y, wp.z, 0.0, false, true)
    SetBlockingOfNonTemporaryEvents(p, false)
    SetPedKeepTask(p, true)
    SetModelAsNoLongerNeeded(hash)
    local goEnd = math.random() < 0.5
    peds[i] = { ped = p, walk = w, toEnd = goEnd, sitting = false }
    local tx, ty = goEnd and w[3] or w[1], goEnd and w[4] or w[2]
    local tw = W(tx, ty, 0.3)
    TaskGoStraightToCoord(p, tw.x, tw.y, tw.z, 1.0, -1, 0.0, 0.5)
end

local SCENARIOS = { 'WORLD_HUMAN_SMOKING', 'WORLD_HUMAN_STAND_MOBILE', 'WORLD_HUMAN_AA_COFFEE', 'WORLD_HUMAN_TOURIST_MAP',
                    'WORLD_HUMAN_HANG_OUT_STREET', 'WORLD_HUMAN_DRINKING', 'WORLD_HUMAN_MOBILE_FILM_SHOCKING', 'WORLD_HUMAN_STAND_IMPATIENT' }

local function newStander(i)
    local w = Life.WALKS[math.random(#Life.WALKS)]
    local t = math.random()
    local x, y = w[1] + (w[3] - w[1]) * t, w[2] + (w[4] - w[2]) * t
    local wp = groundAt(x, y, 0.05)
    if not wp then return end
    local hash = pedModel(i + 11)
    if not load(hash) then return end
    local p = CreatePed(4, hash, wp.x, wp.y, wp.z, math.random(0, 359) + 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    TaskStartScenarioInPlace(p, SCENARIOS[math.random(#SCENARIOS)], 0, true)
    peds[i] = { ped = p, sitting = true }
end

local function newSitter(i)
    local b = Life.BENCHES[math.random(#Life.BENCHES)]
    local wp = groundAt(b[1], b[2], 0.05)
    if not wp then return end
    local hash = pedModel(i + 3)
    if not load(hash) then return end
    local p = CreatePed(4, hash, wp.x, wp.y, wp.z, b[3], false, true)
    SetModelAsNoLongerNeeded(hash)
    TaskStartScenarioAtPosition(p, 'PROP_HUMAN_SEAT_BENCH', wp.x, wp.y, wp.z + 0.5, b[3], 0, true, true)
    peds[i] = { ped = p, sitting = true }
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        if Config.Pedestrians and inCity(pos, 150.0) then
            for i = 1, Config.PedCount do
                local e = peds[i]
                if not e or not DoesEntityExist(e.ped) or IsEntityDead(e.ped) then
                    if e and e.ped and DoesEntityExist(e.ped) then SetPedAsNoLongerNeeded(e.ped) end
                    if i % 5 == 0 and #Life.BENCHES > 0 then newSitter(i)
                    elseif i % 3 == 0 then newStander(i)
                    else newWalker(i) end
                elseif not e.sitting then
                    -- turn around at the end of the sidewalk
                    local w = e.walk
                    local tx, ty = e.toEnd and w[3] or w[1], e.toEnd and w[4] or w[2]
                    local tw = W(tx, ty, 0.3)
                    if #(GetEntityCoords(e.ped) - tw) < 2.5 then
                        e.toEnd = not e.toEnd
                        local nx, ny = e.toEnd and w[3] or w[1], e.toEnd and w[4] or w[2]
                        local nw = W(nx, ny, 0.3)
                        TaskGoStraightToCoord(e.ped, nw.x, nw.y, nw.z, 1.0, -1, 0.0, 0.5)
                    elseif #(GetEntityCoords(e.ped) - pos) > 260.0 then
                        DeletePed(e.ped); peds[i] = nil     -- respawned closer next round
                    end
                end
            end
        else
            for i, e in pairs(peds) do
                if e.ped and DoesEntityExist(e.ped) then DeletePed(e.ped) end
                peds[i] = nil
            end
        end
        Wait(2000)
    end
end)

-- ===================================================================== traffic (cars with drivers driving loops)
local cars = {}

local function spawnCar(i)
    local route = Life.ROUTES[(i % #Life.ROUTES) + 1]
    local wpIndex = (i * 3) % #route + 1
    local a, b = route[wpIndex], route[(wpIndex % #route) + 1]
    local t = math.random() * 0.8 + 0.1
    local x, y = a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t
    local heading = (math.deg(math.atan(b[2] - a[2], b[1] - a[1])) - 90.0) % 360.0
    local list = Config.TrafficModels
    local vhash = firstModel({ list[(i % #list) + 1], list[1] })
    local phash = pedModel(i + 7)
    local wp = groundAt(x, y, 0.6)
    if not wp then return end                                   -- road there not loaded yet, try again next round
    local me = GetEntityCoords(PlayerPedId())
    if #(me - wp) > 220.0 or #(me - wp) < 25.0 then return end  -- only near you, never on top of you
    if not load(vhash) or not load(phash) then return end
    local v = CreateVehicle(vhash, wp.x, wp.y, wp.z, heading, false, false)
    settleVehicle(v)
    SetVehicleEngineOn(v, true, true, false)
    local d = CreatePedInsideVehicle(v, 4, phash, -1, false, true)
    SetBlockingOfNonTemporaryEvents(d, true)
    SetDriverAbility(d, 1.0)
    SetDriverAggressiveness(d, 0.0)
    SetModelAsNoLongerNeeded(vhash)
    SetModelAsNoLongerNeeded(phash)
    cars[i] = { veh = v, drv = d, route = route, nextWp = (wpIndex % #route) + 1, stuck = 0, last = GetEntityCoords(v) }
    local n = W(b[1], b[2], 0.5)
    TaskVehicleDriveToCoord(d, v, n.x, n.y, n.z, Config.TrafficSpeed, 0, vhash, Config.DrivingStyle, 4.0, true)
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        if Config.Traffic and inCity(pos, 200.0) then
            for i = 1, Config.TrafficCount do
                local c = cars[i]
                if not c or not DoesEntityExist(c.veh) or not DoesEntityExist(c.drv) or IsEntityDead(c.drv)
                    or GetPedInVehicleSeat(c.veh, -1) ~= c.drv then
                    if c then
                        if c.drv and DoesEntityExist(c.drv) then SetPedAsNoLongerNeeded(c.drv) end
                        if c.veh and DoesEntityExist(c.veh) and GetPedInVehicleSeat(c.veh, -1) ~= PlayerPedId() then SetVehicleAsNoLongerNeeded(c.veh) end
                    end
                    cars[i] = nil
                    spawnCar(i)
                else
                    local vp = GetEntityCoords(c.veh)
                    local wpt = c.route[c.nextWp]
                    local target = W(wpt[1], wpt[2], 0.5)
                    if #(vp - target) < 9.0 then
                        c.nextWp = (c.nextWp % #c.route) + 1
                        local n = c.route[c.nextWp]
                        local nw = W(n[1], n[2], 0.5)
                        TaskVehicleDriveToCoord(c.drv, c.veh, nw.x, nw.y, nw.z, Config.TrafficSpeed, 0, GetEntityModel(c.veh), Config.DrivingStyle, 4.0, true)
                    end
                    -- stuck for 20 s -> remove, a new car comes
                    if #(vp - c.last) < 1.0 then c.stuck = c.stuck + 1 else c.stuck = 0 end
                    c.last = vp
                    if c.stuck > 10 then
                        DeletePed(c.drv); DeleteVehicle(c.veh); cars[i] = nil
                    end
                end
            end
        else
            for i, c in pairs(cars) do
                if c.drv and DoesEntityExist(c.drv) then DeletePed(c.drv) end
                if c.veh and DoesEntityExist(c.veh) and GetPedInVehicleSeat(c.veh, -1) ~= PlayerPedId() then DeleteVehicle(c.veh) end
                cars[i] = nil
            end
        end
        Wait(2000)
    end
end)

-- GTA's own random traffic/peds don't exist out at sea; keep the scripted ones company with normal density
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        if inCity(pos, 0.0) then
            SetVehicleDensityMultiplierThisFrame(0.0)      -- no random GTA cars falling out of the sky here
            SetRandomVehicleDensityMultiplierThisFrame(0.0)
            SetParkedVehicleDensityMultiplierThisFrame(0.0)
            Wait(0)
        else
            Wait(1000)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, v in pairs(parked) do if DoesEntityExist(v) then DeleteVehicle(v) end end
    for _, o in pairs(signs) do if DoesEntityExist(o) then DeleteObject(o) end end
    for _, e in pairs(peds) do if e.ped and DoesEntityExist(e.ped) then DeletePed(e.ped) end end
    for _, c in pairs(cars) do
        if c.drv and DoesEntityExist(c.drv) then DeletePed(c.drv) end
        if c.veh and DoesEntityExist(c.veh) then DeleteVehicle(c.veh) end
    end
end)


-- ===================================================================== v1.0.16: take the parked ambulances / planes / heli
-- Parked ones are local decoration; press F next to one and it becomes a real (networked) vehicle you can drive or fly.
OsijekTaken = {}
CreateThread(function()
    while true do
        local sleep = 500
        if Config.TakeVehicles and Life.SPECIAL then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                local pos = GetEntityCoords(ped)
                for i, sv in ipairs(Life.SPECIAL) do
                    local key = 'sp' .. i
                    local v = parked[key]
                    if v and DoesEntityExist(v) and #(GetEntityCoords(v) - pos) < 6.0 then
                        sleep = 0
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('~INPUT_ENTER~ Uđi u vozilo')
                        EndTextCommandDisplayHelp(0, false, false, -1)
                        if IsControlJustPressed(0, 23) then
                            local c, h, model = GetEntityCoords(v), GetEntityHeading(v), GetEntityModel(v)
                            DeleteVehicle(v)
                            parked[key] = nil
                            OsijekTaken[key] = GetGameTimer()
                            RequestModel(model)
                            while not HasModelLoaded(model) do Wait(0) end
                            local nv = CreateVehicle(model, c.x, c.y, c.z + 0.2, h, true, false)
                            if sv[6] and sv[6] > 0 then SetVehicleLivery(nv, sv[6]) end
                            SetVehicleNumberPlateText(nv, sv[5] == 'ambulance' and 'HITNA' or 'OSIJEK')
                            SetVehicleOnGroundProperly(nv)
                            SetPedIntoVehicle(ped, nv, -1)
                            SetEntityAsNoLongerNeeded(nv)
                            SetModelAsNoLongerNeeded(model)
                        end
                        break
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

-- ===================================================================== staff (hospital reception, doctor, airport check-in, security, pilot)
local staff = {}
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, st in ipairs(Life.STAFF or {}) do
            local wp = W(st[2], st[3], 0.3)
            local d = #(pos - wp)
            if d < 120.0 and not (staff[i] and DoesEntityExist(staff[i])) then
                local g = groundAt(st[2], st[3], 0.0)
                local hash = g and firstModel({ st[1] })
                if hash and load(hash) then
                    local p = CreatePed(4, hash, g.x, g.y, g.z, st[4], false, true)
                    SetEntityInvincible(p, true)
                    SetBlockingOfNonTemporaryEvents(p, true)
                    FreezeEntityPosition(p, true)
                    TaskStartScenarioInPlace(p, st[5], 0, true)
                    SetModelAsNoLongerNeeded(hash)
                    staff[i] = p
                end
            elseif d > 150.0 and staff[i] then
                if DoesEntityExist(staff[i]) then DeletePed(staff[i]) end
                staff[i] = nil
            end
        end
        Wait(2000)
    end
end)

-- ===================================================================== lights inside the hospital lobby and the terminal hall
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local near = false
        for _, l in ipairs(Life.INTERIOR_LIGHTS or {}) do
            local p = W(l[1], l[2], l[3])
            if #(pos - p) < 80.0 then
                near = true
                DrawLightWithRange(p.x, p.y, p.z, 255, 244, 228, 22.0, 2.2)
            end
        end
        Wait(near and 0 or 1000)
    end
end)

-- ===================================================================== NPCs talk to you (English)
local talked = {}
local function bubble(ped, text)
    local untilT = GetGameTimer() + 4500
    CreateThread(function()
        while GetGameTimer() < untilT and DoesEntityExist(ped) do
            local c = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0) + vector3(0.0, 0.0, 0.45)
            local on, sx, sy = World3dToScreen2d(c.x, c.y, c.z)
            if on then
                SetTextScale(0.0, 0.34)
                SetTextFont(4)
                SetTextColour(255, 255, 255, 235)
                SetTextCentre(true)
                SetTextOutline()
                BeginTextCommandDisplayText('STRING')
                AddTextComponentSubstringPlayerName(text)
                EndTextCommandDisplayText(sx, sy)
            end
            Wait(0)
        end
    end)
end

local function npcSay(ped, lines, speech)
    if not ped or not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return end
    TaskTurnPedToFaceEntity(ped, PlayerPedId(), 1500)
    PlayPedAmbientSpeechNative(ped, speech or 'GENERIC_HI', 'SPEECH_PARAMS_FORCE_NORMAL')
    bubble(ped, lines[math.random(#lines)])
end

local function allTalkers()
    local list = {}
    for _, e in pairs(peds) do if e.ped then list[#list + 1] = e.ped end end
    for _, p in pairs(staff) do list[#list + 1] = p end
    return list
end

CreateThread(function()
    while true do
        local sleep = 500
        local me = PlayerPedId()
        if Config.NpcTalk and not IsPedInAnyVehicle(me, false) then
            local pos = GetEntityCoords(me)
            for _, p in ipairs(allTalkers()) do
                if DoesEntityExist(p) then
                    local d = #(GetEntityCoords(p) - pos)
                    if d < 2.6 then
                        sleep = 0
                        if not talked[p] or GetGameTimer() - talked[p] > 60000 then
                            talked[p] = GetGameTimer()
                            npcSay(p, Config.NpcGreetings)
                        end
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Talk')
                        EndTextCommandDisplayHelp(0, false, false, -1)
                        if IsControlJustReleased(0, 38) then
                            talked[p] = GetGameTimer()
                            npcSay(p, Config.NpcChat, 'GENERIC_HOWS_IT_GOING')
                        end
                        break
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
