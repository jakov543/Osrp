-- OSRP framework V1 - death + respawn at hospital

local deadSince = nil

local function draw2D(text)
    SetTextFont(4)
    SetTextScale(0.0, 0.55)
    SetTextColour(255, 255, 255, 230)
    SetTextCentre(true)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(0.5, 0.82)
end

CreateThread(function()
    while true do
        local sleep = 500
        if OSRP.Spawned then
            local ped = PlayerPedId()
            if IsEntityDead(ped) then
                sleep = 0
                deadSince = deadSince or GetGameTimer()
                local left = Config.RespawnSeconds - math.floor((GetGameTimer() - deadSince) / 1000)
                if left > 0 then
                    draw2D(('Onesviješten si. Respawn za ~r~%d~s~ s'):format(left))
                else
                    draw2D('Pritisni ~g~E~s~ za bolnicu')
                    if IsControlJustReleased(0, 38) then
                        local h = Config.Hospital
                        deadSince = nil
                        OSRP.SpawnAt(h.x, h.y, h.z, h.w, OSRP.Data and OSRP.Data.sex)
                        OSRP.Notify('Probudio si se u ~b~bolnici~s~.')
                    end
                end
            else
                deadSince = nil
            end
        end
        Wait(sleep)
    end
end)

RegisterNetEvent('osrp:revive', function()
    local ped = PlayerPedId()
    local c = GetEntityCoords(ped)
    deadSince = nil
    NetworkResurrectLocalPlayer(c.x, c.y, c.z, GetEntityHeading(ped), true, false)
    SetEntityHealth(PlayerPedId(), GetEntityMaxHealth(PlayerPedId()))
    ClearPedBloodDamage(PlayerPedId())
    OSRP.Notify('~g~Oživljen si.')
end)
