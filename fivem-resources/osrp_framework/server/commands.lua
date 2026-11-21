-- OSRP framework V1 - commands
-- Admin rights: in server.cfg ->  add_principal identifier.license:XXXX group.admin
--                                  add_ace group.admin osrp.admin allow

local function isAdmin(src)
    return src == 0 or IsPlayerAceAllowed(src, 'osrp.admin')
end

local function reply(src, msg)
    if src == 0 then print('[OSRP] ' .. msg)
    else TriggerClientEvent('osrp:notify', src, msg) end
end

local function target(src, arg)
    local id = tonumber(arg)
    if id and GetPlayerName(id) then return id end
    return nil
end

-- ---------- player commands ----------
RegisterCommand('me', function(src, args)
    if src == 0 or #args == 0 then return end
    TriggerClientEvent('osrp:rpText', -1, src, 'me', table.concat(args, ' '):sub(1, 120))
end, false)

RegisterCommand('do', function(src, args)
    if src == 0 or #args == 0 then return end
    TriggerClientEvent('osrp:rpText', -1, src, 'do', table.concat(args, ' '):sub(1, 120))
end, false)

RegisterCommand('novac', function(src)
    local p = OSRP.GetPlayer(src)
    if not p then return end
    reply(src, ('Gotovina: ~g~$%d~s~  Banka: ~b~$%d'):format(p.cash, p.bank))
end, false)

RegisterCommand('daj', function(src, args)  -- /daj [id] [iznos] - give cash to a player
    local to, amount = target(src, args[1]), math.floor(tonumber(args[2]) or 0)
    if src == 0 or not to or to == src or amount <= 0 then return reply(src, 'Koristi: /daj [id] [iznos]') end
    if OSRP.RemoveMoney(src, 'cash', amount) then
        OSRP.AddMoney(to, 'cash', amount)
        reply(src, ('Dao si ~g~$%d'):format(amount))
        reply(to, ('Dobio si ~g~$%d'):format(amount))
    else
        reply(src, '~r~Nemaš dovoljno gotovine.')
    end
end, false)

-- ---------- admin commands ----------
RegisterCommand('setjob', function(src, args)
    if not isAdmin(src) then return reply(src, '~r~Nemaš dozvolu.') end
    local t = target(src, args[1])
    if not t or not OSRP.SetJob(t, args[2] or '') then
        local list = {}
        for k in pairs(Config.Jobs) do list[#list + 1] = k end
        return reply(src, 'Koristi: /setjob [id] [' .. table.concat(list, '/') .. ']')
    end
    reply(src, 'Posao postavljen.')
    reply(t, 'Novi posao: ~y~' .. Config.Jobs[args[2]].label)
end, false)

RegisterCommand('givemoney', function(src, args)  -- /givemoney [id] [cash/bank] [iznos]
    if not isAdmin(src) then return reply(src, '~r~Nemaš dozvolu.') end
    local t = target(src, args[1])
    if not t or not OSRP.AddMoney(t, args[2], args[3]) then
        return reply(src, 'Koristi: /givemoney [id] [cash/bank] [iznos]')
    end
    reply(src, 'Novac dodan.')
end, false)

RegisterCommand('car', function(src, args)
    if src == 0 then return end
    if not isAdmin(src) then return reply(src, '~r~Nemaš dozvolu.') end
    TriggerClientEvent('osrp:spawnCar', src, args[1] or 'sultan')
end, false)

RegisterCommand('dv', function(src)
    if src == 0 then return end
    if not isAdmin(src) then return reply(src, '~r~Nemaš dozvolu.') end
    TriggerClientEvent('osrp:deleteCar', src)
end, false)

RegisterCommand('tpm', function(src)
    if src == 0 then return end
    if not isAdmin(src) then return reply(src, '~r~Nemaš dozvolu.') end
    TriggerClientEvent('osrp:tpm', src)
end, false)

RegisterCommand('revive', function(src, args)
    if not isAdmin(src) then return reply(src, '~r~Nemaš dozvolu.') end
    local t = target(src, args[1]) or src
    if t == 0 then return reply(src, 'Koristi: revive [id]') end
    TriggerClientEvent('osrp:revive', t)
end, false)

RegisterCommand('resetlik', function(src, args)  -- deletes a character so the player makes a new one
    if not isAdmin(src) then return reply(src, '~r~Nemaš dozvolu.') end
    local t = target(src, args[1])
    if not t then return reply(src, 'Koristi: /resetlik [id]') end
    local p = OSRP.GetPlayer(t)
    if p then
        DeleteResourceKvp('osrp:player:' .. p.license)
        OSRP.Players[t] = nil
        DropPlayer(t, 'OSRP: tvoj lik je resetiran. Uđi ponovno i napravi novog.')
    end
end, false)
