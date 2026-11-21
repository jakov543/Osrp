-- Osijek V1 - client
-- Renames map texts to Osijek. The normal GTA V HUD (minimap, health, money, weapon wheel)
-- is kept exactly as GTA V draws it - this script does not hide any HUD component.

local NAME = 'Osijek'

CreateThread(function()
    -- Pause menu (ESC) header + map tab titles
    AddTextEntry('FE_THDR_GTAO', NAME)            -- big title in the pause menu
    AddTextEntry('PM_PANE_LEAVE', 'Napusti ' .. NAME)
    AddTextEntry('PM_SCR_MAP', 'Karta - ' .. NAME)
    AddTextEntry('PM_SCR_GAM', NAME)

    -- Rename big map regions so the map reads Osijek instead of Los Santos
    AddTextEntry('LOSSANTOS', NAME)
    AddTextEntry('SANANDREAS', NAME)
    AddTextEntry('PM_LS', NAME)
end)

-- Make sure GTA V HUD + radar stay ON
CreateThread(function()
    DisplayRadar(true)
    DisplayHud(true)
end)

-- Small welcome message once the player spawns
AddEventHandler('playerSpawned', function()
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName('Dobrodošao u ~g~' .. NAME .. '~s~!')
    EndTextCommandThefeedPostTicker(false, true)
end)
