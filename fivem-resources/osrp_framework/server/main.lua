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

-- v1.0.16 multicharacter: all characters of a license in one KVP list (old single character is moved in)
local function charsKey(lic) return 'osrp:chars:' .. lic end

local function loadChars(lic)
    local list = {}
    local raw = GetResourceKvpString(charsKey(lic))
    if raw then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then list = data end
    end
    if #list == 0 then
        local old = load(lic)
        if old then
            old.cid = 1
            list[1] = old
            SetResourceKvp(charsKey(lic), json.encode(list))
            DeleteResourceKvp(key(lic))
        end
    end
    return list
end

local function saveChars(lic, list) SetResourceKvp(charsKey(lic), json.encode(list)) end

local function save(src)
    local p = OSRP.Players[src]
    if not p or not p.license then return end
    local list = loadChars(p.license)
    local found = false
    for i, c in ipairs(list) do
        if c.cid == p.cid then list[i] = p found = true break end
    end
    if not found then list[#list + 1] = p end
    saveChars(p.license, list)
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
    TriggerClientEvent('osrp:job', src, job)
    syncHud(src)
    save(src)
    return true
end

exports('GetPlayer', OSRP.GetPlayer)
exports('AddMoney', OSRP.AddMoney)
exports('RemoveMoney', OSRP.RemoveMoney)
exports('SetJob', OSRP.SetJob)

-- ---------- join / characters ----------
local function summary(c)
    local job = Config.Jobs[c.job] or Config.Jobs.unemployed
    return {
        cid = c.cid, firstname = c.firstname, lastname = c.lastname, dob = c.dob, sex = c.sex,
        height = c.height, nationality = c.nationality, appearance = c.appearance,
        job = job.label, cash = c.cash, bank = c.bank, hasPos = c.pos ~= nil,
    }
end

local function sendChars(src)
    local lic = license(src)
    if not lic then return end
    local out = {}
    for _, c in ipairs(loadChars(lic)) do out[#out + 1] = summary(c) end
    TriggerClientEvent('osrp:chars', src, out, Config.MaxCharacters)
end

RegisterNetEvent('osrp:ready', function()
    local src = source
    local lic = license(src)
    if not lic then
        DropPlayer(src, 'OSRP: Rockstar licenca nije pronađena. Pokreni igru preko OSRP launchera.')
        return
    end
    print(('^2[OSRP]^7 %s je ušao na server (%s)'):format(GetPlayerName(src), lic))
    print('^3[OSRP]^7 Za admina dodaj u server.cfg:  add_principal identifier.' .. lic .. ' group.admin')
    if OSRP.Players[src] then save(src) OSRP.Players[src] = nil end
    sendChars(src)
end)

RegisterNetEvent('osrp:selectChar', function(cid)
    local src = source
    local lic = license(src)
    if not lic or OSRP.Players[src] then return end
    for _, c in ipairs(loadChars(lic)) do
        if c.cid == tonumber(cid) then
            c.license = lic
            OSRP.Players[src] = c
            TriggerClientEvent('osrp:spawnSelect', src, c)
            syncHud(src)
            return
        end
    end
end)

local function validName(s)
    return type(s) == 'string' and #s >= 2 and #s <= 20 and s:match("^[%a%s%-ČčĆćŽžŠšĐđ]+$") ~= nil
end

local NATIONS = { Hrvatska = true, ['Bosna i Hercegovina'] = true, Srbija = true, Slovenija = true, ['Crna Gora'] = true,
                  ['Mađarska'] = true, Austrija = true, ['Njemačka'] = true, Italija = true, Ostalo = true }

RegisterNetEvent('osrp:createChar', function(c)
    local src = source
    local lic = license(src)
    if not lic or OSRP.Players[src] or type(c) ~= 'table' then return end
    local list = loadChars(lic)
    if #list >= Config.MaxCharacters then
        return TriggerClientEvent('osrp:characterError', src, ('Možeš imati najviše %d lika.'):format(Config.MaxCharacters))
    end
    if not validName(c.firstname) or not validName(c.lastname) then
        return TriggerClientEvent('osrp:characterError', src, 'Ime i prezime: 2-20 slova.')
    end
    if type(c.dob) ~= 'string' or not c.dob:match('^%d%d%d%d%-%d%d%-%d%d$') then
        return TriggerClientEvent('osrp:characterError', src, 'Upiši datum rođenja.')
    end
    local height = math.floor(tonumber(c.height) or 180)
    if height < 150 or height > 210 then height = 180 end
    local ap = type(c.appearance) == 'table' and c.appearance or {}
    local function clampInt(v, lo, hi) v = math.floor(tonumber(v) or lo) return math.max(lo, math.min(hi, v)) end
    local cid = 0
    for _, x in ipairs(list) do cid = math.max(cid, tonumber(x.cid) or 0) end
    local data = {
        cid = cid + 1, license = lic,
        firstname = c.firstname, lastname = c.lastname, dob = c.dob, sex = (c.sex == 'f') and 'f' or 'm',
        height = height, nationality = NATIONS[c.nationality] and c.nationality or 'Hrvatska',
        appearance = { face = clampInt(ap.face, 0, 45), skin = clampInt(ap.skin, 0, 45), hair = clampInt(ap.hair, 0, 70),
                       hairColor = clampInt(ap.hairColor, 0, 63), outfit = clampInt(ap.outfit, 1, 4) },
        cash = Config.StartCash, bank = Config.StartBank, job = 'unemployed', pos = nil,
    }
    list[#list + 1] = data
    saveChars(lic, list)
    OSRP.Players[src] = data
    TriggerClientEvent('osrp:spawn', src, data, { arrival = true })
    syncHud(src)
end)

RegisterNetEvent('osrp:deleteChar', function(cid)
    local src = source
    local lic = license(src)
    if not lic or OSRP.Players[src] then return end
    local list, out = loadChars(lic), {}
    for _, c in ipairs(list) do if c.cid ~= tonumber(cid) then out[#out + 1] = c end end
    saveChars(lic, out)
    sendChars(src)
end)

-- /odjava - back to the character selection
RegisterCommand('odjava', function(src)
    if src == 0 or not OSRP.Players[src] then return end
    save(src)
    OSRP.Players[src] = nil
    TriggerClientEvent('osrp:backToMenu', src)
end, false)

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
function OSRP.DeleteCharacter(lic, cid)
    local list, out = loadChars(lic), {}
    for _, c in ipairs(list) do if c.cid ~= cid then out[#out + 1] = c end end
    saveChars(lic, out)
end

-- players online for the HUD
CreateThread(function()
    while true do
        TriggerClientEvent('osrp:online', -1, #GetPlayers())
        Wait(15000)
    end
end)
