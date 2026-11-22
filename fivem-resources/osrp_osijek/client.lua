-- OSRP Osijek - spawns the Osijek city chunks (static, frozen) near the player

local spawned = {}
local missingWarned = false

local function chunkPos(c)
    return vector3(Config.Origin.x + c.x, Config.Origin.y + c.y, Config.Origin.z + c.z)
end

-- v1.0.16: nearest chunks first, all models requested in parallel (faster, no falling through the map)
local requested = {}

local function createChunk(c, hash)
    local p = chunkPos(c)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(obj, 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityLodDist(obj, 1000)
    SetModelAsNoLongerNeeded(hash)
    spawned[c.name] = obj
    requested[c.name] = nil
end

-- one streaming pass: request + create chunks within radius of (x, y), nearest first. returns loaded, total
local function streamPass(x, y, radius)
    local list = {}
    for _, c in ipairs(Layout) do
        local p = chunkPos(c)
        local d = #(vec2(p.x, p.y) - vec2(x, y))
        if d < radius then list[#list + 1] = { c = c, d = d } end
    end
    table.sort(list, function(a, b) return a.d < b.d end)
    local loaded = 0
    for _, e in ipairs(list) do
        local c = e.c
        local obj = spawned[c.name]
        if obj and DoesEntityExist(obj) then
            loaded = loaded + 1
        else
            local hash = joaat(c.name)
            if not IsModelInCdimage(hash) then
                if not missingWarned then
                    missingWarned = true
                    print('^3[OSRP Osijek]^7 Modeli nisu u stream/ mapi - pogledaj OSIJEK-MAPA-UPUTE.txt')
                end
            elseif HasModelLoaded(hash) then
                createChunk(c, hash)
                loaded = loaded + 1
            elseif not requested[c.name] or GetGameTimer() - requested[c.name] > 8000 then
                RequestModel(hash)
                requested[c.name] = GetGameTimer()
            end
        end
    end
    return loaded, #list
end

-- blocks until the city around (x, y) is loaded (used by osrp_framework while the screen is black)
function LoadArea(x, y, radius, timeout)
    local t = GetGameTimer()
    radius = radius or 350.0
    while GetGameTimer() - t < (timeout or 20000) do
        local loaded, total = streamPass(x, y, radius)
        TriggerEvent('osrp:mapLoading', loaded, total)
        if loaded >= total then
            RequestCollisionAtCoord(x, y, Config.Origin.z)
            Wait(300)
            return true
        end
        Wait(50)
    end
    return false
end
-- exports must not wait (FiveM cannot yield across resources): osrp_framework polls this instead
exports('AreaProgress', function(x, y, radius)
    local loaded, total = streamPass(x, y, radius or 350.0)
    if loaded >= total then RequestCollisionAtCoord(x, y, Config.Origin.z) end
    return loaded, total
end)

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        streamPass(pos.x, pos.y, Config.StreamDistance)
        for _, c in ipairs(Layout) do
            local obj = spawned[c.name]
            if obj and #(pos - chunkPos(c)) > Config.StreamDistance + 100.0 then
                if DoesEntityExist(obj) then DeleteObject(obj) end
                spawned[c.name] = nil
            end
        end
        Wait(250)
    end
end)

-- ---------- houses: GTA V doors, furniture, interior lights ----------
local doorObjs, furnObjs, firstValid = {}, {}, {}
OsijekFurniture = furnObjs     -- life.lua lets you sit / lie on these

local function firstModel(key, list)
    if firstValid[key] == nil then
        firstValid[key] = false
        for _, m in ipairs(list or {}) do
            if IsModelInCdimage(joaat(m)) then firstValid[key] = m break end
        end
    end
    return firstValid[key] or nil
end

local function loadModel(hash)
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) and GetGameTimer() - t < 5000 do Wait(0) end
    return HasModelLoaded(hash)
end

local function world(p) return vector3(Config.Origin.x + p.x, Config.Origin.y + p.y, Config.Origin.z + p.z) end

-- v1.0.15: doors are opened by the script (swing into the room when you walk up, close behind you).
-- GTA's door system often refuses to move doors that a script created, so we turn them ourselves.
local doorState = {}        -- i -> { closed, open, cur, away }

local function rightVec(h) local r = math.rad(h) return math.cos(r), math.sin(r) end

