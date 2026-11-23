-- OSRP framework V1 - server: 112 calls, EMS revives, hospital treatment, bills, random-event rewards

local lastCall, lastBill, lastReward, thefts = {}, {}, {}, {}

local function notify(src, msg) TriggerClientEvent('osrp:notify', src, msg) end

local function charge(src, amount)
    if OSRP.RemoveMoney(src, 'bank', amount) then return 'banke' end
    if OSRP.RemoveMoney(src, 'cash', amount) then return 'gotovine' end
    return nil
end

local function pedPos(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

RegisterNetEvent('osrp:callEms', function(x, y, z, injuredOnly)
    local src = source
    local p = OSRP.GetPlayer(src)
    if not p then return end
    if lastCall[src] and os.time() - lastCall[src] < 20 then
        return TriggerClientEvent('osrp:emsCallResult', src, 'wait')
    end
    lastCall[src] = os.time()
    local count = 0
    local name = p.firstname .. ' ' .. p.lastname
    for id, pl in pairs(OSRP.Players) do
        if id ~= src and pl.job == 'ems' and GetPlayerPing(id) > 0 then
            count = count + 1
            TriggerClientEvent('osrp:emsCall', id, src, tonumber(x) or 0.0, tonumber(y) or 0.0, tonumber(z) or 0.0, name, injuredOnly and true or false)
        end
    end
    TriggerClientEvent('osrp:emsCallResult', src, count > 0 and 'ems' or 'ai', count)
end)

RegisterNetEvent('osrp:emsRevive', function(target)
    local src = source
    local p = OSRP.GetPlayer(src)
    target = tonumber(target)
    if not p or p.job ~= 'ems' or not target or not OSRP.GetPlayer(target) then return end
    local a, b = pedPos(src), pedPos(target)
    if not a or not b or #(a - b) > 6.0 then return end
    if GetEntityHealth(GetPlayerPed(target)) > 0 then return end          -- not down
    TriggerClientEvent('osrp:revive', target)
    TriggerClientEvent('osrp:emsCallClosed', -1, target)
    OSRP.AddMoney(src, 'bank', Config.EmsReviveReward)
    notify(src, ('~g~Pacijent oživljen.~s~ +$%d'):format(Config.EmsReviveReward))
    local acct = charge(target, Config.AmbulanceBill)
    if acct then notify(target, ('Račun hitne pomoći: ~r~$%d~s~ (s %s).'):format(Config.AmbulanceBill, acct)) end
end)

-- bill after the AI ambulance helped you
RegisterNetEvent('osrp:emsBill', function()
    local src = source
    if not OSRP.GetPlayer(src) then return end
    if lastBill[src] and os.time() - lastBill[src] < 60 then return end
    lastBill[src] = os.time()
    TriggerClientEvent('osrp:emsCallClosed', -1, src)
    local acct = charge(src, Config.AmbulanceBill)
    if acct then notify(src, ('Račun hitne pomoći: ~r~$%d~s~ (s %s).'):format(Config.AmbulanceBill, acct))
    else notify(src, 'Hitna pomoć: nemaš novca, ovaj put je besplatno.') end
end)

RegisterNetEvent('osrp:hospitalHeal', function()
    local src = source
    if not OSRP.GetPlayer(src) then return end
    local pos = pedPos(src)
    if not pos or #(pos - Config.HospitalDoor) > 6.0 then return end
    local acct = charge(src, Config.HealPrice)
    if not acct then return notify(src, ('~r~Nemaš $%d~s~ za liječenje.'):format(Config.HealPrice)) end
    TriggerClientEvent('osrp:healed', src)
    notify(src, ('Plaćeno ~r~$%d~s~ (s %s).'):format(Config.HealPrice, acct))
end)

-- ---------- random events (osrp_osijek) ----------
local REWARDS = { breakdown = 75 }

RegisterNetEvent('osrp:eventReward', function(kind)
    local src = source
    local amount = REWARDS[kind]
    if not amount or not OSRP.GetPlayer(src) then return end
    lastReward[src] = lastReward[src] or {}
    if lastReward[src][kind] and os.time() - lastReward[src][kind] < 300 then return end
    lastReward[src][kind] = os.time()
    OSRP.AddMoney(src, 'cash', amount)
    notify(src, ('~g~+$%d~s~'):format(amount))
end)

RegisterNetEvent('osrp:eventThief', function()
    local src = source
    local p = OSRP.GetPlayer(src)
    if not p or (thefts[src] and os.time() - thefts[src].t < 120) then return end
    local amount = math.min(p.cash, math.random(40, 120))
    if amount > 0 and OSRP.RemoveMoney(src, 'cash', amount) then
        thefts[src] = { amount = amount, t = os.time() }
        notify(src, ('~r~-$%d~s~'):format(amount))
    else
        thefts[src] = { amount = 0, t = os.time() }
    end
end)

RegisterNetEvent('osrp:eventThiefCaught', function()
    local src = source
    local th = thefts[src]
    thefts[src] = nil
    if not th or os.time() - th.t > 120 then return end
    local back = th.amount + 50
    OSRP.AddMoney(src, 'cash', back)
    notify(src, ('~g~+$%d~s~ (novčanik + nagrada)'):format(back))
end)

AddEventHandler('playerDropped', function()
    local src = source
    lastCall[src], lastBill[src], lastReward[src], thefts[src] = nil, nil, nil, nil
end)

-- ---------- v1.0.25: NPC dialogs (osrp_osijek) - doctor/nurse treatment, beach bar ----------
local lastNpc = {}
RegisterNetEvent('osrp:npcHeal', function()
    local src = source
    if not OSRP.GetPlayer(src) then return end
    local pos = pedPos(src)
    if not pos or #(pos - Config.HospitalDoor) > 80.0 then return end          -- anywhere inside KBC Osijek
    if lastNpc[src] and os.time() - lastNpc[src] < 5 then return end
    lastNpc[src] = os.time()
    local acct = charge(src, Config.HealPrice)
    if not acct then return notify(src, ('~r~Nemaš $%d~s~ za liječenje.'):format(Config.HealPrice)) end
    TriggerClientEvent('osrp:healed', src)
    notify(src, ('Plaćeno ~r~$%d~s~ (s %s).'):format(Config.HealPrice, acct))
end)

local SHOP = { limunada = { 5, 'Limunada' }, pivo = { 6, 'Pivo' }, kava = { 3, 'Kava' }, sok = { 4, 'Sok' },
              burek = { 4, 'Burek' }, sendvic = { 5, 'Sendvič' }, pizza = { 7, 'Pizza' } }   -- v1.0.43 food
RegisterNetEvent('osrp:npcBuy', function(item)
    local src = source
    local it = SHOP[item]
    if not it or not OSRP.GetPlayer(src) then return end
    if lastNpc[src] and os.time() - lastNpc[src] < 3 then return end
    lastNpc[src] = os.time()
    local acct = charge(src, it[1])
    if not acct then return notify(src, ('~r~Nemaš $%d.'):format(it[1])) end
    TriggerClientEvent('osrp_osijek:drink', src, item)
    notify(src, ('%s: plaćeno ~r~$%d~s~ (s %s).'):format(it[2], it[1], acct))
end)
