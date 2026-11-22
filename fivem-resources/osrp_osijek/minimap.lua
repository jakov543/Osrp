-- OSRP Osijek - real drawn map instead of blip rectangles (Config.MapMode = 'nui')
--  * minimap: inside Osijek the GTA radar is replaced by a drawn map of the city (rotates with the camera,
--    GPS route along the streets, waypoint, landmarks, other players, health/armour)
--  * big map: F7 or /karta - drag, zoom, click to set a waypoint (GPS), right click to remove it

local bigOpen = false
local cutscene = false
AddEventHandler('osrp:cutscene', function(on) cutscene = on end)
local lastRect, lastWp, lastRoute = '', nil, ''
local inside = false

local function useNui() return (Config.MapMode or 'nui') == 'nui' end

local function toLocal(v) return v.x - Config.Origin.x, v.y - Config.Origin.y end

local function inCity(p, extra)
    return #(vec2(p.x, p.y) - vec2(Config.Origin.x, Config.Origin.y)) < Config.CityRadius + (extra or 0.0)
end

local function radarRect()
    SetScriptGfxAlign(string.byte('L'), string.byte('B'))
    local x, y = GetScriptGfxPosition(-0.0045, 0.002 - 0.188888)
    local r, b = GetScriptGfxPosition(-0.0045 + 0.150, 0.002)
    ResetScriptGfxAlign()
    return x, y, r - x, b - y
end

-- position feed (25 per second)
CreateThread(function()
    while true do
        local wait = 1000
        if useNui() then
            local ped = PlayerPedId()
            local p = GetEntityCoords(ped)
            local now = inCity(p, 150.0) and not IsPauseMenuActive() and not cutscene and not IsScreenFadedOut()
            if now ~= inside then
                inside = now
                SendNUIMessage({ t = 'radar', show = now })
                if not now then DisplayRadar(true) end
            end
            if inside then
                wait = 40
                DisplayRadar(false)
                local x, y, w, h = radarRect()
                local key = ('%.4f%.4f%.4f%.4f'):format(x, y, w, h)
                if key ~= lastRect then
                    lastRect = key
                    SendNUIMessage({ t = 'radar', show = true, left = x, top = y, w = w, h = h })
                end
                local others = {}
                for _, pl in ipairs(GetActivePlayers()) do
                    if pl ~= PlayerId() then
                        local op = GetEntityCoords(GetPlayerPed(pl))
                        if #(op - p) < 400.0 then
                            local ox, oy = toLocal(op)
                            others[#others + 1] = { math.floor(ox), math.floor(oy) }
                        end
                    end
                end
                local lx, ly = toLocal(p)
                local maxHp = GetEntityMaxHealth(ped) - 100
                SendNUIMessage({
                    t = 'pos', x = lx, y = ly,
                    cam = GetGameplayCamRot(2).z, ped = GetEntityHeading(ped),
                    speed = GetEntitySpeed(ped),
                    hp = maxHp > 0 and (GetEntityHealth(ped) - 100) / maxHp * 100 or 0,
                    ar = GetPedArmour(ped), players = others,
                })
            elseif bigOpen then
                wait = 100
            end
        end
        Wait(wait)
    end
end)

-- waypoint + GPS route along the Osijek streets (every second)
CreateThread(function()
    while true do
        Wait(1000)
        if useNui() then
            local wp
            local blip = GetFirstBlipInfoId(8)
            if DoesBlipExist(blip) then
                local c = GetBlipInfoIdCoord(blip)
                if inCity(c, 50.0) then
                    local x, y = toLocal(c)
                    wp = { math.floor(x * 10) / 10, math.floor(y * 10) / 10 }
                end
            end
            local wkey = wp and (wp[1] .. ',' .. wp[2]) or nil
            if wkey ~= lastWp then
                lastWp = wkey
                SendNUIMessage({ t = 'wp', wp = wp })
            end
            local pts = {}
            local me = GetEntityCoords(PlayerPedId())
            if wp and inCity(me, 50.0) then
                local wx, wy = Config.Origin.x + wp[1], Config.Origin.y + wp[2]
                local mx, my = toLocal(me)
                pts[1] = { math.floor(mx), math.floor(my) }
                for _, w in ipairs(OsijekRoute(me.x, me.y, wx, wy)) do
                    local x, y = toLocal(w)
                    pts[#pts + 1] = { math.floor(x), math.floor(y) }
                end
                pts[#pts + 1] = { wp[1], wp[2] }
            end
            local rkey = json.encode(pts)
            if rkey ~= lastRoute then
                lastRoute = rkey
                SendNUIMessage({ t = 'route', pts = pts })
            end
        end
    end
end)

-- big map
local function setBig(open)
    bigOpen = open
    SetNuiFocus(open, open)
    SendNUIMessage({ t = 'big', open = open })
    if open then
        local ped = PlayerPedId()
        local lx, ly = toLocal(GetEntityCoords(ped))
        SendNUIMessage({ t = 'pos', x = lx, y = ly, cam = GetGameplayCamRot(2).z, ped = GetEntityHeading(ped), speed = 0,
                         hp = 100, ar = GetPedArmour(ped) })
    end
end

RegisterCommand('karta', function()
    if not useNui() then return end
    setBig(not bigOpen)
end, false)
RegisterKeyMapping('karta', 'Karta Osijeka', 'keyboard', 'F7')

RegisterNUICallback('closeBig', function(_, cb) setBig(false) cb({}) end)
RegisterNUICallback('setWaypoint', function(d, cb)
    local x, y = tonumber(d.x), tonumber(d.y)
    if x and y then
        SetNewWaypoint(Config.Origin.x + x, Config.Origin.y + y)
        PlaySoundFrontend(-1, 'WAYPOINT_SET', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
    lastWp = nil
    cb({})
end)
RegisterNUICallback('clearWaypoint', function(_, cb)
    SetWaypointOff()
    lastWp = nil
    cb({})
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() then
        DisplayRadar(true)
        if bigOpen then SetNuiFocus(false, false) end
    end
end)
