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
    if y < -360 then
        if x > -400 and x < -255 and y > -445 then return 'KBC Osijek' end
        if y < -455 or (x > 100 and x < 300) then return 'Zračna luka Osijek' end
        return 'Južna zona'
    end
    if y >= 265 and x > -420 and x < -180 and y < 300 then return 'Kupalište Copacabana' end
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
    if math.abs(x) > 600 or y < -800 or y > 380 then return nil end
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
    elseif math.abs(x - 150) < 8 and y < -355 and y > -396 then street = 'Cesta do zračne luke'
    elseif y < -642 and y > -688 and math.abs(x) < 500 then street = 'Uzletno-sletna staza'
    elseif y < -360 and math.abs(x + 330) < 65 and y > -381 then street = 'KBC Osijek - parkiralište'
    elseif y < -395 and y > -615 and x > 40 and x < 360 then street = 'Platforma (stajanke)'
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
OsijekLocation = GetLocation

-- ------------------------------------------------------------------ road graph (for AI ambulance, fire truck, events)
-- nodes = street intersections and street ends; edges = street pieces. City coordinates.
local ROW_Y = { -350, -180, 0, 125 }
local COL_X = { -450, -300, -150, 0, 150, 300, 450 }
local XS = { -540, -450, -300, -150, 0, 150, 300, 450, 540 }
local nodes, adj = {}, {}
local function nodeId(x, y)
    local k = x .. ',' .. y
    if not nodes[k] then nodes[k] = { x = x, y = y } adj[k] = {} end
    return k
end
local function link(a, b)
    local d = math.abs(nodes[a].x - nodes[b].x) + math.abs(nodes[a].y - nodes[b].y)
    adj[a][b] = d adj[b][a] = d
end
for _, y in ipairs(ROW_Y) do
    for i = 1, #XS - 1 do link(nodeId(XS[i], y), nodeId(XS[i + 1], y)) end
end
for _, x in ipairs(COL_X) do
    for i = 1, #ROW_Y - 1 do link(nodeId(x, ROW_Y[i]), nodeId(x, ROW_Y[i + 1])) end
end
link(nodeId(150, -350), nodeId(150, -395))   -- airport road

-- nearest point on any street: returns x, y, nodeA, nodeB
local function project(x, y)
    local best, bx, by, ba, bb = 1e18
    for a, nbrs in pairs(adj) do
        for b in pairs(nbrs) do
            if a < b then
                local A, B = nodes[a], nodes[b]
                local px, py
                if A.y == B.y then px, py = math.max(math.min(A.x, B.x), math.min(math.max(A.x, B.x), x)), A.y
                else px, py = A.x, math.max(math.min(A.y, B.y), math.min(math.max(A.y, B.y), y)) end
                local d = (px - x) ^ 2 + (py - y) ^ 2
                if d < best then best, bx, by, ba, bb = d, px, py, a, b end
            end
        end
    end
    return bx, by, ba, bb
end

local function dijkstra(starts, goals)
    local dist, prev, done = {}, {}, {}
    for k, d in pairs(starts) do dist[k] = d end
    while true do
        local u, ud
        for k, d in pairs(dist) do if not done[k] and (not ud or d < ud) then u, ud = k, d end end
        if not u then return nil end
        if goals[u] then
            local path = {}
            while u do table.insert(path, 1, u) u = prev[u] end
            return path, goals[path[#path]]
        end
        done[u] = true
        for v, w in pairs(adj[u]) do
            if not done[v] and (not dist[v] or ud + w < dist[v]) then dist[v] = ud + w prev[v] = u end
        end
    end
end

-- world waypoints from (wx1, wy1) to (wx2, wy2) along the streets
local function GetRoute(wx1, wy1, wx2, wy2)
    local ox, oy = Config.Origin.x, Config.Origin.y
    local sx, sy, sa, sb = project(wx1 - ox, wy1 - oy)
    local ex, ey, ea, eb = project(wx2 - ox, wy2 - oy)
    local pts = { { sx, sy } }
    if not ((sa == ea and sb == eb) or (sa == eb and sb == ea)) then
        local function d(k, px, py) return math.abs(nodes[k].x - px) + math.abs(nodes[k].y - py) end
        local path = dijkstra({ [sa] = d(sa, sx, sy), [sb] = d(sb, sx, sy) }, { [ea] = true, [eb] = true })
        for _, k in ipairs(path or {}) do pts[#pts + 1] = { nodes[k].x, nodes[k].y } end
    end
    pts[#pts + 1] = { ex, ey }
    local out = {}
    for _, p in ipairs(pts) do
        local last = out[#out]
        local w = vector3(ox + p[1], oy + p[2], Config.Origin.z + 0.5)
        if not last or #(last - w) > 3.0 then out[#out + 1] = w end
    end
    return out
end
exports('GetRoute', GetRoute)

-- named places from the map (hospital door, EMS garage, airport ...), world coords
local function GetPlace(name)
    local p = Life and Life.PLACES and Life.PLACES[name]
    if not p then return nil end
    return vector3(Config.Origin.x + p[1], Config.Origin.y + p[2], Config.Origin.z + 0.5)
end
exports('GetPlace', GetPlace)
OsijekRoute, OsijekPlace = GetRoute, GetPlace

-- nearest street point to a world position: world point, street is horizontal (east-west)?, city x, city y
function OsijekNearestStreet(wx, wy)
    local x, y, a, b = project(wx - Config.Origin.x, wy - Config.Origin.y)
    return vector3(Config.Origin.x + x, Config.Origin.y + y, Config.Origin.z), nodes[a].y == nodes[b].y, x, y
end
