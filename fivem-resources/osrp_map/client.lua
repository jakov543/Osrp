-- OSRP map builder V1 - client: spawns saved props near the player + admin build commands
--
--  /prop [ime]                         postavi prop ispred sebe (npr. /prop lampa, /prop drvo, /prop prop_bench_09)
--  /proplinija [ime] [broj] [razmak] [2]   red propova ispred sebe (2 = obje strane), npr. /proplinija lampa 10 25 2
--  /propobrisi                         obriši najbliži postavljeni prop (do 5 m)
--  /propundo                           obriši zadnji postavljeni prop
--  /propovi                            popis kratkih imena
--  /predlozak [ulica|trg|park|promenada] [a] [b]   cijelo uređeno područje odjednom (stani na sredinu ceste/trga, gledaj naprijed)

local props = {}      -- [id] = data
local spawned = {}    -- [id] = entity

local function msg(text)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandThefeedPostTicker(false, true)
end
RegisterNetEvent('osrp_map:msg', msg)

local function resolveModel(name)
    local preset = Config.Presets[name]
    if preset then return preset[math.random(#preset)] end
    return name
end

local function loadModel(hash)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return false end
    RequestModel(hash)
    local t = GetGameTimer()
    while not HasModelLoaded(hash) do
        if GetGameTimer() - t > 5000 then return false end
        Wait(0)
    end
    return true
end

local function despawn(id)
    local e = spawned[id]
    if e and DoesEntityExist(e) then DeleteObject(e) end
    spawned[id] = nil
end

local function spawn(p)
    local hash = joaat(p.model)
    if not loadModel(hash) then return end
    local obj = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(obj, p.h or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityLodDist(obj, 500)
    SetModelAsNoLongerNeeded(hash)
    if not props[p.id] then DeleteObject(obj) return end   -- deleted while the model was loading
    spawned[p.id] = obj
end

-- ---------- sync from server ----------
RegisterNetEvent('osrp_map:all', function(list)
    for id in pairs(spawned) do despawn(id) end
    props = {}
    for _, p in ipairs(list) do props[p.id] = p end
end)

RegisterNetEvent('osrp_map:added', function(list)
    for _, p in ipairs(list) do props[p.id] = p end
end)

RegisterNetEvent('osrp_map:removed', function(id)
    props[id] = nil
    despawn(id)
end)

CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(500) end
    TriggerServerEvent('osrp_map:request')
end)

-- ---------- streaming: only props near the player exist ----------
CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        local list = {}
        for id, p in pairs(props) do list[#list + 1] = { id, p } end   -- copy: props can change while we load models
        for _, item in ipairs(list) do
            local id, p = item[1], item[2]
            local d = #(pos - vector3(p.x, p.y, p.z))
            if d < Config.StreamDistance then
                if props[id] and (not spawned[id] or not DoesEntityExist(spawned[id])) then spawn(p) end
            elseif spawned[id] and d > Config.StreamDistance + 30.0 then
                despawn(id)
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for id in pairs(spawned) do despawn(id) end
end)

-- ---------- placing helpers ----------
local function groundZ(x, y, zHint)
    for _, start in ipairs({ zHint + 5.0, zHint + 30.0, 1000.0 }) do
        local ok, z = GetGroundZFor_3dCoord(x, y, start, false)
        if ok then return z end
    end
    return zHint - 1.0
end

local function forwardPoint(dist)
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local r = math.rad(h)
    return c.x - math.sin(r) * dist, c.y + math.cos(r) * dist, c.z, h
end

-- ---------- commands (server checks admin) ----------
RegisterCommand('prop', function(_, args)
    local name = args[1]
    if not name then return msg('Koristi: /prop [lampa/drvo/bor/grm/klupa/kanta ili ime GTA propa]') end
    local model = resolveModel(name)
    if not IsModelInCdimage(joaat(model)) then return msg('~r~Prop ne postoji: ' .. model) end
    local x, y, z, h = forwardPoint(2.5)
    TriggerServerEvent('osrp_map:add', { { model = model, x = x, y = y, z = groundZ(x, y, z), h = h } })
end, false)

RegisterCommand('proplinija', function(_, args)
    local name, count, spacing, sides = args[1], tonumber(args[2]) or 5, tonumber(args[3]) or 20.0, tonumber(args[4]) or 1
    if not name then return msg('Koristi: /proplinija [ime] [broj] [razmak m] [1 ili 2 strane]') end
    count = math.max(1, math.min(count, 50))
    spacing = math.max(2.0, math.min(spacing, 100.0))
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local r = math.rad(h)
    local fx, fy = -math.sin(r), math.cos(r)        -- forward
    local rx, ry = fy, -fx                           -- right
    local list = {}
    for i = 1, count do
        local bx, by = c.x + fx * spacing * (i - 1), c.y + fy * spacing * (i - 1)
        local offsets = sides == 2 and { -Config.SideOffset, Config.SideOffset } or { 0.0 }
        for _, off in ipairs(offsets) do
            local model = resolveModel(name)
            if IsModelInCdimage(joaat(model)) then
                local x, y = bx + rx * off, by + ry * off
                -- lights on both sides face the middle of the road
                local heading = h
                if sides == 2 then heading = off < 0 and h - 90.0 or h + 90.0 end
                list[#list + 1] = { model = model, x = x, y = y, z = groundZ(x, y, c.z), h = heading }
            end
        end
    end
    if #list == 0 then return msg('~r~Prop ne postoji: ' .. name) end
    TriggerServerEvent('osrp_map:add', list)
end, false)

-- ---------- templates: whole dressed areas in one command ----------
local function sendBatched(list)
    if #list == 0 then return msg('~r~Ništa nije postavljeno (propovi ne postoje?).') end
    CreateThread(function()
        for i = 1, #list, 150 do
            local chunk = {}
            for j = i, math.min(i + 149, #list) do chunk[#chunk + 1] = list[j] end
            TriggerServerEvent('osrp_map:add', chunk)
            Wait(500)
        end
    end)
end

local function builder()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    local h = GetEntityHeading(ped)
    local r = math.rad(h)
    local fx, fy = -math.sin(r), math.cos(r)
    local rx, ry = fy, -fx
    local list = {}
    local b = {}
    -- put a preset at (forward f, right s) from the player; heading relative to player heading
    function b.put(name, f, s, relH)
        local model = resolveModel(name)
        if not IsModelInCdimage(joaat(model)) then
            if name == 'fontana' then model = resolveModel('drvo') else return end
        end
        local x, y = c.x + fx * f + rx * s, c.y + fy * f + ry * s
        list[#list + 1] = { model = model, x = x, y = y, z = groundZ(x, y, c.z), h = (h + (relH or 0.0)) % 360.0 }
    end
    b.list = list
    b.c = c
    return b
end

local Templates = {}

-- Street: you stand in the MIDDLE of the road looking along it
function Templates.ulica(len, width)
    len = math.min(tonumber(len) or Config.Templates.ulica.length, 300)
    width = math.min(tonumber(width) or Config.Templates.ulica.width, 40)
    local b = builder()
    local edge = width / 2
    for d = 0, len, 25 do
        b.put('lampa', d, -(edge + 1.2), 90.0)            -- lamps face the road
        b.put('lampa', d + 12.5, edge + 1.2, -90.0)
        b.put('drvo', d + 6, -(edge + 3.5))
        b.put('drvo', d + 18.5, edge + 3.5)
        b.put('stup', d + 3, -(edge + 0.6)); b.put('stup', d + 9, -(edge + 0.6))
        b.put('stup', d + 15.5, edge + 0.6); b.put('stup', d + 21.5, edge + 0.6)
        if d % 50 == 0 then
            b.put('klupa', d + 10, -(edge + 4.5), 90.0)
            b.put('kanta', d + 13, -(edge + 2.0))
            b.put('klupa', d + 35, edge + 4.5, -90.0)
            b.put('kanta', d + 38, edge + 2.0)
        end
    end
    b.put('hidrant', len / 2, -(edge + 1.0))
    b.put('posta', len / 3, edge + 2.0)
    return b.list
end

-- Square: you stand in the CENTER
function Templates.trg(radius)
    radius = math.min(tonumber(radius) or Config.Templates.trg.radius, 60)
    local b = builder()
    b.put('fontana', 0, 0)
    for k = 0, 7 do
        local a = k / 8 * 2 * math.pi
        local deg = math.deg(a)
        b.put('drvo', math.cos(a) * radius, math.sin(a) * radius)
        local a2 = a + math.pi / 8
        b.put('klupa', math.cos(a2) * (radius - 4), math.sin(a2) * (radius - 4), math.deg(a2) + 90.0)  -- benches face the center
        if k % 2 == 0 then b.put('lampa', math.cos(a2) * (radius + 3), math.sin(a2) * (radius + 3), deg + 180.0) end
        if k % 4 == 1 then b.put('kanta', math.cos(a) * (radius - 6), math.sin(a) * (radius - 6)) end
    end
    for k = 0, 11 do
        local a = k / 12 * 2 * math.pi
        b.put('grm', math.cos(a) * (radius + 6), math.sin(a) * (radius + 6))
    end
    return b.list
end

-- Park: you stand at the START of the middle path, looking into the park
function Templates.park(width, len)
    width = math.min(tonumber(width) or Config.Templates.park.width, 120)
    len = math.min(tonumber(len) or Config.Templates.park.length, 200)
    local b = builder()
    for f = 0, len, 20 do
        b.put('lampa', f, 2.5, -90.0)
        b.put('klupa', f + 10, -2.5, 90.0)
        if f % 40 == 0 then b.put('kanta', f + 12, -2.5) end
    end
    for f = 6, len, 11 do
        for s = 7, width / 2, 10 do
            b.put('drvo', f + math.random(-3, 3), s + math.random(-2, 2))
            b.put('drvo', f + math.random(-3, 3), -s + math.random(-2, 2))
        end
        b.put('grm', f + 5, width / 2 + 1)
        b.put('grm', f + 5, -(width / 2 + 1))
    end
    return b.list
end

-- Promenade: you walk along it, props go on your LEFT (e.g. river on your right)
function Templates.promenada(len)
    len = math.min(tonumber(len) or Config.Templates.promenada.length, 300)
    local b = builder()
    for d = 0, len, 20 do
        b.put('lampa', d, -1.5, 90.0)
        b.put('drvo', d + 10, -5.0)
        b.put('klupa', d + 5, -3.0, 90.0)
        if d % 60 == 0 then b.put('kanta', d + 8, -2.0) end
    end
    return b.list
end

RegisterCommand('predlozak', function(_, args)
    local t = Templates[args[1] or '']
    if not t then return msg('Koristi: /predlozak ~y~ulica~s~ [dužina] [širina] | ~y~trg~s~ [radijus] | ~y~park~s~ [širina] [dužina] | ~y~promenada~s~ [dužina]') end
    local list = t(args[2], args[3])
    msg(('Gradim ~g~%s~s~: %d propova...'):format(args[1], #list))
    sendBatched(list)
end, false)

RegisterCommand('propobrisi', function()
    local pos = GetEntityCoords(PlayerPedId())
    local best, bestD = nil, 5.0
    for id, p in pairs(props) do
        local d = #(pos - vector3(p.x, p.y, p.z))
        if d < bestD then best, bestD = id, d end
    end
    if not best then return msg('Nema propa u blizini (5 m).') end
    TriggerServerEvent('osrp_map:remove', best)
end, false)

RegisterCommand('propundo', function() TriggerServerEvent('osrp_map:undo') end, false)

RegisterCommand('propovi', function()
    local names = {}
    for k in pairs(Config.Presets) do names[#names + 1] = k end
    table.sort(names)
    msg('Propovi: ~y~' .. table.concat(names, ', '))
end, false)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/prop', 'Postavi GTA prop ispred sebe (admin)', { { name = 'ime', help = 'lampa, drvo, bor, grm, klupa, kanta ili ime propa' } })
    TriggerEvent('chat:addSuggestion', '/proplinija', 'Red propova - npr. ulica s lampama (admin)', {
        { name = 'ime' }, { name = 'broj', help = 'koliko (max 50)' }, { name = 'razmak', help = 'metara između' }, { name = 'strane', help = '1 ili 2' } })
    TriggerEvent('chat:addSuggestion', '/propobrisi', 'Obriši najbliži prop (admin)')
    TriggerEvent('chat:addSuggestion', '/propundo', 'Obriši zadnji prop (admin)')
    TriggerEvent('chat:addSuggestion', '/propovi', 'Popis kratkih imena propova')
    TriggerEvent('chat:addSuggestion', '/predlozak', 'Izgradi cijelo područje (admin)', {
        { name = 'vrsta', help = 'ulica (stani na sredinu ceste) / trg (stani u centar) / park / promenada' },
        { name = 'a', help = 'ulica: dužina | trg: radijus | park: širina | promenada: dužina' },
        { name = 'b', help = 'ulica: širina ceste | park: dužina' } })
end)
