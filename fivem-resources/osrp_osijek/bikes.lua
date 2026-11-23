-- OSRP Osijek v1.0.43 - Bike Osijek: city bike rental with a chooser (E at a bike station)
-- The bike turns on a stand in front of you, the camera circles it; pick the bike, its frame colour and accent colour.
-- Free city bikes: the last one you took disappears when you take a new one.

local BIKES = {
    { m = 'cruiser',  name = 'Gradski cruiser', type = 'Gradski',  speed = 45, handling = 70, comfort = 95, desc = 'Udoban gradski bicikl s košaricom za vožnju uz Dravu.' },
    { m = 'scorcher', name = 'Brdski Scorcher', type = 'MTB',      speed = 65, handling = 80, comfort = 70, desc = 'Brdski bicikl - za šljunak, parkove i Šumu.' },
    { m = 'tribike',  name = 'Cestovni Tri',    type = 'Cestovni', speed = 90, handling = 75, comfort = 45, desc = 'Najbrži na asfaltu i obilaznici.' },
    { m = 'tribike2', name = 'Cestovni Tri Pro', type = 'Cestovni', speed = 92, handling = 78, comfort = 45, desc = 'Lakši okvir, još brži.' },
    { m = 'tribike3', name = 'Cestovni Tri Sport', type = 'Cestovni', speed = 90, handling = 80, comfort = 48, desc = 'Sportska geometrija za duge vožnje.' },
    { m = 'fixter',   name = 'Fixie',           type = 'Gradski',  speed = 75, handling = 85, comfort = 55, desc = 'Jednostavan i brz - za gradske ulice.' },
    { m = 'bmx',      name = 'BMX',             type = 'Trik',     speed = 40, handling = 95, comfort = 40, desc = 'Za trikove na trgu i rampama.' },
    { m = 'inductor', name = 'E-bicikl Inductor', type = 'Električni', speed = 80, handling = 70, comfort = 85, desc = 'Električna pomoć pri vožnji.' },
}
local COLOURS = {   -- GTA paint ids + hex for the swatches
    { id = 0, hex = '#0d0d0d', n = 'Crna' }, { id = 111, hex = '#f2f2f2', n = 'Bijela' }, { id = 27, hex = '#c00e1a', n = 'Crvena' },
    { id = 38, hex = '#f78616', n = 'Narančasta' }, { id = 89, hex = '#f5d12b', n = 'Žuta' }, { id = 53, hex = '#155c2d', n = 'Zelena' },
    { id = 92, hex = '#79c600', n = 'Limeta' }, { id = 64, hex = '#2354a1', n = 'Plava' }, { id = 70, hex = '#0b9cf1', n = 'Svijetloplava' },
    { id = 145, hex = '#7c1b8a', n = 'Ljubičasta' }, { id = 137, hex = '#df5891', n = 'Roza' }, { id = 4, hex = '#99a0a8', n = 'Srebrna' },
    { id = 99, hex = '#c6a15a', n = 'Zlatna' }, { id = 96, hex = '#5d3a1a', n = 'Smeđa' },
}

local function W(x, y, z) return vector3(Config.Origin.x + x, Config.Origin.y + y, Config.Origin.z + (z or 0.0)) end
local function loadModel(h)
    if not IsModelInCdimage(h) then return false end
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) and GetGameTimer() - t < 5000 do Wait(0) end
    return HasModelLoaded(h)
end

