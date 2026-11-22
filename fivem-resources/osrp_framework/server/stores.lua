-- OSRP framework v1.0.36 - server: STIL clothing store + VOLT electronics + personal items
local function notify(src, msg) TriggerClientEvent('osrp:notify', src, msg) end
local function charge(src, amount)
    if amount <= 0 then return 'besplatno' end
    if OSRP.RemoveMoney(src, 'bank', amount) then return 'banke' end
    if OSRP.RemoveMoney(src, 'cash', amount) then return 'gotovine' end
    return nil
end
local CATS, ITEMS = {}, {}
for _, c in ipairs(Config.Clothes) do CATS[c.key] = c end
for _, it in ipairs(Config.TechItems) do ITEMS[it.id] = it end

local function cleanClothes(t)
    local out = {}
    if type(t) ~= 'table' then return out end
    for key in pairs(CATS) do
        local v = t[key]
        if type(v) == 'table' then
            local d, tx = math.floor(tonumber(v[1]) or 0), math.floor(tonumber(v[2]) or 0)
            if d >= -1 and d <= 999 and tx >= 0 and tx <= 99 then out[key] = { d, tx } end
        end
    end
    return out
end

RegisterNetEvent('osrp:getMyStuff', function()
    local src = source
    local p = OSRP.GetPlayer(src)
    if not p then return end
    TriggerClientEvent('osrp:myStuff', src, p.clothes or {}, p.items or {})
end)

RegisterNetEvent('osrp:buyClothes', function(wanted)
    local src = source
    local p = OSRP.GetPlayer(src)
    if not p then return end
    wanted = cleanClothes(wanted)
    local old, price = p.clothes or {}, 0
    for key, v in pairs(wanted) do
        local o = old[key]
        if not o or o[1] ~= v[1] or o[2] ~= v[2] then price = price + (CATS[key].price or 0) end
    end
    local acct = charge(src, price)
    if not acct then
        notify(src, ('~r~Nemaš dovoljno novca (~s~$%d~r~).'):format(price))
        return TriggerClientEvent('osrp:clothesResult', src, false, old)
    end
    for key, v in pairs(wanted) do old[key] = v end
    p.clothes = old
    OSRP.Save(src)
    notify(src, price > 0 and ('~g~STIL:~s~ nova odjeća plaćena ~r~$%d~s~ (s %s).'):format(price, acct) or '~g~STIL:~s~ odjeća spremljena.')
    TriggerClientEvent('osrp:clothesResult', src, true, old)
end)

RegisterNetEvent('osrp:buyTech', function(id)
    local src = source
    local p = OSRP.GetPlayer(src)
    local it = ITEMS[id]
    if not p or not it then return end
    local acct = charge(src, it.price)
    if not acct then return notify(src, ('~r~Nemaš $%d za %s.'):format(it.price, it.label)) end
    p.items = p.items or {}
    p.items[id] = (p.items[id] or 0) + 1
    OSRP.Save(src)
    notify(src, ('~b~VOLT:~s~ kupio si ~y~%s~s~ za ~r~$%d~s~ (s %s). ~y~/inventar~s~ za korištenje.'):format(it.label, it.price, acct))
    if id == 'flashlight' then TriggerClientEvent('osrp:giveFlashlight', src) end
    TriggerClientEvent('osrp:myStuff', src, p.clothes or {}, p.items)
end)

RegisterNetEvent('osrp:useItem', function(id)
    local src = source
    local p = OSRP.GetPlayer(src)
    if not p or not ITEMS[id] or not p.items or (p.items[id] or 0) < 1 then return end
    if id == 'powerbank' then                       -- used up
        p.items[id] = p.items[id] - 1
        if p.items[id] <= 0 then p.items[id] = nil end
        OSRP.Save(src)
        TriggerClientEvent('osrp:myStuff', src, p.clothes or {}, p.items)
    end
    TriggerClientEvent('osrp:itemUsed', src, id)
end)
