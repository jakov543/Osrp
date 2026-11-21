-- OSRP V1 - server
SetMapName('Osijek')
SetGameType('OSRP - Osijek Roleplay')

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        print('^2[OSRP]^7 osrp_core V1 pokrenut - mapa: Osijek')
    end
end)
