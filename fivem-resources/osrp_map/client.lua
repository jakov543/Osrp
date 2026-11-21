-- OSRP map builder V1 - client: spawns saved props near the player + admin build commands
--
--  /prop [ime]                         postavi prop ispred sebe (npr. /prop lampa, /prop drvo, /prop prop_bench_09)
--  /proplinija [ime] [broj] [razmak] [2]   red propova ispred sebe (2 = obje strane), npr. /proplinija lampa 10 25 2
--  /propobrisi                         obriši najbliži postavljeni prop (do 5 m)
--  /propundo                           obriši zadnji postavljeni prop
--  /propovi                            popis kratkih imena

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
end)
