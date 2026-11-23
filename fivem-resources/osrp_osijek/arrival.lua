-- OSRP Osijek - arrival cutscene (v1.0.42): a short film when you arrive by plane at Zračna luka Osijek
--   1  aerial over the Drava at sunset (OSIJEK title)        4  touchdown, camera rolls next to the wheels
--   2  chase camera behind the plane, the city ahead          5  taxi to the terminal, wide apron shot
--   3  runway threshold - the plane flies right over you      6  orbit at the stand + welcome card
-- TriggerEvent('osrp_osijek:playArrival') -> ~32 s (ENTER skips), then 'osrp_osijek:arrivalDone'. Screen is black before and after.
-- Titles and letterbox are drawn by the NUI (html/cine.*), so they look like a real film intro.

local RW_Y = -665.0          -- runway centre line (city coordinates, see map/blender/osijek_starter.py)
local TOUCH_X = -430.0       -- touchdown point
local STAND = { 175.0, -555.0 }        -- apron stand (clear of the flood light masts)

local function W(x, y, z) return vector3(Config.Origin.x + x, Config.Origin.y + y, Config.Origin.z + (z or 0.0)) end

local function loadModel(list)
    for _, m in ipairs(list) do
        local h = joaat(m)
        if IsModelInCdimage(h) then
            RequestModel(h)
            local t = GetGameTimer()
            while not HasModelLoaded(h) and GetGameTimer() - t < 8000 do Wait(0) end
            if HasModelLoaded(h) then return h end
        end
    end
    return nil
end

local function smooth(u) u = math.max(0.0, math.min(1.0, u)) return u * u * (3 - 2 * u) end
local function lerp(a, b, u) return a + (b - a) * u end

-- plane path: returns x, y, height above runway, heading, pitch, roll (city coordinates)
local T_AIR, T_ROLL, T_TAXI = 18000, 8000, 6000
local TAXI = { { 150.0, RW_Y }, { 168.0, RW_Y + 22.0 }, { 175.0, -605.0 }, { STAND[1], STAND[2] } }
local function planeAt(t)
    if t < T_AIR then
        local u = t / T_AIR
        local x = lerp(-2100.0, TOUCH_X, u)
        local h = 160.0 * (1.0 - u) ^ 1.45
        local pitch = (u < 0.9) and -2.5 or (-2.5 + (u - 0.9) / 0.1 * 8.0)          -- flare before touchdown
        local roll = math.sin(t / 2300.0) * 1.6 * (1.0 - u)                       -- small corrections in the wind
        return x, RW_Y, h, 270.0, pitch, roll
    elseif t < T_AIR + T_ROLL then
        local u = (t - T_AIR) / T_ROLL
        local x = lerp(TOUCH_X, 150.0, 1.0 - (1.0 - u) ^ 2)
        return x, RW_Y, 0.0, 270.0, math.max(0.0, 5.5 - (t - T_AIR) / 450.0), 0.0
    else
        local u = smooth((t - T_AIR - T_ROLL) / T_TAXI)
        -- walk the taxi polyline by length
        local seg, total = {}, 0.0
        for i = 1, #TAXI - 1 do
            local a, b = TAXI[i], TAXI[i + 1]
            local L = math.sqrt((b[1] - a[1]) ^ 2 + (b[2] - a[2]) ^ 2)
            seg[i] = L total = total + L
        end
        local d = u * total
        for i = 1, #TAXI - 1 do
            if d <= seg[i] or i == #TAXI - 1 then
                local a, b = TAXI[i], TAXI[i + 1]
                local k = math.min(1.0, d / seg[i])
                local hd = (math.deg(math.atan(b[2] - a[2], b[1] - a[1])) - 90.0) % 360.0
                return lerp(a[1], b[1], k), lerp(a[2], b[2], k), 0.0, hd, 0.0, 0.0
            end
            d = d - seg[i]
        end
    end
end

