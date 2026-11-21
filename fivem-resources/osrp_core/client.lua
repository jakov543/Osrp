-- OSRP V1 - client
-- Renames map texts to Osijek / OSRP. The normal GTA V HUD (minimap, health, weapon wheel)
-- stays exactly as GTA V draws it - this script does not hide any HUD component.

local BRAND = 'OSRP'
local CITY = 'Osijek'

CreateThread(function()
    -- Pause menu (ESC)
    AddTextEntry('FE_THDR_GTAO', BRAND .. ' - ' .. CITY)
    AddTextEntry('PM_PANE_LEAVE', 'Napusti ' .. BRAND)
    AddTextEntry('PM_SCR_MAP', 'Karta - ' .. CITY)
    AddTextEntry('PM_SCR_GAM', BRAND)

    -- Map regions read Osijek instead of Los Santos
    AddTextEntry('LOSSANTOS', CITY)
    AddTextEntry('SANANDREAS', CITY)
    AddTextEntry('PM_LS', CITY)
end)

-- Keep GTA V HUD + radar ON
CreateThread(function()
    DisplayRadar(true)
    DisplayHud(true)
end)

AddEventHandler('playerSpawned', function()
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('Dobrodošao na ~g~' .. BRAND .. '~s~ - ' .. CITY .. ' Roleplay!')
    EndTextCommandThefeedPostTicker(false, true)
end)
