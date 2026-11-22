-- OSRP framework v1.0.27 - gun shop (Oružarnica, osrp_osijek NPC dialog)
local GUNSHOP = vector3(5530.0, -1896.0, 8.26)         -- shop counter (Config.Origin + 30, -396)
local ITEMS = {
    pistol     = { price = 750, weapon = 'WEAPON_PISTOL', ammo = 36, label = 'Pištolj' },
    ammo       = { price = 60,  weapon = 'WEAPON_PISTOL', ammo = 36, label = 'Municija', ammoOnly = true },
    knife      = { price = 120, weapon = 'WEAPON_KNIFE', ammo = 0, label = 'Nož' },
    bat        = { price = 80,  weapon = 'WEAPON_BAT', ammo = 0, label = 'Palica' },
    flashlight = { price = 40,  weapon = 'WEAPON_FLASHLIGHT', ammo = 0, label = 'Svjetiljka' },
}
local last = {}

local function notify(src, msg) TriggerClientEvent('osrp:notify', src, msg) end

RegisterNetEvent('osrp:buyWeapon', function(item)
    local src = source
    local it = ITEMS[item]
    if not it or not OSRP.GetPlayer(src) then return end
    if last[src] and os.time() - last[src] < 2 then return end
    last[src] = os.time()
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 or #(GetEntityCoords(ped) - GUNSHOP) > 25.0 then return end
    local hash = joaat(it.weapon)
    if it.ammoOnly and not HasPedGotWeapon(ped, hash, false) then
        return notify(src, '~r~Prvo kupi pištolj.')
    end
    local acct = OSRP.RemoveMoney(src, 'cash', it.price) and 'gotovine' or (OSRP.RemoveMoney(src, 'bank', it.price) and 'banke' or nil)
    if not acct then return notify(src, ('~r~Nemaš $%d.'):format(it.price)) end
    if it.ammoOnly then
        AddAmmoToPed(ped, hash, it.ammo)
    else
        GiveWeaponToPed(ped, hash, it.ammo, false, true)
    end
    notify(src, ('Kupljeno: ~y~%s~s~ - plaćeno ~r~$%d~s~ (s %s).'):format(it.label, it.price, acct))
end)

-- ---------- v1.0.33 BULET e-scooter rental ----------
local BULET_UNLOCK, BULET_PER_MIN = 2, 1
local rides = {}

RegisterNetEvent('osrp:buletStart', function(i, k)
    local src = source
    if not OSRP.GetPlayer(src) or rides[src] then return end
    local acct = OSRP.RemoveMoney(src, 'bank', BULET_UNLOCK) and 'banke' or (OSRP.RemoveMoney(src, 'cash', BULET_UNLOCK) and 'gotovine' or nil)
    if not acct then return notify(src, ('~r~BULET:~s~ treba ti $%d za otključavanje.'):format(BULET_UNLOCK)) end
    rides[src] = os.time()
    TriggerClientEvent('osrp_osijek:buletOk', src, i, k)
end)

local function endRide(src, silent)
    local t = rides[src]
    if not t then return end
    rides[src] = nil
    local mins = math.max(1, math.ceil((os.time() - t) / 60))
    local price = math.min(mins, 180) * BULET_PER_MIN
    local acct = OSRP.RemoveMoney(src, 'bank', price) and 'banke' or (OSRP.RemoveMoney(src, 'cash', price) and 'gotovine' or nil)
    if silent then return end
    if acct then
        notify(src, ('~g~BULET~s~ - vožnja gotova: %d min, plaćeno ~r~$%d~s~ (s %s). Hvala!'):format(mins, price + BULET_UNLOCK, acct))
    else
        notify(src, ('~g~BULET~s~ - vožnja gotova: %d min. Nemaš dovoljno novca, ovaj put je besplatno.'):format(mins))
    end
end

RegisterNetEvent('osrp:buletEnd', function() endRide(source) end)
AddEventHandler('playerDropped', function() endRide(source, true) end)
