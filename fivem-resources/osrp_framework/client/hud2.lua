-- OSRP framework v1.0.43 - HUD settings panel (F10 or /hud): which parts you see, size, km/h or mph. Saved in the NUI.
local open = false
local function setOpen(o)
    open = o
    SetNuiFocus(o, o)
    SendNUIMessage({ action = 'hudSettings', open = o })
end
RegisterCommand('hud', function() setOpen(not open) end, false)
RegisterKeyMapping('hud', 'HUD postavke', 'keyboard', 'F10')
RegisterNUICallback('hudSettingsClose', function(_, cb) cb({}) setOpen(false) end)
