-- OSRP Osijek - street and zone names for the HUD (GTA has no street names out here at sea)
-- Coordinates are city coordinates (relative to Config.Origin), matching map/blender/osijek_starter.py.

local ROWS = {          -- streets running east-west: y, half width incl. sidewalk, name
    { 0,    15, 'Europska avenija' },
    { -180, 10, 'Kapucinska ulica' },
    { -350, 10, 'Vukovarska ulica' },
    { 125,  10, 'Šetalište kardinala Šepera' },
    { 164,  9,  'Promenada uz Dravu' },
}

local COLS = {          -- streets running north-south: x, name
    { -450, 'Ulica svetog Roka' },
    { -300, 'Šamačka ulica' },
    { -150, 'Radićeva ulica' },
    { 0,    'Županijska ulica' },
    { 150,  'Ulica Hrvatske Republike' },
    { 300,  'Ulica Franje Kuhača' },
    { 450,  'Divaltova ulica' },
}
local COL_HALF = 10

local function zoneAt(x, y)
    if y > 175 and y < 265 then return 'Drava' end
    if y >= 265 then return 'Lijeva obala Drave' end
    if math.abs(x - 225) < 62 and math.abs(y - 62) < 50 then return 'Tvrđa' end
    if x > -295 and x < -155 and y > 8 and y < 120 then return 'Gradski park' end
    if x < -150 then return 'Gornji grad' end
    if x > 150 then return 'Donji grad' end
    return 'Centar'
end

-- returns street, zone (both strings) or nil when the position is not in Osijek
local function GetLocation(wx, wy)
    local x, y = wx - Config.Origin.x, wy - Config.Origin.y
    if math.abs(x) > 600 or y < -400 or y > 380 then return nil end
    local row, col
    for _, r in ipairs(ROWS) do
        if math.abs(y - r[1]) <= r[2] then row = r[3] break end
    end
    if y > -360 and y < 135 then
        for _, c in ipairs(COLS) do
            if math.abs(x - c[1]) <= COL_HALF then col = c[2] break end
        end
    end
    local street
    if row and col then street = row .. ' / ' .. col
    elseif row then street = row
    elseif col then street = col
    elseif y > 175 and y < 265 and math.abs(x + 80) < 4 then street = 'Pješački most'
    else
        -- nearest street name, so you always see where you are
        local best, bd = nil, 1e9
        for _, r in ipairs(ROWS) do local d = math.abs(y - r[1]) if d < bd then best, bd = r[3], d end end
        for _, c in ipairs(COLS) do local d = math.abs(x - c[1]) if d < bd and y < 135 then best, bd = c[2], d end end
        street = best
    end
    return street, zoneAt(x, y)
end

exports('GetLocation', GetLocation)