-- stations = groups of the parked bikes from the map (Life.SPECIAL)
local STATIONS = {}
local isBike = {}
for _, b in ipairs(BIKES) do isBike[b.m] = true end
isBike.cruiser, isBike.scorcher, isBike.bmx, isBike.tribike = true, true, true, true
for _, sv in ipairs(Life.SPECIAL or {}) do
    if isBike[sv[5]] then
        local found
        for _, st in ipairs(STATIONS) do
            if math.abs(st.x - sv[1]) < 10.0 and math.abs(st.y - sv[2]) < 6.0 then found = st break end
        end
        if found then
            found.n = found.n + 1
            found.x = found.x + (sv[1] - found.x) / found.n
            found.y = found.y + (sv[2] - found.y) / found.n
        else
            STATIONS[#STATIONS + 1] = { x = sv[1], y = sv[2], h = sv[4] or 0.0, n = 1 }
        end
    end
end

local ui, preview, cam, myBike = nil, nil, nil, nil
local hidden = {}                                   -- v1.0.45: parked bikes + you are hidden while you choose

local function hideAround(pos)
    hidden = {}
    for _, v in ipairs(GetGamePool('CVehicle')) do
        if v ~= preview and DoesEntityExist(v) and #(GetEntityCoords(v) - pos) < 14.0 and GetPedInVehicleSeat(v, -1) == 0 then
            SetEntityVisible(v, false, false)
            SetEntityCollision(v, false, false)
            hidden[#hidden + 1] = v
        end
    end
    SetEntityVisible(PlayerPedId(), false, false)
end

local function unhide()
    for _, v in ipairs(hidden) do
        if DoesEntityExist(v) then SetEntityVisible(v, true, false) SetEntityCollision(v, true, true) end
    end
    hidden = {}
    SetEntityVisible(PlayerPedId(), true, false)
end

local function available()
    local out = {}
    for _, b in ipairs(BIKES) do
        if IsModelInCdimage(joaat(b.m)) then out[#out + 1] = b end
    end
    return out
end

local function showPreview(i, c1, c2)
    if not ui then return end
    local b = ui.list[i]
    if not b then return end
    local h = joaat(b.m)
    if not loadModel(h) then return end
    if preview and DoesEntityExist(preview) and GetEntityModel(preview) ~= h then DeleteVehicle(preview) preview = nil end
    if not preview or not DoesEntityExist(preview) then
        preview = CreateVehicle(h, ui.pos.x, ui.pos.y, ui.pos.z + 0.3, ui.heading, false, false)
        SetEntityCollision(preview, false, false)
        FreezeEntityPosition(preview, true)
        SetVehicleOnGroundProperly(preview)
        SetEntityAlpha(preview, 0, false)
        ui.fade = GetGameTimer()                    -- fade the new bike in
    end
    SetVehicleColours(preview, c1, c2)
    SetModelAsNoLongerNeeded(h)
end

local function closeUi(take)
    if not ui then return end
    local u = ui
    ui = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ t = 'bikes', open = false })
    if cam then RenderScriptCams(false, true, 600, true, true) DestroyCam(cam, false) cam = nil end
    local ped = PlayerPedId()
    FreezeEntityPosition(ped, false)
    if preview and DoesEntityExist(preview) then DeleteVehicle(preview) end
    preview = nil
    unhide()
    if take then
        local b = u.list[take.i]
        local h = joaat(b.m)
        if not loadModel(h) then return end
        if myBike and DoesEntityExist(myBike) and GetPedInVehicleSeat(myBike, -1) ~= ped then DeleteVehicle(myBike) end
        myBike = CreateVehicle(h, u.pos.x, u.pos.y, u.pos.z + 0.3, u.heading, true, false)
        SetVehicleOnGroundProperly(myBike)
        SetVehicleColours(myBike, take.c1, take.c2)
        SetVehicleHasBeenOwnedByPlayer(myBike, true)
        SetModelAsNoLongerNeeded(h)
        TaskWarpPedIntoVehicle(ped, myBike, -1)
        TriggerEvent('osrp:notify', ('~g~Bike Osijek:~s~ %s je tvoj - sretna vožnja!'):format(b.name))
    end
end

local function openUi(st)
    local list = available()
    if #list == 0 then return end
    local ped = PlayerPedId()
    local pp = GetEntityCoords(ped)
    local fwd = GetEntityForwardVector(ped)
    local pos = pp + fwd * 3.2
    local ok, gz = GetGroundZFor_3dCoord(pos.x, pos.y, pos.z + 1.0, false)
    pos = vector3(pos.x, pos.y, ok and gz or pp.z - 1.0)
    ui = { list = list, pos = pos, heading = GetEntityHeading(ped) + 90.0, spin = 0.0, fade = 0 }
    FreezeEntityPosition(ped, true)
    hideAround(pos)
    cam = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    SetCamFov(cam, 40.0)
    RenderScriptCams(true, true, 700, true, true)
    SetNuiFocus(true, true)
    local bikes = {}
    for _, b in ipairs(list) do bikes[#bikes + 1] = { name = b.name, type = b.type, speed = b.speed, handling = b.handling, comfort = b.comfort, desc = b.desc } end
    SendNUIMessage({ t = 'bikes', open = true, bikes = bikes, colours = COLOURS })
    showPreview(1, 27, 0)
end

RegisterNUICallback('bikePick', function(d, cb) cb({}) showPreview(tonumber(d.i) or 1, tonumber(d.c1) or 0, tonumber(d.c2) or 0) end)
RegisterNUICallback('bikeTake', function(d, cb) cb({}) closeUi({ i = tonumber(d.i) or 1, c1 = tonumber(d.c1) or 0, c2 = tonumber(d.c2) or 0 }) end)
RegisterNUICallback('bikeClose', function(_, cb) cb({}) closeUi(nil) end)

-- turntable + orbiting camera while the chooser is open
CreateThread(function()
    while true do
        if ui then
            local dt = GetFrameTime()
            ui.spin = (ui.spin + dt * 28.0) % 360.0
            if preview and DoesEntityExist(preview) then
                SetEntityHeading(preview, ui.heading + ui.spin)
                local a = math.min(255, math.floor((GetGameTimer() - ui.fade) / 400 * 255))
                SetEntityAlpha(preview, a, false)
                if a >= 255 then ResetEntityAlpha(preview) end
            end
            if GetGameTimer() > (ui.nextHide or 0) then
                ui.nextHide = GetGameTimer() + 700
                for _, v in ipairs(GetGamePool('CVehicle')) do
                    if v ~= preview and IsEntityVisible(v) and #(GetEntityCoords(v) - ui.pos) < 14.0 and GetPedInVehicleSeat(v, -1) == 0 then
                        SetEntityVisible(v, false, false) SetEntityCollision(v, false, false) hidden[#hidden + 1] = v
                    end
                end
            end
            if cam then
                local t = GetGameTimer() / 9000.0
                local r = 3.4
                SetCamCoord(cam, ui.pos.x + math.cos(t) * r, ui.pos.y + math.sin(t) * r, ui.pos.z + 1.35)
                PointCamAtCoord(cam, ui.pos.x, ui.pos.y, ui.pos.z + 0.55)
            end
            Wait(0)
        else
            Wait(400)
        end
    end
end)

-- E at a station
CreateThread(function()
    while true do
        local sleep = 800
        if not ui then
            local ped = PlayerPedId()
            if not IsPedInAnyVehicle(ped, false) then
                local p = GetEntityCoords(ped)
                for _, st in ipairs(STATIONS) do
                    local c = W(st.x, st.y, 0.0)
                    local d = #(vec2(p.x, p.y) - vec2(c.x, c.y))
                    if d < 30.0 then sleep = 0 end
                    if d < 4.5 then
                        BeginTextCommandDisplayHelp('STRING')
                        AddTextComponentSubstringPlayerName('~INPUT_CONTEXT~ Bike Osijek - izaberi bicikl (besplatno)')
                        EndTextCommandDisplayHelp(0, false, false, -1)
                        if IsControlJustReleased(0, 38) then openUi(st) end
                    end
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    if ui then closeUi(nil) end
    if myBike and DoesEntityExist(myBike) then DeleteVehicle(myBike) end
end)