local function spawnDoor(i, d)
    local model = firstModel('door', Config.DoorModels)
    if not model then return end
    local hash = joaat(model)
    if not loadModel(hash) then return end
    local p = world(d)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    local mn, mx = GetModelDimensions(hash)
    local closed = d.h
    if math.abs(mn.x) > math.abs(mx.x) then closed = (closed + 180.0) % 360.0 end   -- model drawn along -X
    SetEntityHeading(obj, closed)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    -- open = turned 90 degrees into the room (away from the street)
    local sr = math.rad(d.h)
    local outX, outY = -math.sin(sr), math.cos(sr)            -- towards the street
    local open = closed + 90.0
    local ex, ey = rightVec(open)
    if ex * outX + ey * outY > 0 then open = closed - 90.0 end
    doorState[i] = { closed = closed, open = open, cur = closed, away = 0 }
    doorObjs[i] = obj
end

-- swing nearby doors
CreateThread(function()
    while true do
        local sleep = 400
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        for i, st in pairs(doorState) do
            local obj = doorObjs[i]
            if obj and DoesEntityExist(obj) then
                local op = GetEntityCoords(obj)
                local cx, cy = rightVec(st.closed)
                local mid = vector3(op.x + cx * 0.7, op.y + cy * 0.7, op.z + 1.0)
                local dist = #(pos - mid)
                if dist < 12.0 then sleep = 0 end
                local want
                if Config.DoorsLocked then want = st.closed
                elseif dist < 2.2 then st.away = 0 want = st.open
                else
                    st.away = st.away + (sleep == 0 and GetFrameTime() or 0.4)
                    want = (st.away > 2.0 and dist > 3.0) and st.closed or nil
                end
                if want and math.abs(st.cur - want) > 0.5 then
                    local step = 160.0 * GetFrameTime()
                    if sleep ~= 0 then step = 90.0 end
                    if st.cur < want then st.cur = math.min(want, st.cur + step) else st.cur = math.max(want, st.cur - step) end
                    SetEntityHeading(obj, st.cur % 360.0)
                end
            else
                doorState[i] = nil
            end
        end
        Wait(sleep)
    end
end)

-- calm sea around Osijek (big ocean waves washed over the quays)
CreateThread(function()
    local calm = false
    while true do
        local p = GetEntityCoords(PlayerPedId())
        local near = #(vec2(p.x, p.y) - vec2(Config.Origin.x, Config.Origin.y)) < 1800.0
        if near then SetDeepOceanScaler(0.0) calm = true
        elseif calm then ResetDeepOceanScaler() calm = false end
        Wait(1000)
    end
end)

local function spawnFurniture(i, f)
    -- v1.0.22: kinds "osrpprop_*" are our own Blender props (stream/osrpprop_*.ydr), they already face the right way
    local custom = f.kind:sub(1, 9) == 'osrpprop_'
    local model = custom and f.kind or firstModel('f_' .. f.kind, Config.FurnitureModels[f.kind])
    if not model then return end
    local hash = joaat(model)
    if not loadModel(hash) then return end
    local p = world(f)
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    -- GTA furniture models face -Y, the map stores where the piece should look -> turn it (Config.FurnitureTurn)
    local turn = (Config.FurnitureTurn or {})[f.kind]
    if turn == nil then turn = (model:sub(1, 9) == 'osrpprop_') and 0.0 or (Config.FurnitureTurnDefault or 180.0) end
    SetEntityHeading(obj, (f.h + turn) % 360.0)
    FreezeEntityPosition(obj, true)
    SetModelAsNoLongerNeeded(hash)
    furnObjs[i] = obj
end

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local R = Config.InteriorDistance
        for i, d in ipairs(Doors) do
            local dist = #(pos - world(d))
            if dist < R then
                if not doorObjs[i] or not DoesEntityExist(doorObjs[i]) then spawnDoor(i, d) end
            elseif doorObjs[i] and dist > R + 30.0 then
                DeleteObject(doorObjs[i]); doorObjs[i] = nil; doorState[i] = nil
            end
        end
        for i, f in ipairs(Furniture) do
            local dist = #(pos - world(f))
            local R = (f.r and f.r > 0) and f.r or Config.InteriorDistance
            if dist < R then
                if not furnObjs[i] or not DoesEntityExist(furnObjs[i]) then spawnFurniture(i, f) end
            elseif furnObjs[i] and dist > R + 30.0 then
                DeleteObject(furnObjs[i]); furnObjs[i] = nil
            end
        end
        Wait(1500)
    end
