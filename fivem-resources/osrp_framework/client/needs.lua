-- OSRP framework v1.0.43 - hunger + thirst (light: slow, never kills fast). Saved on your PC per character.
local N = Config.Needs or { Enabled = false }
local hunger, thirst = 100.0, 100.0
local key = 'osrp_needs'
local active = false

local function save() SetResourceKvp(key, json.encode({ h = hunger, t = thirst })) end
local function push() SendNUIMessage({ action = 'needs', hunger = math.floor(hunger), thirst = math.floor(thirst), on = N.Enabled }) end

AddEventHandler('osrp:playerSpawned', function()
    local ok, d = pcall(json.decode, GetResourceKvpString(key) or '')
    if ok and type(d) == 'table' then hunger, thirst = tonumber(d.h) or 100.0, tonumber(d.t) or 100.0 end
    if hunger < 30 then hunger = 30 end
    if thirst < 30 then thirst = 30 end
    active = true
    push()
end)
RegisterNetEvent('osrp:backToMenu', function() active = false end)

RegisterNetEvent('osrp_osijek:drink', function(item)
    local it = (N.Items or {})[item]
    if not it then return end
    Wait(4000)                                     -- after the eating / drinking animation
    hunger = math.min(100.0, hunger + (it.hunger or 0))
    thirst = math.min(100.0, thirst + (it.thirst or 0))
    save() push()
end)
exports('AddNeeds', function(h, t)
    hunger = math.max(0.0, math.min(100.0, hunger + (tonumber(h) or 0)))
    thirst = math.max(0.0, math.min(100.0, thirst + (tonumber(t) or 0)))
    push()
end)

CreateThread(function()
    local tick = 0
    while true do
        Wait(5000)
        if N.Enabled and active then
            local ped = PlayerPedId()
            local run = IsPedSprinting(ped) and 1.6 or 1.0
            hunger = math.max(0.0, hunger - 100.0 / (N.HungerMinutes * 12) * run)
            thirst = math.max(0.0, thirst - 100.0 / (N.ThirstMinutes * 12) * run)
            if N.Damage and (hunger <= 0 or thirst <= 0) and not IsEntityDead(ped) and GetEntityHealth(ped) > 120 then
                SetEntityHealth(ped, GetEntityHealth(ped) - 2)
            end
            push()
            tick = tick + 1
            if tick % 6 == 0 then save() end
        end
    end
end)
-- after dying you come back a bit hungry, never empty
AddEventHandler('osrp:respawned', function() hunger, thirst = math.max(hunger, 50.0), math.max(thirst, 50.0) push() end)
