-- OSRP Osijek v1.0.46 - sirens for police / ambulance / fire (every emergency vehicle, GTA class 18)
--   Q  = blue lights on/off (no sound)          E = siren on/off
--   R  = change the tone                         H = air horn (hold)
--   (keys can be changed in GTA Settings -> Key Bindings -> FiveM)
-- Tones: HR dvotonac (Croatian two-tone, played by the NUI), Wail, Yelp, Priority (GTA sounds).
-- Everyone around hears and sees it: the state is synced on the vehicle (state bag), every client plays the sound itself.
-- NPC police cars / ambulances on a call (traffic) use the same system.

local S = Config.Sirens or {}
local TONES = S.Tones or {
    { id = 'hr', label = 'HR dvotonac' },
    { id = 'wail', label = 'Wail', sound = 'VEHICLES_HORNS_SIREN_1' },
    { id = 'yelp', label = 'Yelp', sound = 'VEHICLES_HORNS_SIREN_2' },
    { id = 'prio', label = 'Priority', sound = 'VEHICLES_HORNS_POLICE_WARNING' },
}
local HORN = 'SIRENS_AIRHORN'

local mine = { l = false, s = false, t = 1, h = false }
local sounds = {}          -- [veh] = { id = soundId, tone = n }   GTA siren sound per vehicle
local horns = {}           -- [veh] = soundId

local function isEmergency(veh)
    return veh ~= 0 and GetVehicleClass(veh) == 18
end

local function myVeh()
    local ped = PlayerPedId()
    local veh = GetVehiclePedIsIn(ped, false)
    if isEmergency(veh) and GetPedInVehicleSeat(veh, -1) == ped then return veh end
    return nil
end

local function notify(txt)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(txt)
    EndTextCommandThefeedPostTicker(false, false)
end

local function push(veh)
    if NetworkGetEntityIsNetworked(veh) then
        Entity(veh).state:set('osrpSir', { l = mine.l, s = mine.s, t = mine.t, h = mine.h }, true)
    end
    OsrpLocalSir = OsrpLocalSir or {}
    OsrpLocalSir[veh] = { l = mine.l, s = mine.s, t = mine.t, h = mine.h }
end

local function stateOf(veh)
    if OsrpLocalSir and OsrpLocalSir[veh] then return OsrpLocalSir[veh] end
    if OsrpNpcSiren and OsrpNpcSiren[veh] then return { l = true, s = true, t = 1, h = false } end
    if NetworkGetEntityIsNetworked(veh) then return Entity(veh).state.osrpSir end
    return nil
end