local function nui(d) d.t = 'cine' SendNUIMessage(d) end

function PlayArrival()
    local ped = PlayerPedId()
    -- the city around the Drava and the airport are loaded before the film starts
    if LoadArea then
        LoadArea(Config.Origin.x - 80.0, Config.Origin.y + 150.0, 650.0, 12000)
        LoadArea(Config.Origin.x - 250.0, Config.Origin.y + RW_Y, 600.0, 12000)
    end
    local model = loadModel(Config.ArrivalPlane or { 'luxor' })
    if not model then return false end

    -- runway height for this plane
    local probe = W(-300.0, RW_Y, 3.0)
    RequestCollisionAtCoord(probe.x, probe.y, probe.z)
    local plane = CreateVehicle(model, probe.x, probe.y, probe.z, 270.0, false, false)
    SetEntityAsMissionEntity(plane, true, true)
    Wait(200)
    SetVehicleOnGroundProperly(plane)
    Wait(100)
    local gz = GetEntityCoords(plane).z
    if gz < Config.Origin.z - 2.0 then gz = Config.Origin.z + 1.4 end
    FreezeEntityPosition(plane, true)
    SetEntityCollision(plane, false, false)
    SetVehicleEngineOn(plane, true, true, false)
    SetVehicleLights(plane, 2)
    SetEntityInvincible(plane, true)
    ControlLandingGear(plane, 0)

    -- you ride along (hidden) so the map keeps streaming around the camera
    local px0 = W(-80.0, 150.0, 2.0)
    SetEntityCoordsNoOffset(ped, px0.x, px0.y, px0.z, false, false, false)
    FreezeEntityPosition(ped, true)
    SetEntityVisible(ped, false, false)
    SetEntityCollision(ped, false, false)

    NetworkOverrideClockTime(19, 5, 0)                 -- golden hour for the film
    local cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 50.0)
    SetCamActive(cam, true)
    RenderScriptCams(true, false, 0, true, true)
    ShakeCam(cam, 'HAND_SHAKE', 0.15)
    DisplayRadar(false)
    TriggerEvent('osrp:cutscene', true)
    nui({ on = true })
    DoScreenFadeIn(1500)

    local TOTAL = T_AIR + T_ROLL + T_TAXI + 2000
    local start = GetGameTimer()
    local shot, attached, skipped = 0, false, false
    local lastP = 0
    while true do
        Wait(0)
        local t = GetGameTimer() - start
        if t > TOTAL then break end
        if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) or IsControlJustPressed(0, 200) then skipped = true break end
        DisableAllControlActions(0)

        local x, y, h, hd, pitch, roll = planeAt(math.min(t, T_AIR + T_ROLL + T_TAXI))
        local p = W(x, y, 0.0)
        local pz = gz + h
        SetEntityCoordsNoOffset(plane, p.x, p.y, pz, false, false, false)
        SetEntityRotation(plane, pitch, roll, hd, 2, true)

        local rad = math.rad(hd)
        local fx, fy = -math.sin(rad), math.cos(rad)          -- plane forward
        local now
        if t < 6000 then                                       -- 1: aerial along the Drava, looking at the old town
            now = 1
            local u = smooth(t / 6000)
            local c = W(lerp(650.0, -250.0, u), lerp(20.0, 90.0, u), lerp(150.0, 105.0, u))
            local look = W(lerp(-30.0, -80.0, u), 200.0, 0.0)
            SetCamCoord(cam, c.x, c.y, c.z) PointCamAtCoord(cam, look.x, look.y, look.z) SetCamFov(cam, 48.0)
        elseif t < 12000 then                                  -- 2: chase camera, the city ahead
            now = 2
            SetCamCoord(cam, p.x - fx * 42.0 + fy * 8.0, p.y - fy * 42.0 - fx * 8.0, pz + 9.0)
            PointCamAtCoord(cam, p.x + fx * 60.0, p.y + fy * 60.0, pz - 6.0) SetCamFov(cam, 55.0)
        elseif t < 16300 then                                  -- 3: runway threshold, it flies over you
            now = 3
            local c = W(TOUCH_X - 60.0, RW_Y - 26.0, 1.6)
            SetCamCoord(cam, c.x, c.y, c.z) PointCamAtEntity(cam, plane, 0.0, 0.0, 0.0, true) SetCamFov(cam, 42.0)
        elseif t < T_AIR + 3500 then                           -- 4: touchdown, camera rolls next to the wheels
            now = 4
            SetCamCoord(cam, p.x + fx * 6.0 + fy * 24.0, p.y + fy * 6.0 - fx * 24.0, gz + 1.3)
            PointCamAtCoord(cam, p.x, p.y, gz + 2.0) SetCamFov(cam, 38.0)
        elseif t < T_AIR + T_ROLL + 3500 then                  -- 5: wide apron shot from the terminal
            now = 5
            local c = W(265.0, -545.0, 16.0)
            SetCamCoord(cam, c.x, c.y, c.z) PointCamAtEntity(cam, plane, 0.0, 0.0, 0.0, true) SetCamFov(cam, 40.0)
        else                                                   -- 6: slow orbit at the stand
            now = 6
            local a = (t - T_AIR - T_ROLL - 3500) / 6000.0 * 1.2 + 0.8
            SetCamCoord(cam, p.x + math.cos(a) * 34.0, p.y + math.sin(a) * 34.0, gz + 7.0)
            PointCamAtCoord(cam, p.x, p.y, gz + 3.0) SetCamFov(cam, 45.0)
        end
        if now ~= shot then
            shot = now
            if shot == 2 and not attached then              -- from now on you ride with the plane (streaming follows)
                AttachEntityToEntity(ped, plane, 0, 0.0, 0.0, -2.0, 0.0, 0.0, 0.0, false, false, false, false, 2, true)
                attached = true
            end
            if shot == 4 then ControlLandingGear(plane, 0) end
            nui({ shot = shot, t = 'cine' })
        end
        if t - (lastP or 0) > 120 then lastP = t nui({ progress = t / TOTAL }) end
    end

    nui({ shot = 7 })                                        -- welcome card while the screen fades
    DoScreenFadeOut(skipped and 300 or 1500)
    while not IsScreenFadedOut() do Wait(0) end
    if attached then DetachEntity(ped, false, false) end
    FreezeEntityPosition(ped, false)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(cam, false)
    DeleteVehicle(plane)
    SetModelAsNoLongerNeeded(model)
    NetworkClearClockTimeOverride()
    DisplayRadar(true)
    nui({ on = false })
    TriggerEvent('osrp:cutscene', false)
    return true
end

-- started with an event (an export cannot wait); osrp_osijek:arrivalDone fires when it is over
AddEventHandler('osrp_osijek:playArrival', function()
    CreateThread(function()
        local ok, err = pcall(PlayArrival)
        if not ok then
            print('[osrp_osijek] arrival: ' .. tostring(err))
            local ped = PlayerPedId()
            DetachEntity(ped, false, false) FreezeEntityPosition(ped, false) SetEntityVisible(ped, true, false) SetEntityCollision(ped, true, true)
            RenderScriptCams(false, false, 0, true, true)
            NetworkClearClockTimeOverride()
            DisplayRadar(true)
            SendNUIMessage({ t = 'cine', on = false })
            TriggerEvent('osrp:cutscene', false)
        end
        TriggerEvent('osrp_osijek:arrivalDone')
    end)
end)

-- where you stand after the flight: arrivals hall in the terminal (world coords + heading)
exports('GetArrivalSpot', function()
    local p = Life.PLACES and Life.PLACES.terminal_arrival or { 210, -453 }
    return vector4(Config.Origin.x + p[1], Config.Origin.y + p[2], Config.Origin.z + 1.0, 0.0)
end)
