-- Osijek V1 - server
-- Shows "Osijek" as map name in the FiveM server list
SetMapName('Osijek')
SetGameType('Osijek Roleplay')

AddEventHandler('onResourceStart', function(res)
    if res == GetCurrentResourceName() then
        print('^2[osijek_core]^7 V1 pokrenut - mapa: Osijek')
    end
end)