end)

-- warm light in the middle of each nearby house (rooms would be dark otherwise)
CreateThread(function()
    local rooms = {}
    for i, d in ipairs(Doors) do
        local r = math.rad(d.h)
        local fx, fy = -math.sin(r), math.cos(r)            -- towards the street
        local rx, ry = fy, -fx                              -- along the wall, away from the hinge
        rooms[i] = vector3(Config.Origin.x + d.x + rx * 0.7 - fx * 4.5,
                           Config.Origin.y + d.y + ry * 0.7 - fy * 4.5,
                           Config.Origin.z + 2.9)
    end
    while true do
        local sleep = 1000
        if Config.InteriorLight then
            local pos = GetEntityCoords(PlayerPedId())
            for _, c in ipairs(rooms) do
                if #(pos - c) < 40.0 then
                    sleep = 0
                    DrawLightWithRange(c.x, c.y, c.z, 255, 214, 160, 9.0, 1.6)
                end
            end
        end
        Wait(sleep)
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
                            -- v1.0.18: put the trunk exactly on the ground below (ray from just above, never onto a roof)
                            local ok, gz = GetGroundZFor_3dCoord(p.x, p.y, p.z + 1.5, false)
                            if ok and math.abs(gz - p.z) < 1.5 then
                                SetEntityCoordsNoOffset(o, p.x, p.y, gz - 0.1, false, false, false)
                            else
                                -- v1.0.23: ground not loaded yet -> try again in a moment instead of leaving a floating tree
                                DeleteObject(o)
                                o = nil
                            end
                            if o then FreezeEntityPosition(o, true) end
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
        for _, o in pairs(furnObjs) do if DoesEntityExist(o) then DeleteObject(o) end end
        for i, o in pairs(doorObjs) do
            local doorHash = joaat('osrp_osijek_door_' .. i)
            if IsDoorRegisteredWithSystem(doorHash) then RemoveDoorFromSystem(doorHash) end
            if DoesEntityExist(o) then DeleteObject(o) end
        end
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


-- ===================================================================== v1.0.22: automatic sliding glass doors
-- Life.SLIDEDOORS: { x, y, z, heading, panel width, model } - two panels slide apart when somebody walks up
local slide = {}
local function slidePanels(d)
    local r = math.rad(d[4])
    local rx, ry = math.cos(r), math.sin(r)
    return rx, ry
end
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local pos = GetEntityCoords(ped)
        local active = false
        for i, d in ipairs(Life.SLIDEDOORS or {}) do
            local c = world({ x = d[1], y = d[2], z = d[3] })
            local dist = #(pos - c)
            local s = slide[i]
            if dist < 80.0 then
                if not s then
                    local hash = joaat(d[6])
                    if IsModelInCdimage(hash) and loadModel(hash) then
                        s = { open = 0.0, objs = {} }
                        local rx, ry = slidePanels(d)
                        for k, sgn in ipairs({ -1, 1 }) do
                            local o = CreateObjectNoOffset(hash, c.x + rx * sgn * d[5] / 2, c.y + ry * sgn * d[5] / 2, c.z, false, false, false)
                            SetEntityHeading(o, d[4])
                            FreezeEntityPosition(o, true)
                            SetEntityCollision(o, false, false)      -- v1.0.31: the glass panels never block the way in
                            s.objs[k] = o
                        end
                        SetModelAsNoLongerNeeded(hash)
                        slide[i] = s
                    end
                end
                if s then
                    -- anybody (you, other players, NPCs) within 3.5 m opens it
                    local want = dist < 5.0
                    if not want then
                        for _, p in ipairs(GetGamePool('CPed')) do
                            if #(GetEntityCoords(p) - c) < 4.5 then want = true break end
                        end
                    end
                    local target = want and (d[5] - 0.15) or 0.0
                    if math.abs(s.open - target) > 0.01 then
                        active = true
                        s.open = s.open + math.max(-0.06, math.min(0.06, target - s.open))
                        local rx, ry = slidePanels(d)
                        for k, sgn in ipairs({ -1, 1 }) do
                            local off = sgn * (d[5] / 2 + s.open)
                            if DoesEntityExist(s.objs[k]) then
                                SetEntityCoordsNoOffset(s.objs[k], c.x + rx * off, c.y + ry * off, c.z, false, false, false)
                            end
                        end
                    end
                    if dist < 12.0 then active = true end
                end
            elseif s and dist > 100.0 then
                for _, o in ipairs(s.objs) do if DoesEntityExist(o) then DeleteObject(o) end end
                slide[i] = nil
            end
        end
        Wait(active and 0 or 500)
    end
end)


