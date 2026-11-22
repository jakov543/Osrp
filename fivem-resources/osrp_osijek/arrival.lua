-- OSRP Osijek - arrival cutscene: you fly in over the sea and land at Zračna luka Osijek (runway 09)
-- TriggerEvent('osrp_osijek:playArrival') -> ~25 s (ENTER skips), then 'osrp_osijek:arrivalDone'. Screen is black before and after.
-- Used by osrp_framework for new characters (and the "Zračna luka (dolazak avionom)" spawn).

local RW_Y = -665.0          -- runway centre line (city coordinates, see map/blender/osijek_starter.py)

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

local function txt(text, x, y, scale, font, r, g, b, a, centre)
    SetTextFont(font or 4)
    SetTextScale(0.0, scale)
    SetTextColour(r or 255, g or 255, b or 255, a or 255)
    SetTextCentre(centre ~= false)
    SetTextDropshadow(2, 0, 0, 0, 200)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

local function smooth(u) return u * u * (3 - 2 * u) end

function PlayArrival()
    if LoadArea then LoadArea(Config.Origin.x - 250.0, Config.Origin.y + RW_Y, 480.0, 15000) end
    local model = loadModel(Config.ArrivalPlane or { 'luxor' })
    if not model then return false end

    -- ground height of the runway for this plane
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
    ControlLandingGear(plane, 0)
    SetVehicleLights(plane, 2)
    SetEntityInvincible(plane, true)

    local camA = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    local camB = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', W(-330.0, RW_Y + 32.0, 2.5), 0.0, 0.0, 0.0, 45.0, false, 0)
    local camC = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', W(60.0, -560.0, 24.0), 0.0, 0.0, 0.0, 50.0, false, 0)
    SetCamFov(camA, 50.0)
    PointCamAtEntity(camA, plane, 0.0, 0.0, 0.0, true)
    PointCamAtEntity(camB, plane, 0.0, 0.0, 0.0, true)
    PointCamAtEntity(camC, plane, 0.0, 0.0, 0.0, true)
    SetCamActive(camA, true)
    RenderScriptCams(true, false, 0, true, true)
    DisplayRadar(false)
    TriggerEvent('osrp:cutscene', true)
    DoScreenFadeIn(1200)

    local T1, T2 = 15000, 10000            -- approach + touchdown, roll-out
    local start = GetGameTimer()
    local stage = 1
    local skipped = false
    while true do
        Wait(0)
        local t = GetGameTimer() - start
        if t > T1 + T2 then break end
        if IsControlJustPressed(0, 191) or IsControlJustPressed(0, 201) or IsControlJustPressed(0, 200) then skipped = true break end
        local x, z, pitch
        if t < T1 then
            local u = t / T1
            x = -1750.0 + (-430.0 + 1750.0) * u
            z = gz + 105.0 * (1.0 - u) ^ 1.6
            pitch = (u < 0.88) and -3.0 or (-3.0 + (u - 0.88) / 0.12 * 8.0)
        else
            local u = smooth((t - T1) / T2)
            x = -430.0 + 560.0 * (1.0 - (1.0 - u) ^ 2)
            z = gz
            pitch = math.max(0.0, 5.0 - (t - T1) / 600.0)
        end
        local p = W(x, RW_Y, 0.0)
        SetEntityCoordsNoOffset(plane, p.x, p.y, z, false, false, false)
        SetEntityRotation(plane, pitch, 0.0, 270.0, 2, true)
        if stage == 1 then
            SetCamCoord(camA, p.x - 34.0, p.y + 30.0, z + 7.0)
            if t > 8500 then SetCamActiveWithInterp(camB, camA, 1500, 1, 1) stage = 2 end
        elseif stage == 2 and t > T1 + 1500 then
            SetCamActiveWithInterp(camC, camB, 2000, 1, 1)
            stage = 3
        end
        -- letterbox + titles
        DrawRect(0.5, 0.05, 1.0, 0.1, 0, 0, 0, 255)
        DrawRect(0.5, 0.95, 1.0, 0.1, 0, 0, 0, 255)
        if t > 1500 and t < 10500 then
            local a = math.floor(255 * math.min(1.0, (t - 1500) / 1200, (10500 - t) / 1200))
            txt('OSIJEK', 0.5, 0.36, 1.6, 7, 255, 255, 255, a)
            txt('Zračna luka Osijek  ·  Dobrodošli', 0.5, 0.47, 0.5, 4, 244, 183, 64, a)
        end
        if t > T1 + 3000 then
            local a = math.floor(255 * math.min(1.0, (t - T1 - 3000) / 1000))
            txt('OSRP | Osijek Roleplay', 0.5, 0.905, 0.42, 4, 31, 214, 182, a)
        end
        txt('ENTER - preskoči', 0.94, 0.915, 0.32, 4, 200, 200, 200, 200)
    end

    DoScreenFadeOut(skipped and 300 or 1000)
    while not IsScreenFadedOut() do
        DrawRect(0.5, 0.05, 1.0, 0.1, 0, 0, 0, 255)
        DrawRect(0.5, 0.95, 1.0, 0.1, 0, 0, 0, 255)
        Wait(0)
    end
    RenderScriptCams(false, false, 0, true, true)
    for _, c in ipairs({ camA, camB, camC }) do DestroyCam(c, false) end
    DeleteVehicle(plane)
    SetModelAsNoLongerNeeded(model)
    DisplayRadar(true)
    TriggerEvent('osrp:cutscene', false)
    return true
end
-- started with an event (an export cannot wait); osrp_osijek:arrivalDone fires when it is over
AddEventHandler('osrp_osijek:playArrival', function()
    CreateThread(function()
        local ok, err = pcall(PlayArrival)
        if not ok then print('[osrp_osijek] arrival: ' .. tostring(err)) DisplayRadar(true) TriggerEvent('osrp:cutscene', false) end
        TriggerEvent('osrp_osijek:arrivalDone')
    end)
end)

-- where you stand after the flight: arrivals hall in the terminal (world coords + heading)
exports('GetArrivalSpot', function()
    local p = Life.PLACES and Life.PLACES.terminal_arrival or { 210, -453 }
    return vector4(Config.Origin.x + p[1], Config.Origin.y + p[2], Config.Origin.z + 1.0, 0.0)
end)
