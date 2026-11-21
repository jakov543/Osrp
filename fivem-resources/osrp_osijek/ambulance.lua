-- OSRP Osijek - AI emergency vehicles (ambulance, fire truck, police) that drive along the Osijek streets
-- SendAmbulance(x, y, z, tag, patientPed?) -> an ambulance comes from KBC Osijek with sirens, two paramedics do CPR,
-- then TriggerEvent('osrp:aiAmbulanceArrived', tag) fires on this client (osrp_framework revives the player).
-- Everything is local to the player who needs help (like GTA's own ambulances).

local busy = {}

local function load(model)
    local h = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) and GetGameTimer() - t < 6000 do Wait(0) end
    return HasModelLoaded(h) and h or nil
end

local function loadDict(d)
    RequestAnimDict(d)
    local t = GetGameTimer()
    while not HasAnimDictLoaded(d) and GetGameTimer() - t < 4000 do Wait(0) end
end

local function startPoint(target)
    -- from the hospital when it is not too far, otherwise from a street ~250 m away
    local h = OsijekPlace and OsijekPlace('ambulance_start')
    if h and #(h - target) < 900.0 then return h end
    local route = OsijekRoute(target.x + 250.0, target.y, target.x, target.y)
    return route[1]
end

-- drive a vehicle through waypoints; returns when close to the last one (or teleports ahead if stuck)
function OsijekDriveRoute(veh, drv, route, speed, stopDist)
    for i, wp in ipairs(route) do
        local last = i == #route
        TaskVehicleDriveToCoord(drv, veh, wp.x, wp.y, wp.z, speed, 0, GetEntityModel(veh), 787004, last and (stopDist or 8.0) or 6.0, true)
        local t0, lastPos, stuck = GetGameTimer(), GetEntityCoords(veh), 0
        while DoesEntityExist(veh) do
            Wait(250)
            local p = GetEntityCoords(veh)
            if #(vec2(p.x, p.y) - vec2(wp.x, wp.y)) < (last and (stopDist or 8.0) + 2.0 or 9.0) then break end
            if #(p - lastPos) < 0.4 then stuck = stuck + 1 else stuck = 0 end
            lastPos = p
            if stuck > 24 or GetGameTimer() - t0 > 45000 then          -- 6 s stuck / 45 s on one leg: hop to the waypoint
                SetEntityCoords(veh, wp.x, wp.y, wp.z + 0.5, false, false, false, false)
                SetVehicleOnGroundProperly(veh)
                break
            end
        end
    end
    if DoesEntityExist(veh) then
        TaskVehicleTempAction(drv, veh, 27, 3000)                     -- brake
    end
end

local function cleanupLater(list, ms)
    SetTimeout(ms, function()
        for _, e in ipairs(list) do
            if DoesEntityExist(e) then
                SetEntityAsMissionEntity(e, true, true)
                if IsEntityAVehicle(e) then DeleteVehicle(e) else DeletePed(e) end
            end
        end
    end)
end

