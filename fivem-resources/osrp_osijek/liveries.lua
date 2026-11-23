-- OSRP Osijek v1.0.45 - vehicle liveries made of our own decal models (works on every car model, no GTA files needed)
--   * police cars: white paint + blue "POLICIJA" band with yellow-green reflective edges on both sides.
--     The band is 6 pieces; each piece finds the car body with a ray, so it follows the curve of the doors.
--   * box trucks (Mule / Benson / Pounder): brand panels on both sides of the box (VOLT, STIL, DRAVA MARKET, KAVA DRAVA, OSIJEK TRANS)
-- Everything is client side (only you see your decals, everyone else makes their own), max. 40 decorated cars around you.

local L = Config.Liveries or {}
local POL_SEG, POL_SEGS = 0.6, 6
local decorated = {}          -- [veh] = { objects }

local function loadModel(name)
    local h = joaat(name)
    if not IsModelInCdimage(h) then return nil end
    RequestModel(h)
    local t = GetGameTimer()
    while not HasModelLoaded(h) and GetGameTimer() - t < 3000 do Wait(0) end
    return HasModelLoaded(h) and h or nil
end

local function attach(veh, model, x, y, z, rz, list)
    local h = loadModel(model)
    if not h then return false end
    local o = CreateObjectNoOffset(h, 0.0, 0.0, -100.0, false, false, false)
    SetEntityCollision(o, false, false)
    SetEntityCompletelyDisableCollision(o, false, false)
    AttachEntityToEntity(o, veh, 0, x, y, z, 0.0, 0.0, rz, false, false, false, false, 2, true)
    SetModelAsNoLongerNeeded(h)
    list[#list + 1] = o
    return true
end

-- side surface of the car at local (y, z), side = 1 right / -1 left -> local x of the paint (or nil)
local function surfaceX(veh, side, y, z, half)
    local from = GetOffsetFromEntityInWorldCoords(veh, side * (half + 1.5), y, z)
    local to = GetOffsetFromEntityInWorldCoords(veh, 0.0, y, z)
    local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, to.x, to.y, to.z, 2, 0, 4)
    local _, hit, pos, _, ent = GetShapeTestResult(ray)
    if hit == 1 and ent == veh then
        return GetOffsetFromEntityGivenWorldCoords(veh, pos.x, pos.y, pos.z).x
    end
    return nil
end

local function decoratePolice(veh)
    local mn, mx = GetModelDimensions(GetEntityModel(veh))
    local half = math.max(math.abs(mn.x), math.abs(mx.x))
    local len = POL_SEG * POL_SEGS
    local cy = (mn.y + mx.y) / 2 - 0.05
    local z = mn.z + (mx.z - mn.z) * (L.PoliceBandHeight or 0.42)
    local list = {}
    SetVehicleColours(veh, L.PoliceColour or 111, L.PoliceColour or 111)
    for _, side in ipairs({ 1, -1 }) do
        local xs = {}
        for i = 0, POL_SEGS - 1 do
            local y = cy - len / 2 + (i + 0.5) * POL_SEG
            xs[i] = surfaceX(veh, side, y, z, half)
        end
        -- fill misses (wheel arches) from the neighbours
        local last
        for i = 0, POL_SEGS - 1 do if xs[i] then last = xs[i] elseif last then xs[i] = last end end
        for i = POL_SEGS - 1, 0, -1 do if xs[i] then last = xs[i] elseif last then xs[i] = last end end
        for i = 0, POL_SEGS - 1 do
            if xs[i] then
                -- right side: text reads from the back to the front (+Y), left side from the front to the back
                local k = side == 1 and i or (POL_SEGS - 1 - i)
                local y = cy - len / 2 + (i + 0.5) * POL_SEG
                -- a little turn so each piece lies on the body (slope from the neighbour pieces)
                local a, b = xs[math.max(0, i - 1)], xs[math.min(POL_SEGS - 1, i + 1)]
                local slope = math.deg(math.atan((b - a) / (POL_SEG * 2.0)))
                local rz = (side == 1 and -90.0 or 90.0) - slope          -- body bends in -> piece turns with it
                attach(veh, 'osrpprop_decal_pol_' .. k, xs[i] + side * 0.012, y, z, rz, list)
            end
        end
    end
    return list
end

local BRANDS = { 'volt', 'stil', 'market', 'kava', 'trans' }

local function decorateTruck(veh, size)
    local mn, mx = GetModelDimensions(GetEntityModel(veh))
    local half = math.max(math.abs(mn.x), math.abs(mx.x))
    local brand = (TruckBrand and TruckBrand[veh]) or BRANDS[(veh % #BRANDS) + 1]
    local list = {}
    -- the box is the back part of the truck, upper half
    local L_ = mx.y - mn.y
    local cy = mn.y + L_ * (size == 'big' and 0.36 or 0.34)
    local z = mn.z + (mx.z - mn.z) * 0.62
    for _, side in ipairs({ 1, -1 }) do
        local xs = {}
        for _, dy in ipairs({ -1.0, 0.0, 1.0 }) do
            local x = surfaceX(veh, side, cy + dy, z, half)
            if x then xs[#xs + 1] = x end
        end
        if #xs > 0 then
            table.sort(xs, function(p, q) return math.abs(p) > math.abs(q) end)
            attach(veh, ('osrpprop_decal_truck_%s_%s'):format(brand, size), xs[1] + side * 0.02, cy, z, side == 1 and -90.0 or 90.0, list)
        end
    end
    return list
end

local function kindOf(veh)
    local m = GetEntityModel(veh)
    for _, n in ipairs(L.PoliceModels or {}) do if joaat(n) == m then return 'police' end end
    for n, size in pairs(L.TruckModels or {}) do if joaat(n) == m then return 'truck', size end end
    return nil
end

local function clear(veh)
    for _, o in ipairs(decorated[veh] or {}) do if DoesEntityExist(o) then DeleteObject(o) end end
    decorated[veh] = nil
end

CreateThread(function()
    if L.Enabled == false then return end
    while true do
        local me = GetEntityCoords(PlayerPedId())
        local count = 0
        for veh in pairs(decorated) do
            if not DoesEntityExist(veh) or #(GetEntityCoords(veh) - me) > 160.0 then clear(veh) else count = count + 1 end
        end
        for _, veh in ipairs(GetGamePool('CVehicle')) do
            if count >= (L.Max or 40) then break end
            if not decorated[veh] and #(GetEntityCoords(veh) - me) < 120.0 then
                local kind, size = kindOf(veh)
                if kind == 'police' then
                    decorated[veh] = decoratePolice(veh) count = count + 1
                elseif kind == 'truck' then
                    decorated[veh] = decorateTruck(veh, size) count = count + 1
                end
            end
        end
        Wait(1000)
    end
end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for veh in pairs(decorated) do clear(veh) end
end)
