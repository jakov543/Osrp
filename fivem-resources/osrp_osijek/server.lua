-- OSRP Osijek - server: /osijek teleport (admins)
RegisterCommand('osijek', function(src)
    if src == 0 then return end
    if not IsPlayerAceAllowed(src, 'osrp.admin') then
        return TriggerClientEvent('osrp:notify', src, '~r~Nemaš dozvolu.')
    end
    TriggerClientEvent('osrp_osijek:tp', src)
end, false)

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        print('^2[OSRP]^7 osrp_osijek pokrenut - ' .. #Layout .. ' dijelova grada. Komanda: /osijek')
    end
end)

-- /dogadaj [name] - admins start a random event for themselves (test)
RegisterCommand('dogadaj', function(src, args)
    if src == 0 then return print('Use it in game: /dogadaj [hit_and_run|accident|breakdown|thief|fire|chase]') end
    if not IsPlayerAceAllowed(src, 'osrp.admin') then
        return TriggerClientEvent('osrp:notify', src, '~r~Nemaš dozvolu.')
    end
    TriggerClientEvent('osrp_osijek:testEvent', src, args[1] or '')
end, false)

-- v1.0.48: doors are opened by players (E) and everyone sees the same door state
local doorStates = {}            -- ['h12'] = true (house door 12 open), ['s3'] = true (sliding door 3 open)
RegisterNetEvent('osrp_osijek:door', function(kind, i, open)
    if (kind ~= 'h' and kind ~= 's') or type(i) ~= 'number' then return end
    local key = kind .. i
    doorStates[key] = open and true or nil
    TriggerClientEvent('osrp_osijek:doorState', -1, kind, i, open and true or false)
end)
RegisterNetEvent('osrp_osijek:doorSync', function()
    TriggerClientEvent('osrp_osijek:doorAll', source, doorStates)
end)
