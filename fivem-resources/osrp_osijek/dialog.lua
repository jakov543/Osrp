-- OSRP Osijek v1.0.25 - NPC dialog window (camera on the NPC, name, text, answer buttons)
-- Texts are in dialogs.lua, language = Config.NpcLanguage ('hr' | 'en')

local dlg = nil            -- { ped, role, node, cam, name }
local names = {}           -- ped -> generated name (same name while the ped exists)

local function L(t)
    if type(t) ~= 'table' then return t end
    if t.hr or t.en then return t[Config.NpcLanguage or 'hr'] or t.hr or t.en end
    return L(t[math.random(#t)])            -- list of variants
end

function OsijekDialogOpen() return dlg ~= nil end

local function roleOf(ped)
    local info = OsijekPedInfo and OsijekPedInfo[ped]
    if info and info.role then return info.role end
    local m = GetEntityModel(ped)
    for model, role in pairs(OsijekDialogRoles) do
        if joaat(model) == m then return role end
    end
    return 'citizen'
end

local function nameOf(ped, role)
    if names[ped] then return names[ped] end
    local N = OsijekDialogNames
    local first = IsPedMale(ped) and N.m[math.random(#N.m)] or N.f[math.random(#N.f)]
    local full = first .. ' ' .. N.last[math.random(#N.last)]
    names[ped] = { first = first, full = full }
    return names[ped]
end

local function fill(text, d)
    local fl = OsijekDialogFlights
    local h = (GetClockHours() + math.random(1, 3)) % 24
    return (text:gsub('{name}', d.name.first)
        :gsub('{flight}', fl[math.random(#fl)])
        :gsub('{time}', ('%02d:%02d'):format(h, math.random(0, 11) * 5))
        :gsub('{gate}', tostring(math.random(1, 6)))
        :gsub('{case}', ('%d/%d'):format(math.random(100, 999), 2026)))
end

local function show(nodeId)
    local D = OsijekDialogs[dlg.role] or OsijekDialogs.citizen
    local node = D.nodes[nodeId] or D.nodes.start
    dlg.node = nodeId
    local opts = {}
    local src = (node.opts and #node.opts > 0) and node.opts or D.nodes.start.opts   -- dead end -> back to the main questions
    for i, o in ipairs(src) do opts[#opts + 1] = { i = i, text = L(o.t) } end
    dlg.opts = src
    local title = L(D.title)
    local prefix = D.prefix and (L(D.prefix) .. ' ') or ''
    SendNUIMessage({ t = 'dialog', show = true, name = prefix .. dlg.name.full, role = title, text = fill(L(node.text), dlg),
                     opts = opts, bye = L(OsijekDialogBye) })
    if Config.NpcVoice ~= false and math.random() < 0.5 then
        PlayPedAmbientSpeechNative(dlg.ped, 'GENERIC_HOWS_IT_GOING', 'SPEECH_PARAMS_FORCE_NORMAL')
    end
end

local function close()
    if not dlg then return end
    local d = dlg
    dlg = nil
    SendNUIMessage({ t = 'dialog', show = false })
    SetNuiFocus(false, false)
    RenderScriptCams(false, true, 600, true, true)
    if d.cam then DestroyCam(d.cam, false) end
    FreezeEntityPosition(PlayerPedId(), false)
    if DoesEntityExist(d.ped) then
        local info = OsijekPedInfo and OsijekPedInfo[d.ped]
        if info and info.scenario then
            TaskStartScenarioInPlace(d.ped, info.scenario, 0, true)
        elseif not (info and info.frozen) then
            ClearPedTasks(d.ped)
            if d.wasScenario then TaskStartScenarioInPlace(d.ped, d.wasScenario, 0, true) end   -- walkers: the sidewalk loop gives them a new target
        end
    end
end

function OsijekOpenDialog(ped)
    if dlg or not DoesEntityExist(ped) then return end
    local me = PlayerPedId()
    local role = roleOf(ped)
    dlg = { ped = ped, role = role, name = nameOf(ped, role) }
    local info = OsijekPedInfo and OsijekPedInfo[ped]
    if not (info and info.frozen) then
        ClearPedTasks(ped)
        TaskTurnPedToFaceEntity(ped, me, -1)
    end
    TaskTurnPedToFaceEntity(me, ped, 1200)
    Wait(700)
    FreezeEntityPosition(me, true)
    -- camera over your shoulder, looking at the NPC's face
    local head = GetPedBoneCoords(ped, 31086, 0.0, 0.0, 0.0)
    local fwd = GetEntityForwardVector(ped)
    local camPos = head + fwd * 1.25 + vector3(0.0, 0.0, 0.05)
    local cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, 42.0, false, 2)
    PointCamAtCoord(cam, head.x, head.y, head.z - 0.08)
    SetCamActive(cam, true)
    RenderScriptCams(true, true, 700, true, true)
    dlg.cam = cam
    SetNuiFocus(true, true)
    show('start')
end

RegisterNUICallback('dialogPick', function(d, cb)
    cb({})
    if not dlg then return end
    local o = dlg.opts and dlg.opts[tonumber(d.i) or 0]
    if not o then return end
    if o.act == 'gps' then
        local p = OsijekDialogPlaces[o.arg]
        if p then
            SetNewWaypoint(Config.Origin.x + p[1], Config.Origin.y + p[2])
            PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
        end
    elseif o.act == 'heal' then
        TriggerServerEvent('osrp:npcHeal')
    elseif o.act == 'gun' then
        TriggerServerEvent('osrp:buyWeapon', o.arg)
    elseif o.act == 'buy' then
        TriggerServerEvent('osrp:npcBuy', o.arg)
    elseif o.act == 'id' then
        TriggerEvent('osrp:notify', Config.NpcLanguage == 'en' and 'You showed your ~b~ID card~s~.' or 'Pokazao si ~b~osobnu iskaznicu~s~.')
    elseif o.act == 'clothes' or o.act == 'tech' then         -- v1.0.36 shops (osrp_framework opens its shop window)
        close()
        return TriggerEvent(o.act == 'clothes' and 'osrp:openClothes' or 'osrp:openTechShop')
    elseif o.act == 'end' then
        return close()
    end
    show(o.go or 'start')
end)

RegisterNUICallback('dialogClose', function(_, cb) cb({}) close() end)

-- stop talking if something happens (you get hurt, the NPC dies, you walk away somehow)
CreateThread(function()
    while true do
        if dlg then
            local me = PlayerPedId()
            if not DoesEntityExist(dlg.ped) or IsPedDeadOrDying(dlg.ped, true) or IsEntityDead(me)
                or #(GetEntityCoords(me) - GetEntityCoords(dlg.ped)) > 6.0 then
                close()
            end
            Wait(300)
        else
            Wait(1000)
        end
    end
end)

-- drinks from the beach bar
RegisterNetEvent('osrp_osijek:drink', function(item)
    local ped = PlayerPedId()
    local model = (item == 'pivo') and 'prop_beer_bottle' or (item == 'kava' and 'p_amb_coffeecup_01' or 'prop_ld_flow_bottle')
    local h = joaat(model)
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) and GetGameTimer() - t < 3000 do Wait(0) end
    local obj = HasModelLoaded(h) and CreateObject(h, 0.0, 0.0, 0.0, true, true, false) or nil
    RequestAnimDict('mp_player_intdrink')
    t = GetGameTimer()
    while not HasAnimDictLoaded('mp_player_intdrink') and GetGameTimer() - t < 3000 do Wait(0) end
    if obj then AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, 18905), 0.12, 0.008, 0.03, 240.0, -60.0, 0.0, true, true, false, true, 1, true) end
    TaskPlayAnim(ped, 'mp_player_intdrink', 'loop_bottle', 8.0, -8.0, 4500, 49, 0, false, false, false)
    Wait(4500)
    if obj and DoesEntityExist(obj) then DeleteObject(obj) end
    SetEntityHealth(ped, math.min(GetEntityMaxHealth(ped), GetEntityHealth(ped) + 10))
    SetModelAsNoLongerNeeded(h)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and dlg then close() end
end)
