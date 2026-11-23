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
                        local L = Config.PoliceLivery            -- v1.0.27: white Croatian police cars
                        if L and L.Enabled then
                            for _, m in ipairs(L.Models) do
                                if sv[5] == m then SetVehicleColours(v, L.Colour, L.Colour) SetVehicleNumberPlateText(v, 'POLICIJA') end
                            end
                        end
                        SetVehicleDoorsLocked(v, 2)
                        SetEntityAsMissionEntity(v, true, true)
                        local isPol = false
                        for _, m in ipairs((Config.Liveries or {}).PoliceModels or {}) do if sv[5] == m then isPol = true end end
                        if isPol then SetVehicleColours(v, 111, 111) end
                        SetVehicleNumberPlateText(v, isPol and 'POLICIJA' or (sv[5] == 'ambulance' and 'HITNA' or 'OSIJEK'))
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
                    SetEntityHeading(o, s[4] + ((Config.SignTurn or {})[s[1]] or 0.0))
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
    SetBlockingOfNonTemporaryEvents(p, true)        -- v1.0.27: stay on the sidewalk, do not wander over the grass
    SetPedKeepTask(p, true)
    SetPedPathCanUseClimbovers(p, false)
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
                    -- v1.0.27: walkers follow the sidewalk network: at the end of a sidewalk they cross to the next one
                    -- (or turn around), and if anything knocks them off their path they go back to the sidewalk
                    local w = e.walk
                    local tx, ty = e.toEnd and w[3] or w[1], e.toEnd and w[4] or w[2]
                    local tw = W(tx, ty, 0.3)
                    local pc = GetEntityCoords(e.ped)
                    if e.via then
                        local vw = W(e.via[1], e.via[2], 0.3)
                        if #(pc.xy - vw.xy) < 2.0 then
                            e.via = nil
                            TaskGoStraightToCoord(e.ped, tw.x, tw.y, tw.z, e.speed or 1.0, -1, 0.0, 0.5)
                        elseif GetScriptTaskStatus(e.ped, 0x7d8f4411) == 7 then
                            TaskGoStraightToCoord(e.ped, vw.x, vw.y, vw.z, e.speed or 1.0, -1, 0.0, 0.5)
                        end
                    elseif #(pc.xy - tw.xy) < 2.5 then
                        local nextW, nextEnd, best = nil, nil, {}
                        for _, o in ipairs(Life.WALKS) do
                            if o ~= w then
                                for k = 0, 1 do
                                    local ox, oy = o[1 + k * 2], o[2 + k * 2]
                                    local d = math.sqrt((ox - tx) ^ 2 + (oy - ty) ^ 2)
                                    if d < 22.0 then best[#best + 1] = { o, k == 0, ox, oy } end
                                end
                            end
                        end
                        if #best > 0 and math.random() < 0.8 then
                            local b = best[math.random(#best)]
                            e.walk, e.toEnd, e.via = b[1], b[2], { b[3], b[4] }
                            local vw = W(b[3], b[4], 0.3)
                            TaskGoStraightToCoord(e.ped, vw.x, vw.y, vw.z, e.speed or 1.0, -1, 0.0, 0.5)
                        else
                            e.toEnd = not e.toEnd
                            local nx, ny = e.toEnd and w[3] or w[1], e.toEnd and w[4] or w[2]
                            local nw = W(nx, ny, 0.3)
                            TaskGoStraightToCoord(e.ped, nw.x, nw.y, nw.z, e.speed or 1.0, -1, 0.0, 0.5)
                        end
                    elseif #(pc - pos) > 260.0 then
                        DeletePed(e.ped); peds[i] = nil     -- respawned closer next round
                    else
                        -- off the sidewalk line or standing still -> back onto the sidewalk, then on
                        local lx, ly = pc.x - Config.Origin.x, pc.y - Config.Origin.y
                        local dx, dy = w[3] - w[1], w[4] - w[2]
                        local len2 = math.max(0.01, dx * dx + dy * dy)
                        local t = math.max(0, math.min(1, ((lx - w[1]) * dx + (ly - w[2]) * dy) / len2))
                        local px, py = w[1] + dx * t, w[2] + dy * t
                        if (px - lx) ^ 2 + (py - ly) ^ 2 > 16.0 then
                            e.via = { px, py }
                            local vw = W(px, py, 0.3)
                            TaskGoStraightToCoord(e.ped, vw.x, vw.y, vw.z, e.speed or 1.0, -1, 0.0, 0.5)
                        elseif GetScriptTaskStatus(e.ped, 0x7d8f4411) == 7 and not (OsijekDialogOpen and OsijekDialogOpen()) then
                            TaskGoStraightToCoord(e.ped, tw.x, tw.y, tw.z, e.speed or 1.0, -1, 0.0, 0.5)
                        end
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

-- ===================================================================== v1.0.41 traffic on the whole road network
-- Life.ROADNET = { nodes = { {x, y} }, edges = { {a, b, width, speed} } } (city coordinates, made by the map export)
-- Cars drive in the right-hand lane, pick a new street at every crossing (no U-turns unless it is a dead end),
-- slow down before crossings, keep a gap to the car in front, spawn out of sight and vanish far away.
local cars = {}
local NET = Life.ROADNET
local adj = {}
if NET and NET.nodes then
    for ei, e in ipairs(NET.edges) do
        local a, b = e[1] + 1, e[2] + 1
        adj[a] = adj[a] or {}; adj[b] = adj[b] or {}
        adj[a][#adj[a] + 1] = { e = ei, to = b }
        adj[b][#adj[b] + 1] = { e = ei, to = a }
    end
end

local function lane(ei, from, to, t)
    -- point on the right-hand lane of edge ei going from node 'from' to node 'to', t = metres from 'from'
    local e = NET.edges[ei]
    local A, B = NET.nodes[from], NET.nodes[to]
    local dx, dy = B[1] - A[1], B[2] - A[2]
    local L = math.sqrt(dx * dx + dy * dy)
    dx, dy = dx / L, dy / L
    local off = e[3] / 4.0                                     -- v1.0.45: middle of the right-hand half (wider roads)
    t = math.max(0.0, math.min(L, t))
    return A[1] + dx * t + dy * off, A[2] + dy * t - dx * off, L, dx, dy
end

local function pickNext(at, cameFrom)
    local opts = {}
    for _, o in ipairs(adj[at] or {}) do
        if o.to ~= cameFrom then opts[#opts + 1] = o end
    end
    if #opts == 0 then opts = adj[at] or {} end
    return opts[math.random(#opts)]
end

local function driveTo(c)
    -- target: 9 m before the end node (then the turn is planned), speed of this street
    local x, y, L = lane(c.e, c.from, c.to, 0)
    local tx, ty = lane(c.e, c.from, c.to, math.max(L - 9.0, L * 0.5))
    local es = NET.edges[c.e][4]
    local sp = (es >= 19.0 and es or math.min(es, Config.TrafficSpeed or 13.5)) * (c.mood or 1.0)   -- bypass keeps its 70 km/h
    local p = W(tx, ty, 0.5)
    TaskVehicleDriveToCoord(c.drv, c.veh, p.x, p.y, p.z, sp, 0, GetEntityModel(c.veh), Config.DrivingStyle, 3.0, true)
    c.tx, c.ty, c.phase = tx, ty, 'edge'
end

local function turnTo(c)
    -- through the crossing onto the next street (aim 12 m into it)
    local o = pickNext(c.to, c.from)
    if not o then return false end
    c.from, c.to, c.e = c.to, o.to, o.e
    local tx, ty = lane(c.e, c.from, c.to, 12.0)
    local p = W(tx, ty, 0.5)
    TaskVehicleDriveToCoord(c.drv, c.veh, p.x, p.y, p.z, 7.0, 0, GetEntityModel(c.veh), Config.DrivingStyle, 3.0, true)
    c.tx, c.ty, c.phase = tx, ty, 'turn'
    return true
end

local function spawnCar(i, me)
    if not NET or not NET.edges or #NET.edges == 0 then return end
    local mx, my = me.x - Config.Origin.x, me.y - Config.Origin.y
    for _ = 1, 12 do                                              -- find a street piece 70-260 m away
        local ei = math.random(#NET.edges)
        local e = NET.edges[ei]
        local from, to = e[1] + 1, e[2] + 1
        if math.random() < 0.5 then from, to = to, from end
        local x, y, L, dx, dy = lane(ei, from, to, 0)
        local t = math.random() * math.max(1.0, L - 20.0) + 10.0
        x, y = lane(ei, from, to, t)
        local d = math.sqrt((x - mx) ^ 2 + (y - my) ^ 2)
        local wv = W(x, y, 1.5)
        if d > 70.0 and d < 260.0 and L > 25.0 and not (d < 180.0 and IsSphereVisible(wv.x, wv.y, wv.z, 3.0)) then
            local wp = groundAt(x, y, 0.6)
            if not wp then return end
            for _, o in pairs(cars) do
                if o.veh and DoesEntityExist(o.veh) and #(GetEntityCoords(o.veh) - wp) < 14.0 then return end
            end
            local list = Config.TrafficModels
            local vhash = firstModel({ list[math.random(#list)], list[1] })
            local phash = pedModel(i + 7)
            if not load(vhash) or not load(phash) then return end
            local heading = (math.deg(math.atan(dy, dx)) - 90.0) % 360.0
            local v = CreateVehicle(vhash, wp.x, wp.y, wp.z, heading, false, false)
            settleVehicle(v)
            SetVehicleEngineOn(v, true, true, false)
            local pal = Config.TrafficColours or { 0, 111, 4 }
            local col = pal[math.random(#pal)]
            SetVehicleColours(v, col, col)
            SetVehicleExtraColours(v, col, 156)
            SetVehicleDirtLevel(v, math.random() * 4.0)
            local A = 'ABCDEFGHIJKLMNOPRSTUVZ'
            local r1, r2 = math.random(#A), math.random(#A)
            SetVehicleNumberPlateText(v, ('OS%03d%s%s'):format(math.random(100, 999), A:sub(r1, r1), A:sub(r2, r2)))
            SetVehicleNumberPlateTextIndex(v, 1)
            local drv = CreatePedInsideVehicle(v, 4, phash, -1, false, true)
            SetBlockingOfNonTemporaryEvents(drv, true)
            SetDriverAbility(drv, 1.0)
            SetDriverAggressiveness(drv, 0.0)
            SetModelAsNoLongerNeeded(vhash)
            SetModelAsNoLongerNeeded(phash)
            cars[i] = { veh = v, drv = drv, e = ei, from = from, to = to, stuck = 0, last = GetEntityCoords(v), mood = 0.85 + math.random() * 0.25 }
            SetVehicleForwardSpeed(v, math.min(e[4], Config.TrafficSpeed or 13.5) * 0.7)
            driveTo(cars[i])
            return
        end
    end
end

local function removeCar(i, c)
    if c.drv and DoesEntityExist(c.drv) then DeletePed(c.drv) end
    if c.veh and DoesEntityExist(c.veh) and GetPedInVehicleSeat(c.veh, -1) ~= PlayerPedId() then DeleteVehicle(c.veh) end
    cars[i] = nil
end

local function trafficArea(pos)
    return #(vec2(pos.x, pos.y) - vec2(Config.Origin.x, Config.Origin.y)) < (Config.MapRadius or Config.CityRadius) + 200.0
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        if Config.Traffic and NET and trafficArea(me) then
            local spawned = 0
            for i = 1, Config.TrafficCount do
                local c = cars[i]
                if c and (not DoesEntityExist(c.veh) or not DoesEntityExist(c.drv) or IsEntityDead(c.drv)
                          or GetPedInVehicleSeat(c.veh, -1) ~= c.drv) then
                    if c.drv and DoesEntityExist(c.drv) then SetPedAsNoLongerNeeded(c.drv) end
                    if c.veh and DoesEntityExist(c.veh) and GetPedInVehicleSeat(c.veh, -1) ~= PlayerPedId() then SetVehicleAsNoLongerNeeded(c.veh) end
                    cars[i] = nil
                    c = nil
                end
                if not c then
                    if spawned < 2 then spawnCar(i, me) spawned = spawned + 1 end       -- a couple per round, no pop-in wave
                else
                    local vp = GetEntityCoords(c.veh)
                    if #(vp - me) > 380.0 then
                        removeCar(i, c)
                    else
                        local t = W(c.tx, c.ty, 0.5)
                        if #(vec2(vp.x, vp.y) - vec2(t.x, t.y)) < 7.0 then
                            if c.phase == 'edge' then
                                -- v1.0.45: give way - wait (max ~4 s) while another car is turning in this crossing
                                local node = NET.nodes[c.to]
                                local busy = false
                                for j, o in pairs(cars) do
                                    if j ~= i and o.phase == 'turn' and o.veh and DoesEntityExist(o.veh) then
                                        local op = GetEntityCoords(o.veh)
                                        if #(vec2(op.x - Config.Origin.x, op.y - Config.Origin.y) - vec2(node[1], node[2])) < 16.0 then busy = true break end
                                    end
                                end
                                c.wait = busy and (c.wait or 0) + 1 or 0
                                if busy and c.wait < 6 then
                                    TaskVehicleTempAction(c.drv, c.veh, 6, 800)          -- brake and wait
                                    c.stuck = 0
                                else
                                    c.wait = 0
                                    turnTo(c)
                                end
                            else
                                driveTo(c)
                            end
                        end
                        if #(vp - c.last) < 0.8 then c.stuck = c.stuck + 1 else c.stuck = 0 end
                        c.last = vp
                        if c.stuck > 14 then removeCar(i, c) end                       -- stuck ~10 s: a new car comes
                    end
                end
            end
        else
            for i, c in pairs(cars) do removeCar(i, c) end
        end
        Wait(700)
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
OsijekPedInfo = {}          -- v1.0.25: model + scenario of the NPCs (dialogs use it)
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
                    OsijekPedInfo[p] = { model = st[1], scenario = st[5], frozen = true }
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
    if not (OsijekPedInfo[ped] and OsijekPedInfo[ped].frozen) then TaskTurnPedToFaceEntity(ped, PlayerPedId(), 1500) end
    if Config.NpcVoice ~= false then PlayPedAmbientSpeechNative(ped, speech or 'GENERIC_HI', 'SPEECH_PARAMS_FORCE_NORMAL') end
    bubble(ped, lines[math.random(#lines)])
end

OsijekExtraTalkers = {}        -- v1.0.25: beach + airport people can be talked to too
local function allTalkers()
    local list = {}
    for _, e in pairs(peds) do if e.ped then list[#list + 1] = e.ped end end
    for _, p in pairs(staff) do list[#list + 1] = p end
    for p in pairs(OsijekExtraTalkers) do list[#list + 1] = p end
    return list
end

local function L(t)       -- text in the NPC language (Config.NpcLanguage = 'hr' | 'en')
    if type(t) ~= 'table' then return t end
    return t[Config.NpcLanguage or 'hr'] or t.hr or t.en
end

CreateThread(function()
    while true do
        local sleep = 500
        local me = PlayerPedId()
        if Config.NpcTalk and not IsPedInAnyVehicle(me, false) and not (OsijekDialogOpen and OsijekDialogOpen()) then
            local pos = GetEntityCoords(me)
            for _, p in ipairs(allTalkers()) do
                if DoesEntityExist(p) and not IsPedInAnyVehicle(p, false) and not IsPedDeadOrDying(p, true) then
                    local d = #(GetEntityCoords(p) - pos)
                    if d < 2.6 then
                        sleep = 0
                        if not talked[p] or GetGameTimer() - talked[p] > 60000 then
                            talked[p] = GetGameTimer()
                            local g = L(Config.NpcGreetings)
                            npcSay(p, g)
                        end
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName(Config.NpcLanguage == 'en' and '~INPUT_CONTEXT~ Talk' or '~INPUT_CONTEXT~ Razgovaraj')
                        EndTextCommandDisplayHelp(0, false, false, -1)
                        if IsControlJustReleased(0, 38) then
                            talked[p] = GetGameTimer()
                            if OsijekOpenDialog then OsijekOpenDialog(p) else npcSay(p, L(Config.NpcChat), 'GENERIC_HOWS_IT_GOING') end
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
    OsijekExtraTalkers[p] = true
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
    for _, p in ipairs(beach.peds) do OsijekExtraTalkers[p] = nil if DoesEntityExist(p) then DeletePed(p) end end
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

-- ===================================================================== v1.0.25: passengers in the airport terminal
-- queues at the check-in desks, people on the gate seats, at the kiosks + baggage belts, walkers with luggage
local AIR_PEDS = { 'a_m_y_business_01', 'a_f_y_business_01', 'a_f_y_tourist_01', 'a_m_m_tourist_01', 'a_f_y_hipster_01',
                   'a_m_y_hipster_01', 'a_m_m_business_01', 'a_f_m_tourist_01', 'a_f_y_bevhills_01', 'a_m_y_bevhills_01' }
local air = { peds = {}, on = false }

local function airPed(i, x, y, h, scenario)
    local A = Life.AIRPORT
    local hash = firstModel({ AIR_PEDS[(i % #AIR_PEDS) + 1], 'a_m_y_business_01' })
    if not (hash and load(hash)) then return nil end
    local w = W(x, y, A.z[1])
    local p = CreatePed(4, hash, w.x, w.y, w.z, h or 0.0, false, true)
    SetModelAsNoLongerNeeded(hash)
    SetBlockingOfNonTemporaryEvents(p, true)
    SetPedKeepTask(p, true)
    air.peds[#air.peds + 1] = p
    OsijekExtraTalkers[p] = true
    OsijekPedInfo[p] = { role = 'traveler', scenario = scenario }
    if scenario then TaskStartScenarioInPlace(p, scenario, 0, true) end
    return p
end

local function airUp()
    local A = Life.AIRPORT
    if not A then return end
    air.on = true
    local n = 0
    local QSC = { 'WORLD_HUMAN_STAND_IMPATIENT', 'WORLD_HUMAN_STAND_MOBILE', 'WORLD_HUMAN_TOURIST_MOBILE' }
    for i, q in ipairs(A.queue or {}) do
        if math.random() < 0.8 then n = n + 1 airPed(n, q[1], q[2], q[3], QSC[(i % #QSC) + 1]) end
    end
    for i, s in ipairs(A.seats or {}) do              -- about every 3rd seat is taken
        if math.random() < 0.33 then
            n = n + 1
            local p = airPed(n, s[1], s[2], s[3])
            if p then
                local w = W(s[1], s[2], A.z[1] + 0.5)
                TaskStartScenarioAtPosition(p, 'PROP_HUMAN_SEAT_CHAIR', w.x, w.y, w.z, s[3], 0, true, true)
                OsijekPedInfo[p].scenario = nil
                OsijekPedInfo[p].frozen = true          -- stays seated while you talk
            end
        end
    end
    local SSC = { 'WORLD_HUMAN_STAND_IMPATIENT', 'WORLD_HUMAN_STAND_MOBILE', 'WORLD_HUMAN_AA_COFFEE' }
    for i, s in ipairs(A.stand or {}) do
        if math.random() < 0.7 then n = n + 1 airPed(n, s[1], s[2], s[3], SSC[(i % #SSC) + 1]) end
    end
    local W_ = A.walk or {}
    for k = 1, 10 do                                  -- walkers going from point to point
        n = n + 1
        local a = W_[math.random(#W_)]
        local p = airPed(n, a[1], a[2], 0.0)
        if p then
            CreateThread(function()
                while DoesEntityExist(p) and air.on do
                    if not (OsijekDialogOpen and OsijekDialogOpen()) or #(GetEntityCoords(p) - GetEntityCoords(PlayerPedId())) > 6.0 then
                        local b = W_[math.random(#W_)]
                        local w = W(b[1], b[2], A.z[1])
                        TaskGoStraightToCoord(p, w.x, w.y, w.z, 1.0, 30000, 0.0, 0.5)
                    end
                    Wait(math.random(9000, 20000))
                end
            end)
        end
    end
end

local function airDown()
    air.on = false
    for _, p in ipairs(air.peds) do
        OsijekExtraTalkers[p] = nil
        OsijekPedInfo[p] = nil
        if DoesEntityExist(p) then DeletePed(p) end
    end
    air.peds = {}
end

CreateThread(function()
    while true do
        local A = Life.AIRPORT
        if A and A.walk and A.walk[1] then
            local c = W(A.walk[3][1], A.walk[3][2], A.z[1])
            local d = #(GetEntityCoords(PlayerPedId()) - c)
            if d < 140.0 and not air.on then
                if groundAt(A.walk[3][1], A.walk[3][2], A.z[1]) then airUp() end
            elseif d > 190.0 and air.on then
                airDown()
            end
        end
        Wait(2000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then airDown() end
end)


-- ===================================================================== v1.0.26: police station locker room (E = uniform)
CreateThread(function()
    while true do
        local sleep = 1000
        local P = Life.POLICE
        if P and P.locker then
            local me = PlayerPedId()
            local pos = GetEntityCoords(me)
            for _, l in ipairs(P.locker) do
                local w = W(l[1], l[2], P.z[1])
                local d = #(pos - w)
                if d < 12.0 then
                    sleep = 0
                    DrawMarker(27, w.x, w.y, w.z + 0.03, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.2, 1.2, 1.0, 40, 90, 220, 160, false, false, 2, true, nil, nil, false)
                    if d < 1.4 then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName(Config.NpcLanguage == 'en' and '~INPUT_CONTEXT~ Police uniform' or '~INPUT_CONTEXT~ Policijska uniforma')
                        EndTextCommandDisplayHelp(0, false, false, -1)
                        if IsControlJustReleased(0, 38) then TriggerEvent('osrp:policeLocker') end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)
