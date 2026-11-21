-- OSRP framework V1 - server
-- Saves player data with KVP (built into FiveM) so no database is needed for testing.

OSRP = {}
OSRP.Players = {}   -- [source] = data

local function license(src)
    for _, id in ipairs(GetPlayerIdentifiers(src)) do
        if id:sub(1, 8) == 'license:' then return id end
    end
    return nil
end

local function key(lic) return 'osrp:player:' .. lic end

local function load(lic)
    local raw = GetResourceKvpString(key(lic))
    if raw then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then return data end
    end
    return nil
end

local function save(src)
    local p = OSRP.Players[src]
    if p and p.license then
        SetResourceKvp(key(p.license), json.encode(p))
    end
end

local function syncHud(src)
    local p = OSRP.Players[src]
    if not p then return end
    local job = Config.Jobs[p.job] or Config.Jobs.unemployed
    TriggerClientEvent('osrp:hud', src, {
        name = p.firstname .. ' ' .. p.lastname,
        cash = p.cash, bank = p.bank, job = job.label
    })
end

-- ---------- public API (use from your other OSRP scripts) ----------
function OSRP.GetPlayer(src) return OSRP.Players[src] end

function OSRP.AddMoney(src, account, amount)
    local p = OSRP.Players[src]
    amount = math.floor(tonumber(amount) or 0)
    if not p or amount <= 0 or (account ~= 'cash' and account ~= 'bank') then return false end
    p[account] = p[account] + amount
    syncHud(src)
    return true
end

function OSRP.RemoveMoney(src, account, amount)
    local p = OSRP.Players[src]
    amount = math.floor(tonumber(amount) or 0)
    if not p or amount <= 0 or (account ~= 'cash' and account ~= 'bank') then return false end
    if p[account] < amount then return false end
    p[account] = p[account] - amount
    syncHud(src)
    return true
end

function OSRP.SetJob(src, job)
    local p = OSRP.Players[src]
    if not p or not Config.Jobs[job] then return false end
    p.job = job
    syncHud(src)
    save(src)
    return true
end

exports('GetPlayer', OSRP.GetPlayer)
exports('AddMoney', OSRP.AddMoney)
exports('RemoveMoney', OSRP.RemoveMoney)
exports('SetJob', OSRP.SetJob)

-- ---------- join / character ----------
RegisterNetEvent('osrp:ready', function()
    local src = source
    local lic = license(src)
    if not lic then
        DropPlayer(src, 'OSRP: Rockstar licenca nije pronađena. Pokreni igru preko OSRP launchera.')
        return
    end
    print(('^2[OSRP]^7 %s je ušao na server (%s)'):format(GetPlayerName(src), lic))
    print('^3[OSRP]^7 Za admina dodaj u server.cfg:  add_principal identifier.' .. lic .. ' group.admin')

    local data = load(lic)
    if data then
        data.license = lic
        OSRP.Players[src] = data
        TriggerClientEvent('osrp:spawn', src, data)
        syncHud(src)
    else
        TriggerClientEvent('osrp:createCharacter', src)
    end
end)

local function validName(s)
    return type(s) == 'string' and #s >= 2 and #s <= 20 and s:match("^[%a%s%-ČčĆćŽžŠšĐđ]+$") ~= nil
end

RegisterNetEvent('osrp:submitCharacter', function(c)
    local src = source
    local lic = license(src)
    if not lic or OSRP.Players[src] or type(c) ~= 'table' then return end
    if not validName(c.firstname) or not validName(c.lastname) then
        TriggerClientEvent('osrp:characterError', src, 'Ime i prezime: 2-20 slova.')
        return
    end
    if type(c.dob) ~= 'string' or not c.dob:match('^%d%d%d%d%-%d%d%-%d%d$') then
        TriggerClientEvent('osrp:characterError', src, 'Upiši datum rođenja.')
        return
    end
    local data = {
        license = lic,
        firstname = c.firstname, lastname = c.lastname,
        dob = c.dob, sex = (c.sex == 'f') and 'f' or 'm',
        cash = Config.StartCash, bank = Config.StartBank,
        job = 'unemployed', pos = nil
    }
    OSRP.Players[src] = data
    save(src)
    TriggerClientEvent('osrp:spawn', src, data)
    syncHud(src)
end)

RegisterNetEvent('osrp:savePos', function(x, y, z, h)
    local p = OSRP.Players[source]
    if p and tonumber(x) and tonumber(y) and tonumber(z) then
        p.pos = { x = x + 0.0, y = y + 0.0, z = z + 0.0, h = (tonumber(h) or 0) + 0.0 }
    end
end)

AddEventHandler('playerDropped', function()
    local src = source
    save(src)
    OSRP.Players[src] = nil
end)

-- Save everyone when the resource stops (server restart)
AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for src in pairs(OSRP.Players) do save(src) end
end)

-- ---------- payday ----------
CreateThread(function()
    while true do
        Wait(Config.PaydayMinutes * 60 * 1000)
        for src, p in pairs(OSRP.Players) do
            local job = Config.Jobs[p.job] or Config.Jobs.unemployed
            p.bank = p.bank + job.salary
            syncHud(src)
            save(src)
            TriggerClientEvent('osrp:notify', src, ('Plaća: ~g~$%d~s~ (%s)'):format(job.salary, job.label))
        end
    end
end)

OSRP.SyncHud = syncHud
OSRP.Save = save