function SendAmbulance(x, y, z, tag, patient)
    if busy[tag] then return false end
    busy[tag] = true
    CreateThread(function()
        local target = vector3(x, y, z)
        local done = false
        local function finish()
            if done then return end
            done = true
            busy[tag] = nil
            TriggerEvent('osrp:aiAmbulanceArrived', tag)
        end
        SetTimeout(150000, finish)                                    -- never leave anyone waiting forever

        local vh, ph = load('ambulance'), load('s_m_m_paramedic_01')
        if not vh or not ph then
            Wait(20000)
            return finish()
        end
        local from = startPoint(target)
        local route = OsijekRoute(from.x, from.y, target.x, target.y)
        local veh = CreateVehicle(vh, from.x, from.y, from.z + 0.5, 0.0, false, false)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        SetVehicleSiren(veh, true)
        SetVehicleHasMutedSirens(veh, false)
        SetVehicleEngineOn(veh, true, true, false)
        local drv = CreatePedInsideVehicle(veh, 4, ph, -1, false, true)
        local med = CreatePedInsideVehicle(veh, 4, ph, 0, false, true)
        for _, p in ipairs({ drv, med }) do
            SetBlockingOfNonTemporaryEvents(p, true)
            SetPedKeepTask(p, true)
            SetEntityInvincible(p, true)
        end
        SetDriverAbility(drv, 1.0)
        SetModelAsNoLongerNeeded(vh)
        SetModelAsNoLongerNeeded(ph)

        local blip = AddBlipForEntity(veh)
        SetBlipSprite(blip, 61)
        SetBlipColour(blip, 1)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName('Hitna pomoć')
        EndTextCommandSetBlipName(blip)

        OsijekDriveRoute(veh, drv, route, 22.0, 6.0)
        -- last bit off the street (park, square, sidewalk): drive closer if it is short
        local vp = GetEntityCoords(veh)
        if #(vp - target) > 14.0 and #(vp - target) < 60.0 then
            OsijekDriveRoute(veh, drv, { target }, 6.0, 9.0)
        end
        if #(GetEntityCoords(veh) - target) > 70.0 then              -- something went wrong: bring it close
            SetEntityCoords(veh, target.x + 6.0, target.y, target.z + 0.5, false, false, false, false)
            SetVehicleOnGroundProperly(veh)
        end

        -- both paramedics get out and do CPR
        TaskLeaveVehicle(drv, veh, 0)
        TaskLeaveVehicle(med, veh, 0)
        Wait(1800)
        local spots = { target + vector3(0.8, 0.0, 0.0), target + vector3(-0.8, 0.3, 0.0) }
        for i, p in ipairs({ med, drv }) do
            TaskGoStraightToCoord(p, spots[i].x, spots[i].y, spots[i].z, 2.0, 12000, 0.0, 0.4)
        end
        local t = GetGameTimer()
        while GetGameTimer() - t < 12000 and #(GetEntityCoords(med) - spots[1]) > 1.2 do Wait(200) end
        loadDict('mini@cpr@char_a@cpr_str')
        TaskTurnPedToFaceCoord(med, target.x, target.y, target.z, 800)
        Wait(800)
        TaskPlayAnim(med, 'mini@cpr@char_a@cpr_str', 'cpr_pumpchest', 8.0, -8.0, 9000, 1, 0, false, false, false)
        TaskStartScenarioInPlace(drv, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
        Wait(9000)
        ClearPedTasks(med)
        ClearPedTasks(drv)
        if patient and DoesEntityExist(patient) then                   -- NPC patient goes into the ambulance
            SetEntityAsMissionEntity(patient, true, true)
            DeletePed(patient)
        end
        finish()

        -- back in and away to the hospital, then gone
        TaskEnterVehicle(drv, veh, 8000, -1, 2.0, 1, 0)
        TaskEnterVehicle(med, veh, 8000, 0, 2.0, 1, 0)
        Wait(7000)
        SetVehicleSiren(veh, false)
        RemoveBlip(blip)
        local home = OsijekPlace and OsijekPlace('ambulance_start') or from
        local back = OsijekRoute(GetEntityCoords(veh).x, GetEntityCoords(veh).y, home.x, home.y)
        CreateThread(function() OsijekDriveRoute(veh, drv, back, 14.0, 8.0) end)
        cleanupLater({ drv, med, veh }, 45000)
    end)
    return true
end
exports('SendAmbulance', SendAmbulance)

-- generic emergency vehicle (fire truck, police) that drives to a point with sirens and parks there
function SendEmergencyVehicle(model, crewModel, x, y, z, keepMs)
    CreateThread(function()
        local target = vector3(x, y, z)
        local vh, ph = load(model), load(crewModel)
        if not vh or not ph then return end
        local route = OsijekRoute(target.x - 220.0, target.y, target.x, target.y)
        local from = route[1]
        local veh = CreateVehicle(vh, from.x, from.y, from.z + 0.5, 0.0, false, false)
        SetEntityAsMissionEntity(veh, true, true)
        SetVehicleOnGroundProperly(veh)
        SetVehicleSiren(veh, true)
        local drv = CreatePedInsideVehicle(veh, 4, ph, -1, false, true)
        SetBlockingOfNonTemporaryEvents(drv, true)
        SetEntityInvincible(drv, true)
        SetModelAsNoLongerNeeded(vh)
        SetModelAsNoLongerNeeded(ph)
        OsijekDriveRoute(veh, drv, route, 20.0, 12.0)
        TaskLeaveVehicle(drv, veh, 0)
        Wait(2500)
        TaskStartScenarioInPlace(drv, 'WORLD_HUMAN_CLIPBOARD', 0, true)
        cleanupLater({ drv, veh }, keepMs or 60000)
    end)
end
