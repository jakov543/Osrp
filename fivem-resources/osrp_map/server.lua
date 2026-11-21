-- OSRP map builder V1 - server: stores props (KVP) and syncs them to everyone
-- Only admins (ace osrp.admin, same as osrp_framework) can place or delete props.

local KVP_KEY = 'osrp:mapprops'
local props, nextId = {}, 1

local function load()
    local raw = GetResourceKvpString(KVP_KEY)
    if raw then
        local ok, data = pcall(json.decode, raw)
        if ok and type(data) == 'table' then
            props = data.props or {}
            nextId = data.nextId or 1
        end
    end
    print(('^2[OSRP map]^7 %d propova učitano'):format(#props))
end

local function save()
    SetResourceKvp(KVP_KEY, json.encode({ props = props, nextId = nextId }))
end

local function isAdmin(src) return IsPlayerAceAllowed(src, 'osrp.admin') end

local function validProp(p)
    return type(p) == 'table' and type(p.model) == 'string' and #p.model <= 64 and p.model:match('^[%w_]+$')
        and tonumber(p.x) and tonumber(p.y) and tonumber(p.z)
end

CreateThread(load)

RegisterNetEvent('osrp_map:request', function()
    TriggerClientEvent('osrp_map:all', source, props)
end)

RegisterNetEvent('osrp_map:add', function(list)
    local src = source
    if not isAdmin(src) then return TriggerClientEvent('osrp_map:msg', src, '~r~Nemaš dozvolu (admin).') end
    if type(list) ~= 'table' then return end
    local added = {}
    for _, p in ipairs(list) do
        if #props >= Config.MaxProps then
            TriggerClientEvent('osrp_map:msg', src, '~r~Dosegnut limit propova (' .. Config.MaxProps .. ').')
            break
        end
        if validProp(p) and #added < 200 then
            local prop = {
                id = nextId, model = p.model,
                x = p.x + 0.0, y = p.y + 0.0, z = p.z + 0.0, h = (tonumber(p.h) or 0.0) + 0.0
            }
            nextId = nextId + 1
            props[#props + 1] = prop
            added[#added + 1] = prop
        end
    end
    if #added > 0 then
        save()
        TriggerClientEvent('osrp_map:added', -1, added)
        TriggerClientEvent('osrp_map:msg', src, ('Postavljeno: ~g~%d~s~ (ukupno %d)'):format(#added, #props))
    end
end)

RegisterNetEvent('osrp_map:remove', function(id)
    local src = source
    if not isAdmin(src) then return TriggerClientEvent('osrp_map:msg', src, '~r~Nemaš dozvolu (admin).') end
    id = tonumber(id)
    for i, p in ipairs(props) do
        if p.id == id then
            table.remove(props, i)
            save()
            TriggerClientEvent('osrp_map:removed', -1, id)
            TriggerClientEvent('osrp_map:msg', src, 'Prop obrisan.')
            return
        end
    end
end)

RegisterNetEvent('osrp_map:undo', function()
    local src = source
    if not isAdmin(src) or #props == 0 then return end
    local last = table.remove(props)
    save()
    TriggerClientEvent('osrp_map:removed', -1, last.id)
    TriggerClientEvent('osrp_map:msg', src, 'Zadnji prop obrisan (' .. last.model .. ').')
end)
