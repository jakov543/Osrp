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
RegisterNetEvent('osrp:backToMenu', function() HUD_ON = false end)
local cutscene = false
AddEventHandler('osrp:cutscene', function(on)
    cutscene = on
    SendNUIMessage({ action = on and 'hideHud' or 'showHud' })
end)
local online = 1
RegisterNetEvent('osrp:online', function(n) online = n end)

-- hide the GTA parts we draw ourselves (cash, street/area name, vehicle name/class)
CreateThread(function()
    while true do
        if HUD_ON then
            for _, id in ipairs({ 2, 3, 4, 6, 7, 8, 9, 13, 20 }) do HideHudComponentThisFrame(id) end
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
            local radar = not IsPauseMenuActive() and not cutscene      -- osrp_osijek replaces the radar with its own drawn map in the city
            local data = {
                street = street, zone = zone or '',
                dir = direction(GetGameplayCamRot(0).z % 360),
                time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
                left = mr, bottom = mb, show = radar,
                rx = mx, ry = my, rr = mr, rb = mb,                                     -- v1.0.43: whole radar rect for the new HUD
                deg = math.floor((360.0 - GetGameplayCamRot(0).z % 360) % 360),
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


-- ---------- v1.0.16: weapon HUD ----------
local WEAPONS = {
    WEAPON_PISTOL = 'Pištolj', WEAPON_PISTOL_MK2 = 'Pištolj Mk II', WEAPON_COMBATPISTOL = 'Borbeni pištolj', WEAPON_APPISTOL = 'AP pištolj',
    WEAPON_PISTOL50 = 'Pištolj .50', WEAPON_SNSPISTOL = 'SNS pištolj', WEAPON_HEAVYPISTOL = 'Teški pištolj', WEAPON_VINTAGEPISTOL = 'Stari pištolj',
    WEAPON_REVOLVER = 'Revolver', WEAPON_STUNGUN = 'Taser', WEAPON_FLAREGUN = 'Raketni pištolj',
    WEAPON_MICROSMG = 'Micro SMG', WEAPON_SMG = 'SMG', WEAPON_ASSAULTSMG = 'Jurišni SMG', WEAPON_COMBATPDW = 'Borbeni PDW', WEAPON_MINISMG = 'Mini SMG',
    WEAPON_ASSAULTRIFLE = 'Jurišna puška', WEAPON_CARBINERIFLE = 'Karabin', WEAPON_ADVANCEDRIFLE = 'Napredna puška',
    WEAPON_SPECIALCARBINE = 'Specijalni karabin', WEAPON_BULLPUPRIFLE = 'Bullpup puška', WEAPON_COMPACTRIFLE = 'Kompaktna puška',
    WEAPON_PUMPSHOTGUN = 'Sačmarica', WEAPON_SAWNOFFSHOTGUN = 'Skraćena sačmarica', WEAPON_ASSAULTSHOTGUN = 'Jurišna sačmarica',
    WEAPON_BULLPUPSHOTGUN = 'Bullpup sačmarica', WEAPON_HEAVYSHOTGUN = 'Teška sačmarica', WEAPON_SNIPERRIFLE = 'Snajper',
    WEAPON_HEAVYSNIPER = 'Teški snajper', WEAPON_MARKSMANRIFLE = 'Precizna puška', WEAPON_MG = 'Strojnica', WEAPON_COMBATMG = 'Borbena strojnica',
    WEAPON_GUSENBERG = 'Gusenberg', WEAPON_RPG = 'RPG', WEAPON_GRENADELAUNCHER = 'Bacač granata', WEAPON_MINIGUN = 'Minigun',
    WEAPON_GRENADE = 'Granata', WEAPON_MOLOTOV = 'Molotov', WEAPON_SMOKEGRENADE = 'Dimna bomba', WEAPON_BZGAS = 'Suzavac',
    WEAPON_STICKYBOMB = 'Ljepljiva bomba', WEAPON_PETROLCAN = 'Kanister', WEAPON_FIREEXTINGUISHER = 'Aparat za gašenje',
    WEAPON_KNIFE = 'Nož', WEAPON_BAT = 'Palica', WEAPON_CROWBAR = 'Pajser', WEAPON_GOLFCLUB = 'Palica za golf', WEAPON_HAMMER = 'Čekić',
    WEAPON_NIGHTSTICK = 'Pendrek', WEAPON_FLASHLIGHT = 'Svjetiljka', WEAPON_KNUCKLE = 'Bokser', WEAPON_MACHETE = 'Mačeta',
    WEAPON_SWITCHBLADE = 'Skakavac', WEAPON_WRENCH = 'Ključ', WEAPON_HATCHET = 'Sjekira', WEAPON_BOTTLE = 'Boca', WEAPON_DAGGER = 'Bodež',
}
local NAMES = {}
for k, v in pairs(WEAPONS) do NAMES[joaat(k)] = v end

CreateThread(function()
    local last = ''
    while true do
        local wait = 400
        if HUD_ON and not cutscene then
            local ped = PlayerPedId()
            local ok, hash = GetCurrentPedWeapon(ped, true)
            local data
            if ok and hash ~= joaat('WEAPON_UNARMED') then
                wait = 120
                local melee = GetWeaponDamageType(hash) == 2 or GetWeaponClipSize(hash) <= 0
                local _, clip = GetAmmoInClip(ped, hash)
                data = { action = 'weapon', show = true, name = NAMES[hash] or 'Oružje', melee = melee,
                         clip = clip or 0, total = GetAmmoInPedWeapon(ped, hash), clipMax = GetMaxAmmoInClip(ped, hash, true) }
            else
                data = { action = 'weapon', show = false }
            end
            local key = json.encode(data)
            if key ~= last then last = key SendNUIMessage(data) end
        elseif last ~= '' then
            last = ''
            SendNUIMessage({ action = 'weapon', show = false })
        end
        Wait(wait)
    end
end)

-- ---------- v1.0.16: status (health, armour, stamina, voice, id, online, clock) ----------
CreateThread(function()
    while true do
        if HUD_ON then
            local ped = PlayerPedId()
            local maxHp = GetEntityMaxHealth(ped) - 100
            SendNUIMessage({
                action = 'status',
                hp = maxHp > 0 and (GetEntityHealth(ped) - 100) / maxHp * 100 or 0,
                ar = GetPedArmour(ped),
                st = 100 - GetPlayerSprintStaminaRemaining(PlayerId()),
                talk = NetworkIsPlayerTalking(PlayerId()),
                id = GetPlayerServerId(PlayerId()),
                online = online,
                time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes()),
            })
        end
        Wait(300)
    end
end)
