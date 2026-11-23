-- OSRP framework v1.0.43 - cinematic crash camera (slow motion like a film trailer)
-- Fires when: you crash your vehicle hard, you hit a pedestrian / NPC with a car, or a car hits you on foot.
-- What you see: time slows down, the camera cuts to a low side angle and slowly circles the impact, black film bars,
-- a white flash, a short title (SUDAR · 87 km/h) and the game snaps back to normal speed.
-- Settings: Config.CrashCam in config.lua (or setr osrp_crashcam false in server.cfg).

local C = Config.CrashCam or {}
local busy, lastAt = false, 0
local cutscene = false
AddEventHandler('osrp:cutscene', function(on) cutscene = on end)

local function enabled()
    if C.Enabled == false or busy or cutscene then return false end
    if GetGameTimer() - lastAt < (C.Cooldown or 20) * 1000 then return false end
    if IsPauseMenuActive() or IsEntityDead(PlayerPedId()) then return false end
    return true
end

local function play(focus, kind, kmh)
    busy, lastAt = true, GetGameTimer()
    local ped = PlayerPedId()
    local center = GetEntityCoords(focus)
    local fwd = GetEntityForwardVector(focus)
    local side = vector3(-fwd.y, fwd.x, 0.0)
    if math.random() < 0.5 then side = -side end
    local start = GetGameTimer()
    local dur = C.Duration or 2400

    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local function place(u)
        local a = u * 0.7                                              -- slow orbit while time is slowed
        local dir = side * math.cos(a) + fwd * math.sin(a)
        local c = GetEntityCoords(focus)
        local dist = kind == 'onfoot' and 4.5 or 6.5
        SetCamCoord(cam, c.x + dir.x * dist, c.y + dir.y * dist, c.z + (kind == 'onfoot' and 0.8 or 1.1))
        PointCamAtCoord(cam, c.x, c.y, c.z + 0.4)
    end
    SetCamFov(cam, 38.0)
    place(0.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    ShakeCam(cam, 'SMALL_EXPLOSION_SHAKE', 0.35)
    SetTimeScale(C.SlowMo or 0.22)
    AnimpostfxPlay('FocusIn', 0, false)
    PlaySoundFrontend(-1, 'Hit_Out', 'PLAYER_SWITCH_CUSTOM_SOUNDSET', true)
    local titles = { car = 'SUDAR', hitped = 'UDARIO SI PJEŠAKA', onfoot = 'UDAREN SI' }
    SendNUIMessage({ action = 'crashcam', on = true, title = titles[kind] or 'SUDAR', sub = kmh and (math.floor(kmh) .. ' km/h') or '' })

    while GetGameTimer() - start < dur do
        local u = (GetGameTimer() - start) / dur
        place(u)
        -- speed up again during the last third, so it eases back into the game
        if u > 0.66 then SetTimeScale((C.SlowMo or 0.22) + (1.0 - (C.SlowMo or 0.22)) * ((u - 0.66) / 0.34)) end
        DisableControlAction(0, 0, true)                               -- no camera change while the shot runs
        Wait(0)
    end
    SetTimeScale(1.0)
    AnimpostfxStop('FocusIn')
    AnimpostfxPlay('SwitchHUDOut', 300, false)
    PlaySoundFrontend(-1, 'Short_Transition_In', 'PLAYER_SWITCH_CUSTOM_SOUNDSET', true)
    RenderScriptCams(false, true, 450, true, true)
    DestroyCam(cam, false)
    SendNUIMessage({ action = 'crashcam', on = false })
    Wait(500)
    busy = false
end

-- detection
CreateThread(function()
    local lastSpeed = 0.0
    while true do
        local ped = PlayerPedId()
        local veh = GetVehiclePedIsIn(ped, false)
        local sleep = 250
        if veh ~= 0 and GetPedInVehicleSeat(veh, -1) == ped then
            sleep = 50
            local sp = GetEntitySpeed(veh)
            local minS = (C.MinSpeedKmh or 45) / 3.6
            -- 1) hard crash: big speed loss in one step while touching something
            if lastSpeed > minS and (lastSpeed - sp) > (C.CrashDrop or 8.5) and HasEntityCollidedWithAnything(veh) and enabled() then
                play(veh, 'car', lastSpeed * 3.6)
            end
            -- 2) you hit a pedestrian / NPC
            if sp > 7.0 and enabled() then
                for _, p in ipairs(GetGamePool('CPed')) do
                    if p ~= ped and not IsPedInAnyVehicle(p, true) and #(GetEntityCoords(p) - GetEntityCoords(veh)) < 7.0
                        and HasEntityBeenDamagedByEntity(p, veh, true) then
                        ClearEntityLastDamageEntity(p)
                        play(p, 'hitped', sp * 3.6)
                        break
                    end
                end
            end
            lastSpeed = sp
        else
            lastSpeed = 0.0
            -- 3) a car hits you on foot
            if veh == 0 and HasEntityBeenDamagedByAnyVehicle(ped) then
                ClearEntityLastDamageEntity(ped)
                if enabled() then
                    local hitBy, best = nil, 9.0
                    for _, v in ipairs(GetGamePool('CVehicle')) do
                        local d = #(GetEntityCoords(v) - GetEntityCoords(ped))
                        if d < best and GetEntitySpeed(v) > 5.0 then hitBy, best = v, d end
                    end
                    if hitBy then play(ped, 'onfoot', GetEntitySpeed(hitBy) * 3.6) end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and busy then SetTimeScale(1.0) RenderScriptCams(false, false, 0, true, true) end
end)
