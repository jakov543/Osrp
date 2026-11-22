-- OSRP framework v1.0.36 - STIL clothing store (live preview, camera, buy), VOLT electronics shop, /inventar with item animations
-- Opened by the shop clerks in osrp_osijek (dialog -> TriggerEvent('osrp:openClothes' / 'osrp:openTechShop')).
local myClothes, myItems = {}, {}
local shopOpen, cam, before = nil, nil, nil
local heading0 = 0.0

local function parseKey(key) return key:sub(1, 1), tonumber(key:sub(2)) end

local function getPiece(ped, key)
    local kind, id = parseKey(key)
    if kind == 'c' then return { GetPedDrawableVariation(ped, id), GetPedTextureVariation(ped, id) } end
    return { GetPedPropIndex(ped, id), math.max(0, GetPedPropTextureIndex(ped, id)) }
end

local function setPiece(ped, key, d, t)
    local kind, id = parseKey(key)
    if kind == 'c' then
        SetPedComponentVariation(ped, id, math.max(0, d), t or 0, 0)
    elseif d < 0 then
        ClearPedProp(ped, id)
    else
        SetPedPropIndex(ped, id, d, t or 0, true)
    end
end

local function limits(ped, key, d)
    local kind, id = parseKey(key)
    if kind == 'c' then
        return GetNumberOfPedDrawableVariations(ped, id), math.max(1, GetNumberOfPedTextureVariations(ped, id, math.max(0, d)))
    end
    return GetNumberOfPedPropDrawableVariations(ped, id), d >= 0 and math.max(1, GetNumberOfPedPropTextureVariations(ped, id, d)) or 1
end

local function applyClothes(list)
    local ped = PlayerPedId()
    for key, v in pairs(list or {}) do setPiece(ped, key, v[1], v[2]) end
end
exports('ApplyClothes', function() applyClothes(myClothes) end)

local applyNext = false
AddEventHandler('osrp:playerSpawned', function() applyNext = true TriggerServerEvent('osrp:getMyStuff') end)
RegisterNetEvent('osrp:myStuff', function(c, it)
    myClothes, myItems = c or {}, it or {}
    if applyNext then applyNext = false applyClothes(myClothes) end
    if shopOpen == 'inv' then SendNUIMessage({ action = 'shopItems', owned = myItems }) end
end)

-- ---------------------------------------------------------------- camera around the player
local CAMS = { head = { 0.65, 0.65, 0.65 }, body = { 1.4, 0.25, 0.3 }, legs = { 1.3, -0.45, -0.45 }, feet = { 1.0, -0.8, -0.85 } }
local function setCam(which)
    local ped = PlayerPedId()
    local c = CAMS[which] or CAMS.body
    local pos = GetOffsetFromEntityInWorldCoords(ped, 0.0, c[1], c[2])
    local look = GetOffsetFromEntityInWorldCoords(ped, 0.0, 0.0, c[3])
    if not cam then
        cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
        SetCamFov(cam, 45.0)
        RenderScriptCams(true, true, 600, true, true)
    end
    SetCamCoord(cam, pos.x, pos.y, pos.z)
    PointCamAtCoord(cam, look.x, look.y, look.z)
end
local function endCam()
    if cam then RenderScriptCams(false, true, 500, true, true) DestroyCam(cam, false) cam = nil end
end

local function closeShop()
    if not shopOpen then return end
    if shopOpen == 'clothes' and before then applyClothes(before) end
    shopOpen, before = nil, nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'shopClose' })
    endCam()
    FreezeEntityPosition(PlayerPedId(), false)
end

-- ---------------------------------------------------------------- STIL clothes
AddEventHandler('osrp:openClothes', function()
    if shopOpen then return end
    local ped = PlayerPedId()
    shopOpen = 'clothes'
    heading0 = GetEntityHeading(ped)
    FreezeEntityPosition(ped, true)
    ClearPedTasksImmediately(ped)
    before = {}
    local cats = {}
    for _, c in ipairs(Config.Clothes) do
        local cur = getPiece(ped, c.key)
        before[c.key] = cur
        local md, mt = limits(ped, c.key, cur[1])
        cats[#cats + 1] = { key = c.key, label = c.label, icon = c.icon, price = c.price, cam = c.cam, d = cur[1], t = cur[2], maxD = md, maxT = mt,
                            prop = c.key:sub(1, 1) == 'p' }
    end
    setCam('body')
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'clothesOpen', cats = cats })
end)

RegisterNUICallback('clothesSet', function(d, cb)
    if shopOpen ~= 'clothes' then return cb({}) end
    local ped = PlayerPedId()
    local key, dv, tv = tostring(d.key), math.floor(tonumber(d.d) or 0), math.floor(tonumber(d.t) or 0)
    setPiece(ped, key, dv, tv)
    local md, mt = limits(ped, key, dv)
    cb({ maxD = md, maxT = mt })
end)
RegisterNUICallback('clothesCam', function(d, cb)
    cb({})
    if not shopOpen then return end
    if d.cam then setCam(d.cam) end
    if d.turn then
        local ped = PlayerPedId()
        SetEntityHeading(ped, GetEntityHeading(ped) + (tonumber(d.turn) or 0))
        setCam(d.cur or 'body')
    end
end)
RegisterNUICallback('clothesBuy', function(_, cb)
    cb({})
    if shopOpen ~= 'clothes' then return end
    local ped, wanted = PlayerPedId(), {}
    for _, c in ipairs(Config.Clothes) do wanted[c.key] = getPiece(ped, c.key) end
    TriggerServerEvent('osrp:buyClothes', wanted)
end)
RegisterNetEvent('osrp:clothesResult', function(ok, saved)
    myClothes = saved or myClothes
    if ok then before = nil end            -- keep the new look
    closeShop()
    if not ok then applyClothes(myClothes) end
end)

