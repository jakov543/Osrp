-- OSRP framework V1 - HUD: location next to the minimap, speedometer, hides GTA HUD parts we replace
local HUD_ON = false
local last = {}

local function send(action, data)
    data.action = action
    SendNUIMessage(data)
end

-- where the GTA minimap is on screen (fractions 0..1), so the location box sits right next to it on every resolution
local function minimapAnchor()
    SetScriptGfxAlign(string.byte('L'), string.byte('B'))
    -- default GTA minimap frame: posX -0.0045, posY 0.002, size 0.150 x 0.188888 (aligned left/bottom)
    local x, y = GetScriptGfxPosition(-0.0045, 0.002 - 0.188888)
    local r, b = GetScriptGfxPosition(-0.0045 + 0.150, 0.002)
    ResetScriptGfxAlign()
    return x, y, r, b
end

local DIRS = { 'S', 'SZ', 'Z', 'JZ', 'J', 'JI', 'I', 'SI' }   -- sjever, zapad, jug, istok (GTA heading turns left)
local function direction(h)
    return DIRS[math.floor(((h + 22.5) % 360) / 45) + 1]
end

local function location(c)
    if GetResourceState('osrp_osijek') == 'started' then
        local ok, street, zone = pcall(function() return exports.osrp_osijek:GetLocation(c.x, c.y) end)
        if ok and street then return street, zone end
    end
    local s1, s2 = GetStreetNameAtCoord(c.x, c.y, c.z)
    local street = GetStreetNameFromHashKey(s1)
    if s2 ~= 0 then street = street .. ' / ' .. GetStreetNameFromHashKey(s2) end
    return street ~= '' and street or 'Nepoznato', GetLabelText(GetNameOfZone(c.x, c.y, c.z))
end

AddEventHandler('osrp:playerSpawned', function() HUD_ON = true end)

-- hide the GTA parts we draw ourselves (cash, street/area name, vehicle name/class)
CreateThread(function()
    while true do
        if HUD_ON then
            for _, id in ipairs({ 3, 4, 6, 7, 8, 9, 13 }) do HideHudComponentThisFrame(id) end
            Wait(0)
        else
            Wait(500)
        end
    end
end)

-- location + clock
CreateThread(function()
    while true do
        if HUD_ON then
            local ped = PlayerPedId()
            local c = GetEntityCoords(ped)
            local street, zone = location(c)
            local mx, my, mr, mb = minimapAnchor()
            local radar = not IsPauseMenuActive()      -- osrp_osijek replaces the radar with its own drawn map in the city
            local data = {
                street = street, zone = zone or '',
                dir = direction(GetGameplayCamRot(0).z % 360),
                time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
                left = mr, bottom = mb, show = radar,
            }
            local key = json.encode(data)
            if key ~= last.loc then last.loc = key send('loc', data) end
        end
        Wait(250)
    end
end)

-- speedometer
CreateThread(function()
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        if HUD_ON and veh ~= 0 then
            local tank = GetVehicleHandlingFloat(veh, 'CHandlingData', 'fPetrolTankVolume')
            local fuel = tank > 0 and (GetVehicleFuelLevel(veh) / tank) or 1.0
            send('veh', {
                show = not IsPauseMenuActive(),
                speed = math.floor(GetEntitySpeed(veh) * 3.6 + 0.5),
                rpm = GetIsVehicleEngineRunning(veh) and GetVehicleCurrentRpm(veh) or 0.0,
                gear = GetVehicleCurrentGear(veh),
                fuel = math.max(0.0, math.min(1.0, fuel)),
                engine = math.max(0.0, GetVehicleEngineHealth(veh) / 1000.0),
                lights = select(2, GetVehicleLightsState(veh)) == 1 or select(3, GetVehicleLightsState(veh)) == 1,
                reverse = GetEntitySpeedVector(veh, true).y < -0.5,
            })
            last.inVeh = true
            Wait(80)
        else
            if last.inVeh then send('veh', { show = false }) last.inVeh = false end
            Wait(400)
        end
    end
end)
