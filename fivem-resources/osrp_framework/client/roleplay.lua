-- OSRP framework V1 - /me and /do: 3D text above the player, only for people nearby

local texts = {}   -- [serverId] = { text, kind, untill }

RegisterNetEvent('osrp:rpText', function(serverId, kind, text)
    local player = GetPlayerFromServerId(serverId)
    if player == -1 then return end
    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return end
    local dist = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(ped))
    if dist > Config.MeDistance then return end
    texts[serverId] = { text = text, kind = kind, untill = GetGameTimer() + 7000 }
    local name = GetPlayerName(player)
    local line = kind == 'me' and ('* %s %s'):format(name, text) or ('* %s (( %s ))'):format(text, name)
    TriggerEvent('chat:addMessage', { color = kind == 'me' and { 194, 120, 255 } or { 255, 190, 70 }, args = { line } })
end)

local function draw3D(x, y, z, text, r, g, b)
    local onScreen, sx, sy = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.0, 0.38)
    SetTextFont(4)
    SetTextColour(r, g, b, 235)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(sx, sy)
end

CreateThread(function()
    while true do
        local sleep = 500
        local now = GetGameTimer()
        for id, t in pairs(texts) do
            if now > t.untill then
                texts[id] = nil
            else
                local player = GetPlayerFromServerId(id)
                if player ~= -1 then
                    sleep = 0
                    local c = GetEntityCoords(GetPlayerPed(player))
                    if t.kind == 'me' then draw3D(c.x, c.y, c.z + 1.05, '* ' .. t.text .. ' *', 194, 120, 255)
                    else draw3D(c.x, c.y, c.z + 0.85, '* ' .. t.text .. ' *', 255, 190, 70) end
                end
            end
        end
        Wait(sleep)
    end
end)

CreateThread(function()
    Wait(2000)
    TriggerEvent('chat:addSuggestion', '/me', 'Radnja tvog lika', { { name = 'tekst', help = 'npr. vadi novčanik' } })
    TriggerEvent('chat:addSuggestion', '/do', 'Opis situacije', { { name = 'tekst', help = 'npr. Na stolu je ključ' } })
    TriggerEvent('chat:addSuggestion', '/daj', 'Daj gotovinu igraču', { { name = 'id' }, { name = 'iznos' } })
    TriggerEvent('chat:addSuggestion', '/novac', 'Pokaži svoj novac')
end)