-- ---------------------------------------------------------------- VOLT electronics + inventory
AddEventHandler('osrp:openTechShop', function()
    if shopOpen then return end
    shopOpen = 'tech'
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'shopOpen', mode = 'tech', items = Config.TechItems, owned = myItems })
end)
RegisterCommand('inventar', function()
    if shopOpen then return closeShop() end
    shopOpen = 'inv'
    SetNuiFocus(true, true)
    TriggerServerEvent('osrp:getMyStuff')
    SendNUIMessage({ action = 'shopOpen', mode = 'inv', items = Config.TechItems, owned = myItems })
end, false)
RegisterKeyMapping('inventar', 'Moje stvari (inventar)', 'keyboard', 'F2')

RegisterNUICallback('shopBuy', function(d, cb) cb({}) TriggerServerEvent('osrp:buyTech', tostring(d.id)) end)
RegisterNUICallback('shopUse', function(d, cb) cb({}) closeShop() TriggerServerEvent('osrp:useItem', tostring(d.id)) end)
RegisterNUICallback('shopClose', function(_, cb) cb({}) closeShop() end)

RegisterNetEvent('osrp:giveFlashlight', function()
    GiveWeaponToPed(PlayerPedId(), `WEAPON_FLASHLIGHT`, 0, false, true)
end)

-- item animations (with a prop in the hand)
local USE = {
    phone = { 'cellphone@', 'cellphone_text_read_base', 'prop_npc_phone_01', 28422, 'Gledaš poruke na mobitelu.' },
    radio = { 'cellphone@', 'cellphone_call_listen_base', 'prop_cs_hand_radio', 28422, nil },
    tablet = { 'amb@code_human_in_bus_passenger_idles@female@tablet@base', 'base', 'prop_cs_tablet', 28422, 'Listaš tablet.' },
    camera = { 'amb@world_human_paparazzi@male@base', 'base', 'prop_pap_camera_01', 28422, 'Fotografiraš.' },
    headphones = { 'mp_player_int_upperheadphones', 'mp_player_int_headphones', nil, nil, 'Slušaš glazbu.' },
}
local held
local function stopUse()
    if not held then return end
    if DoesEntityExist(held.obj or 0) then DeleteObject(held.obj) end
    ClearPedTasks(PlayerPedId())
    held = nil
end
RegisterNetEvent('osrp:itemUsed', function(id)
    if id == 'powerbank' then
        TriggerEvent('osrp_osijek:buletCharge', 30.0)
        return TriggerEvent('osrp:notify', '~g~Powerbank:~s~ mobitel napunjen (i BULET +30% ako se voziš).')
    end
    if id == 'flashlight' then
        GiveWeaponToPed(PlayerPedId(), `WEAPON_FLASHLIGHT`, 0, false, true)
        return
    end
    local u = USE[id]
    if not u then return end
    stopUse()
    local ped = PlayerPedId()
    RequestAnimDict(u[1])
    local t = GetGameTimer()
    while not HasAnimDictLoaded(u[1]) and GetGameTimer() - t < 2000 do Wait(0) end
    TaskPlayAnim(ped, u[1], u[2], 4.0, -4.0, -1, 49, 0, false, false, false)
    held = { id = id }
    if u[3] then
        local h = joaat(u[3])
        RequestModel(h)
        while not HasModelLoaded(h) and GetGameTimer() - t < 3000 do Wait(0) end
        local c = GetEntityCoords(ped)
        held.obj = CreateObject(h, c.x, c.y, c.z, true, true, false)
        AttachEntityToEntity(held.obj, ped, GetPedBoneIndex(ped, u[4]), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        SetModelAsNoLongerNeeded(h)
    end
    if id == 'radio' then
        if GetResourceState('pma-voice') == 'started' then
            pcall(function() exports['pma-voice']:setRadioChannel(Config.RadioChannel) end)
            TriggerEvent('osrp:notify', ('~b~Radio:~s~ kanal %d. ~y~X~s~ = spremi radio.'):format(Config.RadioChannel))
        else
            TriggerEvent('osrp:notify', '~b~Radio:~s~ upaljen. ~y~X~s~ = spremi radio.')
        end
    elseif u[5] then
        TriggerEvent('osrp:notify', u[5] .. ' ~y~X~s~ = spremi.')
    end
end)
CreateThread(function()
    while true do
        if held then
            if IsControlJustReleased(0, 73) or IsPedRagdoll(PlayerPedId()) or IsPedInAnyVehicle(PlayerPedId(), false) then stopUse() end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    stopUse()
    if shopOpen then closeShop() end
end)