-- ---------------------------------------------------------------- keys
RegisterCommand('osrp_svjetla', function()
    local veh = myVeh() if not veh then return end
    mine.l = not mine.l
    if not mine.l then mine.s = false end
    push(veh)
    PlaySoundFrontend(-1, 'NAV_UP_DOWN', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
end, false)

RegisterCommand('osrp_sirena', function()
    local veh = myVeh() if not veh then return end
    mine.s = not mine.s
    if mine.s then mine.l = true end
    push(veh)
end, false)

RegisterCommand('osrp_ton', function()
    local veh = myVeh() if not veh then return end
    mine.t = mine.t % #TONES + 1
    push(veh)
    notify(('Sirena: ~b~%s'):format(TONES[mine.t].label))
end, false)

RegisterCommand('+osrp_truba', function()
    local veh = myVeh() if not veh then return end
    mine.h = true push(veh)
end, false)
RegisterCommand('-osrp_truba', function()
    local veh = myVeh() if not veh then mine.h = false return end
    mine.h = false push(veh)
end, false)

RegisterKeyMapping('osrp_svjetla', 'OSRP: rotirka (svjetla)', 'keyboard', S.KeyLights or 'Q')
RegisterKeyMapping('osrp_sirena', 'OSRP: sirena', 'keyboard', S.KeySiren or 'E')
RegisterKeyMapping('osrp_ton', 'OSRP: promijeni ton sirene', 'keyboard', S.KeyTone or 'R')
RegisterKeyMapping('+osrp_truba', 'OSRP: truba (zračna)', 'keyboard', S.KeyHorn or 'H')

-- in your emergency vehicle: GTA's own siren / radio wheel / cinematic cam keys are off (Q, E, R are ours)
CreateThread(function()
    local was = nil
    while true do
        local veh = myVeh()
        if veh then
            DisableControlAction(0, 86, true)     -- E horn / GTA siren
            DisableControlAction(0, 85, true)     -- Q radio wheel
            DisableControlAction(0, 80, true)     -- R cinematic cam
            if was ~= veh then
                was = veh
                local st = stateOf(veh)
                if st then mine.l, mine.s, mine.t, mine.h = st.l, st.s, st.t or 1, false else mine.l, mine.s, mine.h = false, false, false end
                notify('~b~Rotirka~s~: Q  ~b~Sirena~s~: E  ~b~Ton~s~: R  ~b~Truba~s~: H')
            end
            Wait(0)
        else
            was = nil
            Wait(300)
        end
    end
end)

-- ---------------------------------------------------------------- everybody: lights + sounds of the emergency vehicles around you
local function stopSound(tbl, veh)
    local id = tbl[veh]
    if id then
        local sid = type(id) == 'table' and id.id or id
        StopSound(sid) ReleaseSoundId(sid)
        tbl[veh] = nil
    end
end

CreateThread(function()
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local cam = GetGameplayCamRot(2)
        local camH = math.rad(cam.z)
        local seen, hr = {}, {}
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if isEmergency(veh) then
                local p = GetEntityCoords(veh)
                local d = #(p - me)
                if d < (S.Range or 260.0) then
                    local st = stateOf(veh)
                    if st then
                        seen[veh] = true
                        SetVehicleHasMutedSirens(veh, true)           -- GTA's own siren sound off, ours plays
                        SetVehicleSiren(veh, st.l or st.s)
                        local tone = TONES[st.t or 1] or TONES[1]
                        -- siren sound
                        if st.s and tone.sound then
                            local cur = sounds[veh]
                            if not cur or cur.tone ~= st.t then
                                stopSound(sounds, veh)
                                local id = GetSoundId()
                                PlaySoundFromEntity(id, tone.sound, veh, 0, false, 0)
                                sounds[veh] = { id = id, tone = st.t }
                            end
                        else
                            stopSound(sounds, veh)
                        end
                        if st.s and tone.id == 'hr' then                -- Croatian two-tone from the NUI, loudness + side by distance
                            local inside = GetVehiclePedIsIn(PlayerPedId(), false) == veh
                            local vol = inside and 0.55 or math.max(0.0, 1.0 - d / (S.Range or 260.0)) ^ 1.6 * 0.6
                            local dx, dy = p.x - me.x, p.y - me.y
                            local ang = math.atan(dy, dx) - (camH + math.pi / 2)
                            local pan = inside and 0.0 or math.max(-1.0, math.min(1.0, -math.sin(ang) * 0.8))
                            local occl = (not inside and not HasEntityClearLosToEntity(PlayerPedId(), veh, 17)) and 0.55 or 1.0
                            hr[#hr + 1] = { id = veh, vol = vol * occl, pan = pan, amb = (GetEntityModel(veh) == joaat('ambulance')) }
                        end
                        -- air horn
                        if st.h then
                            if not horns[veh] then
                                local id = GetSoundId()
                                PlaySoundFromEntity(id, HORN, veh, 0, false, 0)
                                horns[veh] = id
                            end
                        else
                            stopSound(horns, veh)
                        end
                    end
                end
            end
        end
        for veh in pairs(sounds) do if not seen[veh] then stopSound(sounds, veh) end end
        for veh in pairs(horns) do if not seen[veh] then stopSound(horns, veh) end end
        if OsrpLocalSir then for veh in pairs(OsrpLocalSir) do if not DoesEntityExist(veh) then OsrpLocalSir[veh] = nil end end end
        if OsrpNpcSiren then for veh in pairs(OsrpNpcSiren) do if not DoesEntityExist(veh) then OsrpNpcSiren[veh] = nil end end end
        SendNUIMessage({ t = 'siren', list = hr })
        Wait(120)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh in pairs(sounds) do stopSound(sounds, veh) end
    for veh in pairs(horns) do stopSound(horns, veh) end
end)
