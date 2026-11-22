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

-- ambulances, planes, heli + v1.0.18 boats in the Drava marina (boats float on the water, anchored)
local SPECIALS = {}
for _, sv in ipairs(Life.SPECIAL or {}) do SPECIALS[#SPECIALS + 1] = sv end
for _, b in ipairs(Life.BOATS or {}) do SPECIALS[#SPECIALS + 1] = { b[1], b[2], false, b[3], b[4], 0, water = true } end

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
        if Config.SpecialVehicles then
            for i, sv in ipairs(SPECIALS) do
                local key = 'sp' .. i
                if OsijekTaken and OsijekTaken[key] and GetGameTimer() - OsijekTaken[key] < (Config.TakenRespawnMinutes or 15) * 60000 then
                    goto continue
                end
                local roofZ = sv[3]
                local wp = W(sv[1], sv[2], roofZ or 0.4)
                local d = #(pos - wp)
                if d < 250.0 and not (parked[key] and DoesEntityExist(parked[key])) then
                    local ground
                    if sv.water then
                        ground = vector3(wp.x, wp.y, 0.35)                 -- GTA sea level
                    elseif roofZ then
                        RequestCollisionAtCoord(wp.x, wp.y, wp.z)
                        local ok, gz = GetGroundZFor_3dCoord(wp.x, wp.y, wp.z + 5.0, false)
                        if ok and math.abs(gz - wp.z) < 2.0 then ground = vector3(wp.x, wp.y, gz + 0.3) end
                    else
                        ground = groundAt(sv[1], sv[2], 0.6)
                    end
                    local hash = ground and firstModel({ sv[5] })
                    if hash and load(hash) then
                        local v = CreateVehicle(hash, ground.x, ground.y, ground.z, sv[4], false, false)
                        if sv.water then
                            SetBoatAnchor(v, true)
                            SetBoatFrozenWhenAnchored(v, true)
                        else
                            settleVehicle(v)
                        end
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
OsijekBenches, OsijekBenchUsed = {}, {}

local function pedModel(i)
    local list = Config.PedModels
    return firstModel({ list[math.random(#list)], list[(i % #list) + 1], list[1] })
end

-- v1.0.20: walkers appear on sidewalks near you (not anywhere in the city); on the promenades some of them jog
local function nearWalk()
    local me = GetEntityCoords(PlayerPedId())
    local mx, my = me.x - Config.Origin.x, me.y - Config.Origin.y
    local opts = {}
    for _, w in ipairs(Life.WALKS) do
        local dx, dy = w[3] - w[1], w[4] - w[2]
        local len2 = dx * dx + dy * dy
        local t = len2 > 0 and math.max(0, math.min(1, ((mx - w[1]) * dx + (my - w[2]) * dy) / len2)) or 0
        local px, py = w[1] + dx * t, w[2] + dy * t
        if (px - mx) ^ 2 + (py - my) ^ 2 < 200.0 ^ 2 then opts[#opts + 1] = { w, t, math.sqrt(len2) } end
    end
    if #opts == 0 then return nil end
    local o = opts[math.random(#opts)]
    local t = math.max(0, math.min(1, o[2] + (math.random() * 2 - 1) * 140.0 / math.max(o[3], 1)))
    return o[1], t, o[3]
end

local RUNNERS = { 'a_m_y_runner_01', 'a_f_y_runner_01', 'a_m_y_runner_02', 'a_f_y_fitness_01', 'a_m_y_beach_01' }

local function newWalker(i)
    local w, t, len = nearWalk()
    if not w then return end
    local x, y = w[1] + (w[3] - w[1]) * t, w[2] + (w[4] - w[2]) * t
    local wp = groundAt(x, y, 0.05)
    if not wp then return end
    local jogger = len > 500 and math.abs(w[2] - w[4]) < 1.0 and (w[2] > 150.0) and math.random() < (Config.JoggerShare or 0.35)
    local hash = jogger and firstModel({ RUNNERS[math.random(#RUNNERS)], RUNNERS[1] }) or pedModel(i)
    if not load(hash) then return end
    local p = CreatePed(4, hash, wp.x, wp.y, wp.z, 0.0, false, true)
    SetBlockingOfNonTemporaryEvents(p, false)
    SetPedKeepTask(p, true)
    SetModelAsNoLongerNeeded(hash)
    local goEnd = math.random() < 0.5
    local speed = jogger and 2.0 or 1.0
    peds[i] = { ped = p, walk = w, toEnd = goEnd, sitting = false, speed = speed }
    local tx, ty = goEnd and w[3] or w[1], goEnd and w[4] or w[2]
    local tw = W(tx, ty, 0.3)
    TaskGoStraightToCoord(p, tw.x, tw.y, tw.z, speed, -1, 0.0, 0.5)
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
    -- a free real bench near you (the bench props are placed by the bench thread below)
    local me = GetEntityCoords(PlayerPedId())
    local free = {}
    for bi, obj in pairs(OsijekBenches) do
        if DoesEntityExist(obj) and not OsijekBenchUsed[bi] and #(GetEntityCoords(obj) - me) < 160.0 then free[#free + 1] = bi end
    end
    if #free == 0 then return newWalker(i) end
    local bi = free[math.random(#free)]
    local obj = OsijekBenches[bi]
    local hash = pedModel(i + 3)
    if not load(hash) then return end
    local c, h = GetEntityCoords(obj), GetEntityHeading(obj) + 180.0
    local r = math.rad(h)
    local p = CreatePed(4, hash, c.x - math.sin(r) * 0.8, c.y + math.cos(r) * 0.8, c.z + 0.1, h, false, true)
    SetModelAsNoLongerNeeded(hash)
    TaskStartScenarioAtPosition(p, 'PROP_HUMAN_SEAT_BENCH', c.x, c.y, c.z + 0.5, h, 0, true, true)
    OsijekBenchUsed[bi] = p
    peds[i] = { ped = p, sitting = true, bench = bi }
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        if Config.Pedestrians and inCity(pos, 150.0) then
            for i = 1, Config.PedCount do
                local e = peds[i]
                if not e or not DoesEntityExist(e.ped) or IsEntityDead(e.ped) then
                    if e and e.ped and DoesEntityExist(e.ped) then SetPedAsNoLongerNeeded(e.ped) end
                    if e and e.bench then OsijekBenchUsed[e.bench] = nil end
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
                        TaskGoStraightToCoord(e.ped, nw.x, nw.y, nw.z, e.speed or 1.0, -1, 0.0, 0.5)
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
        if Config.TakeVehicles then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                local pos = GetEntityCoords(ped)
                for i, sv in ipairs(SPECIALS) do
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
                            if sv.water then SetBoatAnchor(nv, false) else SetVehicleOnGroundProperly(nv) end
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
            if #(pos - p) < (l[5] or 80.0) then
                near = true
                DrawLightWithRange(p.x, p.y, p.z, 255, 236, 210, l[4] or 22.0, l[4] and 1.6 or 2.2)
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


-- ===================================================================== v1.0.18: real GTA benches you can sit on (E)
-- Life.BENCHES heading = the way you look when sitting. GTA bench props face backwards, so the prop gets +180.
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, b in ipairs(Life.BENCHES or {}) do
            local wp = W(b[1], b[2], 0.3)
            local d = #(pos - wp)
            local obj = OsijekBenches[i]
            if d < 180.0 and not (obj and DoesEntityExist(obj)) then
                local g = groundAt(b[1], b[2], 0.0)
                local hash = g and firstModel(Config.BenchModels)
                if hash and load(hash) then
                    local o = CreateObjectNoOffset(hash, g.x, g.y, g.z, false, false, false)
                    SetEntityHeading(o, (b[3] + 180.0) % 360.0)
                    FreezeEntityPosition(o, true)
                    SetModelAsNoLongerNeeded(hash)
                    OsijekBenches[i] = o
                end
            elseif d > 210.0 and obj then
                if DoesEntityExist(obj) then DeleteObject(obj) end
                OsijekBenches[i] = nil
                OsijekBenchUsed[i] = nil
            end
        end
        Wait(1500)
    end
end)

local sitting = nil
-- furniture you can use: scenario, height above the prop origin, reach, help text
SEATS = {
    sofa     = { 'PROP_HUMAN_SEAT_ARMCHAIR', 0.5, 1.6 },
    fotelja  = { 'PROP_HUMAN_SEAT_ARMCHAIR', 0.5, 1.3 },
    stolica  = { 'PROP_HUMAN_SEAT_CHAIR', 0.5, 1.0 },
    stolac   = { 'PROP_HUMAN_SEAT_BAR', 0.75, 0.9 },
    krevet_d = { 'WORLD_HUMAN_SUNBATHE_BACK', 0.75, 1.6, '~INPUT_CONTEXT~ Lezi' },
    -- v1.0.22: Blender props in the hospital, the terminal and on the beach
    osrpprop_wchairs   = { 'PROP_HUMAN_SEAT_CHAIR', 0.5, 1.3 },
    osrpprop_gateseats = { 'PROP_HUMAN_SEAT_CHAIR', 0.5, 1.8 },
    osrpprop_lounger   = { 'WORLD_HUMAN_SUNBATHE_BACK', 0.45, 1.3, '~INPUT_CONTEXT~ Lezi' },
    osrpprop_hbed      = { 'WORLD_HUMAN_SUNBATHE_BACK', 0.75, 1.4, '~INPUT_CONTEXT~ Lezi' },
}
CreateThread(function()
    while true do
        local sleep = 400
        local ped = PlayerPedId()
        if sitting then
            sleep = 0
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Ustani')
            EndTextCommandDisplayHelp(0, false, false, -1)
            if IsControlJustReleased(0, 38) or IsEntityDead(ped) then
                ClearPedTasks(ped)
                OsijekBenchUsed[sitting] = nil
                sitting = nil
                Wait(600)
            end
        elseif not IsPedInAnyVehicle(ped, false) then
            local pos = GetEntityCoords(ped)
            -- v1.0.21: sofas, armchairs, chairs, stools and beds in the flats
            for i, obj in pairs(OsijekFurniture or {}) do
                local f = Furniture[i]
                local sc = f and SEATS[f.kind]
                if sc and DoesEntityExist(obj) and #(GetEntityCoords(obj) - pos) < (sc[3] or 1.5) and not OsijekBenchUsed['f' .. i] then
                    sleep = 0
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName(sc[4] or '~INPUT_CONTEXT~ Sjedni')
                    EndTextCommandDisplayHelp(0, false, false, -1)
                    if IsControlJustReleased(0, 38) then
                        local c = GetEntityCoords(obj)
                        -- v1.0.22: the map stores where the piece looks (same for GTA props and our own props)
                        TaskStartScenarioAtPosition(ped, sc[1], c.x, c.y, c.z + sc[2], f.h + 0.0, 0, true, true)
                        OsijekBenchUsed['f' .. i] = ped
                        sitting = 'f' .. i
                        Wait(800)
                    end
                    goto done
                end
            end
            for i, obj in pairs(OsijekBenches) do
                if DoesEntityExist(obj) and #(GetEntityCoords(obj) - pos) < 1.8 and not OsijekBenchUsed[i] then
                    sleep = 0
                    BeginTextCommandDisplayHelp('STRING')
                    AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Sjedni')
                    EndTextCommandDisplayHelp(0, false, false, -1)
                    if IsControlJustReleased(0, 38) then
                        local c = GetEntityCoords(obj)
                        TaskStartScenarioAtPosition(ped, 'PROP_HUMAN_SEAT_BENCH', c.x, c.y, c.z + 0.5, GetEntityHeading(obj) + 180.0, 0, true, true)
                        OsijekBenchUsed[i] = ped
                        sitting = i
                        Wait(800)
                    end
                    break
                end
            end
            ::done::
        end
        Wait(sleep)
    end
end)

-- ===================================================================== v1.0.18: fountain water jets
CreateThread(function()
    local fx = {}
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i, f in ipairs(Life.FOUNTAINS or {}) do
            local p = W(f[1], f[2], f[3])
            local d = #(pos - p)
            if d < 120.0 and not fx[i] then
                RequestNamedPtfxAsset('core')
                local t = GetGameTimer()
                while not HasNamedPtfxAssetLoaded('core') and GetGameTimer() - t < 3000 do Wait(0) end
                UseParticleFxAssetNextCall('core')
                local h = StartParticleFxLoopedAtCoord(Config.FountainParticle or 'ent_amb_fountain_pour', p.x, p.y, p.z, 0.0, 0.0, 0.0, 1.0, false, false, false, false)
                fx[i] = (h and h ~= 0) and h or -1
            elseif d > 150.0 and fx[i] then
                if fx[i] ~= -1 then StopParticleFxLooped(fx[i], false) end
                fx[i] = nil
            end
        end
        Wait(2000)
    end
end)

-- ===================================================================== v1.0.18: get out of the water (Drava / sea around the city)
CreateThread(function()
    while true do
        local sleep = 1000
        local ped = PlayerPedId()
        if IsEntityInWater(ped) and not IsPedInAnyVehicle(ped, false) and IsPedSwimming(ped) and inCity(GetEntityCoords(ped), 100.0) then
            sleep = 0
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Izađi na obalu (ili plivaj do stepenica)')
            EndTextCommandDisplayHelp(0, false, false, -1)
            if IsControlJustReleased(0, 38) then
                local c = GetEntityCoords(ped)
                local lx, ly = c.x - Config.Origin.x, c.y - Config.Origin.y
                local tx, ty
                if ly > 175.0 and ly < 265.0 and math.abs(lx) < 560.0 then          -- in the Drava
                    tx, ty = lx, (ly < 220.0) and 168.0 or 272.0
                else                                                                -- sea around the city
                    tx = math.max(-545.0, math.min(545.0, lx))
                    ty = math.max(-775.0, math.min(340.0, ly))
                    if ty > 170.0 and ty < 270.0 then ty = 168.0 end
                end
                DoScreenFadeOut(400)
                while not IsScreenFadedOut() do Wait(0) end
                local g = groundAt(tx, ty, 1.0) or W(tx, ty, 1.0)
                SetEntityCoords(ped, g.x, g.y, g.z, false, false, false, false)
                Wait(300)
                DoScreenFadeIn(500)
            end
        end
        Wait(sleep)
    end
end)


-- ===================================================================== v1.0.20: cyclists on the Drava bike paths
local bikers = {}
local BIKES = { 'cruiser', 'scorcher', 'bmx', 'tribike', 'fixter', 'tribike2' }

local function newCyclist(i)
    local routes = Life.BIKEROUTES or {}
    if #routes == 0 then return end
    local me = GetEntityCoords(PlayerPedId())
    local r = routes[math.random(#routes)]
    local mx = me.x - Config.Origin.x
    if math.abs((me.y - Config.Origin.y) - r[2]) > 260.0 then return end
    local dir = math.random() < 0.5 and 1 or -1
    local x = math.max(r[1] + 5, math.min(r[3] - 5, mx + (math.random() * 2 - 1) * 180.0))
    local lane = r[2] - dir * 0.6                                  -- ride on the right half of the path
    local g = groundAt(x, lane, 0.2)
    if not g or #(g - me) < 35.0 then return end
    local bh = firstModel({ BIKES[math.random(#BIKES)], 'cruiser', 'bmx' })
    local ph = firstModel({ RUNNERS[math.random(#RUNNERS)], 'a_m_y_cyclist_01', 'a_m_y_roadcyc_01' })
    if not bh or not ph or not load(bh) or not load(ph) then return end
    local v = CreateVehicle(bh, g.x, g.y, g.z, dir == 1 and 270.0 or 90.0, false, false)
    local d = CreatePedInsideVehicle(v, 4, ph, -1, false, true)
    SetModelAsNoLongerNeeded(bh)
    SetModelAsNoLongerNeeded(ph)
    SetBlockingOfNonTemporaryEvents(d, true)
    SetEntityAsMissionEntity(v, true, true)
    local endX = dir == 1 and r[3] or r[1]
    local t = W(endX, lane, 0.3)
    TaskVehicleDriveToCoord(d, v, t.x, t.y, t.z, (Config.CyclistSpeed or 6.0), 0, bh, 786603, 3.0, true)
    bikers[i] = { veh = v, drv = d, target = t, last = GetEntityCoords(v), stuck = 0 }
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        if Config.Cyclists and Config.Cyclists > 0 and inCity(pos, 150.0) then
            for i = 1, Config.Cyclists do
                local b = bikers[i]
                if not b or not DoesEntityExist(b.veh) or not DoesEntityExist(b.drv) or IsEntityDead(b.drv) then
                    if b then
                        if DoesEntityExist(b.drv) then DeletePed(b.drv) end
                        if DoesEntityExist(b.veh) and GetPedInVehicleSeat(b.veh, -1) ~= PlayerPedId() then DeleteVehicle(b.veh) end
                    end
                    bikers[i] = nil
                    newCyclist(i)
                else
                    local vp = GetEntityCoords(b.veh)
                    if #(vp - b.last) < 0.5 then b.stuck = b.stuck + 1 else b.stuck = 0 end
                    b.last = vp
                    if #(vp - b.target) < 8.0 or #(vp - pos) > 320.0 or b.stuck > 8 then
                        DeletePed(b.drv)
                        if GetPedInVehicleSeat(b.veh, -1) ~= PlayerPedId() then DeleteVehicle(b.veh) end
                        bikers[i] = nil
                    end
                end
            end
        else
            for i, b in pairs(bikers) do
                if DoesEntityExist(b.drv) then DeletePed(b.drv) end
                if DoesEntityExist(b.veh) and GetPedInVehicleSeat(b.veh, -1) ~= PlayerPedId() then DeleteVehicle(b.veh) end
                bikers[i] = nil
            end
        end
        Wait(2500)
    end
end)


-- ===================================================================== v1.0.22: people on the beach
-- sunbathers on the loungers, people on the sand, swimmers in the Drava and divers using the pier + tower
local BEACH_PEDS = { 'a_f_y_beach_01', 'a_f_y_beach_02', 'a_m_y_beach_01', 'a_m_y_beach_02', 'a_m_y_beach_03',
                     'a_m_y_beach_04', 'a_f_m_beach_01', 'a_m_m_beach_01', 'a_m_m_beach_02', 'a_m_o_beach_01' }
local SAND_SC = { 'WORLD_HUMAN_SUNBATHE', 'WORLD_HUMAN_SUNBATHE_BACK', 'WORLD_HUMAN_PICNIC', 'WORLD_HUMAN_YOGA',
                  'WORLD_HUMAN_MUSCLE_FLEX', 'WORLD_HUMAN_TOURIST_MOBILE', 'WORLD_HUMAN_DRINKING', 'WORLD_HUMAN_HANG_OUT_STREET' }
local beach = { peds = {}, on = false }

local function beachPed(i, x, y, z, h)
    local m = BEACH_PEDS[(i % #BEACH_PEDS) + 1]
    local hash = firstModel({ m, 'a_m_y_beach_01' })
    if not (hash and load(hash)) then return nil end
    local w = W(x, y, z)
    local p = CreatePed(4, hash, w.x, w.y, w.z, h or 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetBlockingOfNonTemporaryEvents(p, true)
    SetPedKeepTask(p, true)
    SetPedCanRagdoll(p, true)
    SetPedDiesInWater(p, false)
    SetPedMaxTimeUnderwater(p, 60.0)
    beach.peds[#beach.peds + 1] = p
    return p
end

local function goTo(p, x, y, z, speed, timeout)
    local w = W(x, y, z or 0.0)
    TaskGoStraightToCoord(p, w.x, w.y, w.z, speed or 1.0, -1, 0.0, 0.5)
    local t = GetGameTimer()
    while DoesEntityExist(p) and beach.on do
        local c = GetEntityCoords(p)
        if #(vec2(c.x, c.y) - vec2(w.x, w.y)) < 0.9 then return true end
        if GetGameTimer() - t > (timeout or 25000) then return false end
        Wait(250)
    end
    return false
end

-- a diver: walk onto the pier, climb the tower (or the board), walk off the edge, swim back, repeat
local function diver(p, k)
    local B = Life.BEACH
    local Z = B.z
    CreateThread(function()
        while DoesEntityExist(p) and beach.on do
            local ok = true
            local route = ({ B.board, B.jump3, B.jump5 })[(k % 3) + 1]
            -- down the sand onto the pier; tower divers then go up the stairs (points 3 + 4)
            for n, pt in ipairs(B.jump) do
                if ok and (n <= 2 or route ~= B.board) then ok = goTo(p, pt[1], pt[2], Z[1], 1.0) end
            end
            for n, pt in ipairs(route) do
                if ok then ok = goTo(p, pt[1], pt[2], Z[1], n == #route and 2.0 or 1.0, n == #route and 4000 or 25000) end
            end
            -- in the water now (or stuck): swim back to the beach
            local t = GetGameTimer()
            while DoesEntityExist(p) and beach.on and not IsEntityInWater(p) and GetGameTimer() - t < 6000 do Wait(300) end
            Wait(1500)
            for _, pt in ipairs(B.out) do
                if DoesEntityExist(p) and beach.on then goTo(p, pt[1], pt[2], Z[4], 1.0, 45000) end
            end
            Wait(math.random(4000, 12000))
            if not ok and DoesEntityExist(p) and beach.on then        -- reset a stuck diver on the sand
                local w = W(B.jump[1][1], B.jump[1][2], 0.3)
                SetEntityCoords(p, w.x, w.y, w.z, false, false, false, false)
            end
        end
    end)
end

local function beachUp()
    local B = Life.BEACH
    if not B then return end
    beach.on = true
    local n = 0
    for i, l in ipairs(B.loungers or {}) do              -- every 2nd lounger has somebody on it
        if i % 2 == 1 then
            n = n + 1
            local p = beachPed(n, l[1], l[2], 0.6, l[3])
            if p then
                local w = W(l[1], l[2], 0.12 + 0.45)
                TaskStartScenarioAtPosition(p, 'WORLD_HUMAN_SUNBATHE_BACK', w.x, w.y, w.z, l[3], 0, true, true)
            end
        end
    end
    for i, s in ipairs(B.stand or {}) do
        n = n + 1
        local p = beachPed(n, s[1], s[2], 0.3, s[3])
        if p then TaskStartScenarioInPlace(p, SAND_SC[(i % #SAND_SC) + 1], 0, true) end
    end
    for i, sw in ipairs(B.swim or {}) do                -- swimmers going back and forth
        n = n + 1
        local p = beachPed(n, sw[1], sw[2], B.z[4], 0.0)
        if p then
            CreateThread(function()
                local a = true
                while DoesEntityExist(p) and beach.on do
                    if a then goTo(p, sw[3], sw[4], B.z[4], 1.0, 40000) else goTo(p, sw[1], sw[2], B.z[4], 1.0, 40000) end
                    a = not a
                    Wait(math.random(1000, 6000))
                end
            end)
        end
    end
    for k = 1, 4 do                                       -- divers
        n = n + 1
        local p = beachPed(n, B.jump[1][1] + k * 1.5, B.jump[1][2] + k, 0.3, 180.0)
        if p then
            Wait(k * 3000)
            diver(p, k)
        end
    end
end

local function beachDown()
    beach.on = false
    for _, p in ipairs(beach.peds) do if DoesEntityExist(p) then DeletePed(p) end end
    beach.peds = {}
end

CreateThread(function()
    while true do
        local B = Life.BEACH
        if B and B.jump and B.jump[1] then
            local c = W(B.jump[1][1], B.jump[1][2], 0.0)
            local d = #(GetEntityCoords(PlayerPedId()) - c)
            if d < 160.0 and not beach.on then
                -- wait for the sand collision under the beach, otherwise people fall through
                if groundAt(B.jump[1][1], B.jump[1][2], 0.0) then beachUp() end
            elseif d > 220.0 and beach.on then
                beachDown()
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then beachDown() end
end)
