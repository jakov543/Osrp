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