-- ===================================================================== v1.0.27 police livery (runtime texture swap)
CreateThread(function()
    local L = Config.PoliceLivery
    if not (L and L.Enabled) then return end
    local txd = CreateRuntimeTxd('osrp_livery')
    local ok = CreateRuntimeTextureFromImage(txd, 'policija_hr', L.Image)
    if not ok then return print('[osrp_osijek] livery image missing: ' .. L.Image) end
    for _, r in ipairs(L.Replace) do AddReplaceTexture(r.txd, r.tex, 'osrp_livery', 'policija_hr') end
end)

-- ===================================================================== v1.0.28 no rain inside buildings
-- Our map is made of objects, and GTA rain only stops under the real GTA map. So when you are under one of
-- our roofs (Life.INDOORS) the rain is switched off for you only, and back on when you walk out.
CreateThread(function()
    local inside = false
    while true do
        local sleep = 500
        local ped = PlayerPedId()
        local p = GetEntityCoords(ped)
        local lx, ly, lz = p.x - Config.Origin.x, p.y - Config.Origin.y, p.z - Config.Origin.z
        local now = false
        do
            for _, r in ipairs(Life.INDOORS or {}) do
                if math.abs(lx - r[1]) < r[3] / 2 and math.abs(ly - r[2]) < r[4] / 2 and lz < r[5] - 0.3 and lz > -2.0 then
                    now = true
                    break
                end
            end
        end
        if now then
            sleep = 0
            SetRainLevel(0.0)                -- every frame while inside (the weather sets it back otherwise)
            SetSnowLevel(0.0)
        elseif inside then
            SetRainLevel(-1.0)               -- -1 = back to the normal weather
            SetSnowLevel(-1.0)
        end
        inside = now
        Wait(sleep)
    end
end)


-- ===================================================================== v1.0.36: Pješački most lit up at night
-- purple light along both handrails, red light up the pylons; the colour slowly drifts purple -> magenta -> red -> blue
local BRIDGE_COLS = { { 150, 60, 255 }, { 230, 40, 200 }, { 255, 30, 60 }, { 70, 90, 255 } }
local function bridgeColour(t)
    local n = #BRIDGE_COLS
    local f = (t / 6000.0) % n
    local a, b = BRIDGE_COLS[math.floor(f) + 1], BRIDGE_COLS[(math.floor(f) + 1) % n + 1]
    local k = f - math.floor(f)
    return a[1] + (b[1] - a[1]) * k, a[2] + (b[2] - a[2]) * k, a[3] + (b[3] - a[3]) * k
end
CreateThread(function()
    while true do
        local br = Life and Life.BRIDGE
        local h = GetClockHours()
        local night = h >= 19 or h < 7
        local wait = 1500
        if br and night then
            local mid = world({ x = br.x, y = (br.y0 + br.y1) / 2, z = br.z })
            if #(GetEntityCoords(PlayerPedId()) - mid) < 450.0 then
                wait = 0
                local r, g, b = bridgeColour(GetGameTimer())
                local step = (br.y1 - br.y0) / 10
                for side = -1, 1, 2 do
                    for k = 0, 10 do
                        local p = world({ x = br.x + side * 2.2, y = br.y0 + k * step, z = br.z + 1.0 })
                        DrawLightWithRange(p.x, p.y, p.z, math.floor(r), math.floor(g), math.floor(b), 6.0, 4.0)
                    end
                    for _, py in ipairs(br.pylons) do
                        for zz = 3, 21, 6 do
                            local p = world({ x = br.x + side * 3.9, y = py, z = zz })
                            DrawLightWithRange(p.x, p.y, p.z, 255, 40, 70, 7.0, 5.0)
                        end
                    end
                end
                -- soft reflection on the Drava under the deck
                local w = world({ x = br.x, y = (br.y0 + br.y1) / 2, z = br.z - 1.5 })
                DrawLightWithRange(w.x, w.y, w.z, math.floor(r), math.floor(g), math.floor(b), 40.0, 2.0)
            end
        end
        Wait(wait)
    end
end)
